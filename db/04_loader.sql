-- Loading: stg_emission (raw text) -> emission (typed) or load_reject.
--
-- All the rules for reading a raw row are in one view, so they can be read,
-- tested and queried in one place. The package only moves rows.

------------------------------------------------------------------------------
-- Every staging row with its interpreted values and, if it cannot be loaded,
-- the first reason found. Rules, in the order they are applied:
--
--   country code      must be 2 or 3 characters
--   pollutant         must match ref_pollutant.source_name
--   sector            must match ref_sector.sector_code
--   year              must be a whole number between 1900 and 2100
--   cell              a number, or a notation key from ref_notation_key;
--                     it may arrive in either the value or the notation column,
--                     but not in both, and not in neither
--   uniqueness        a cell reported twice is ambiguous, so every copy is
--                     rejected rather than picking one
--
-- Numbers are read with '.' as the decimal separator. inventory_loader.load
-- sets that for the session; query this view directly only after doing the same.
------------------------------------------------------------------------------
create or replace view stg_emission_classified as
with
cleaned as (
    select s.stg_row_id,
           trim(s.country_code)                         as country_code,
           p.pollutant_code,
           r.sector_code,
           to_number(trim(s.year_text) default null on conversion error) as year_number,
           trim(s.value_text)                           as value_text,
           trim(s.notation_text)                        as notation_text
      from stg_emission s
      left join ref_pollutant p on p.source_name = trim(s.pollutant_name)
      left join ref_sector    r on r.sector_code = trim(s.sector_code)
),
cell as (
    select c.*,
           to_number(coalesce(c.value_text, c.notation_text) default null on conversion error) as cell_number,
           k.notation_key                               as cell_key
      from cleaned c
      left join ref_notation_key k
        on k.notation_key = upper(coalesce(c.value_text, c.notation_text))
),
first_reason as (
    select c.*,
           case
               when c.country_code is null or length(c.country_code) not between 2 and 3
                   then 'country code is not 2 or 3 characters'
               when c.pollutant_code is null
                   then 'unknown pollutant'
               when c.sector_code is null
                   then 'unknown sector'
               when c.year_number is null
                    or c.year_number <> trunc(c.year_number)
                    or c.year_number not between 1900 and 2100
                   then 'year is not a whole number between 1900 and 2100'
               when c.value_text is null and c.notation_text is null
                   then 'empty cell'
               when c.value_text is not null and c.notation_text is not null
                   then 'both a value and a notation key'
               when c.cell_number is null and c.cell_key is null
                   then 'neither a number nor a notation key'
           end as reason
      from cell c
)
select f.stg_row_id,
       f.country_code,
       f.pollutant_code,
       f.sector_code,
       f.year_number as year,
       f.cell_number as value,
       case when f.cell_number is null then f.cell_key end as notation_key,
       case
           when f.reason is not null
               then f.reason
           when count(case when f.reason is null then 1 end)
                    over (partition by f.country_code, f.pollutant_code, f.sector_code, f.year_number) > 1
               then 'duplicate cell'
       end as reject_reason
  from first_reason f;

------------------------------------------------------------------------------
create or replace package inventory_loader as

    -- Replaces the contents of emission and load_reject with the result of
    -- reading stg_emission. Does not commit; the caller decides.
    procedure load;

end inventory_loader;
/

create or replace package body inventory_loader as

    procedure set_numeric_characters(p_value in varchar2) is
    begin
        execute immediate 'alter session set nls_numeric_characters = '
            || dbms_assert.enquote_literal(p_value);
    end set_numeric_characters;

    procedure load is
        l_saved nls_session_parameters.value%type;
    begin
        -- The decimal separator is a session setting. Use '.' while loading,
        -- then put back whatever the caller had.
        select value into l_saved
          from nls_session_parameters
         where parameter = 'NLS_NUMERIC_CHARACTERS';
        set_numeric_characters('.,');

        delete from emission;
        delete from load_reject;

        insert into emission (country_code, pollutant_code, sector_code, year, value, notation_key)
        select country_code, pollutant_code, sector_code, year, value, notation_key
          from stg_emission_classified
         where reject_reason is null;

        insert into load_reject (stg_row_id, reason)
        select stg_row_id, reject_reason
          from stg_emission_classified
         where reject_reason is not null;

        set_numeric_characters(l_saved);
    exception
        when others then
            if l_saved is not null then
                set_numeric_characters(l_saved);
            end if;
            raise;
    end load;

end inventory_loader;
/
