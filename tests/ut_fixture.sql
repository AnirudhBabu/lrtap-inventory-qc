-- Helpers that build small, hand-checkable datasets for the tests.
--
-- reset() clears the data tables and the inventory reference tables, so each
-- test starts from nothing but the fixed configuration (notation keys, checks,
-- parameters). utPLSQL rolls every test back afterwards, so nothing a test
-- does is kept. Run the tests in a schema without production data anyway:
-- deleting millions of rows only to roll them back is slow.
--
-- Country codes XA, XB, ... are used throughout. ISO 3166 reserves the X
-- range for user-assigned codes, so they can never be mistaken for a real
-- Party.

create global temporary table ut_expected_cell (
    country_code    varchar2(3),
    pollutant_code  varchar2(20),
    sector_code     varchar2(30),
    year            number(4)
) on commit delete rows;

create or replace package ut_fixture as

    procedure reset;

    procedure add_pollutant(
        p_code               in varchar2,
        p_required_from_year in number   default null,
        p_source_name        in varchar2 default null);

    procedure add_sector(
        p_code in varchar2,
        p_role in varchar2 default 'SECTOR');

    procedure add_value(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_year      in number,
        p_value     in number);

    procedure add_key(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_year      in number,
        p_key       in varchar2);

    -- Adds p_value for every year from p_from_year to p_to_year.
    procedure add_constant_series(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_from_year in number,
        p_to_year   in number,
        p_value     in number);

    -- Expected findings. Tests list the cells they expect a check to report,
    -- then compare expected_cells() with the check's view. Going through a
    -- typed table keeps column types identical on both sides; literals from
    -- DUAL would be CHAR, the view columns are VARCHAR2.
    procedure expect_cell(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_year      in number);

    function expected_cells return sys_refcursor;

    -- The cells a check's view reports, in the same shape as expected_cells.
    function actual_cells(p_view_name in varchar2) return sys_refcursor;

end ut_fixture;
/

create or replace package body ut_fixture as

    procedure reset is
    begin
        delete from ut_expected_cell;
        delete from qc_finding;
        delete from qc_run;
        delete from load_reject;
        delete from stg_emission;
        delete from emission;
        delete from ref_sector;
        delete from ref_pollutant;
    end reset;

    procedure add_pollutant(
        p_code               in varchar2,
        p_required_from_year in number   default null,
        p_source_name        in varchar2 default null)
    is
    begin
        insert into ref_pollutant (pollutant_code, source_name, unit, required_from_year, source_ref)
        values (p_code, coalesce(p_source_name, p_code), 'Gg', p_required_from_year, 'test fixture');
    end add_pollutant;

    procedure add_sector(
        p_code in varchar2,
        p_role in varchar2 default 'SECTOR')
    is
    begin
        insert into ref_sector (sector_code, sector_name, role)
        values (p_code, 'Fixture sector ' || p_code, p_role);
    end add_sector;

    procedure add_value(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_year      in number,
        p_value     in number)
    is
    begin
        insert into emission (country_code, pollutant_code, sector_code, year, value)
        values (p_country, p_pollutant, p_sector, p_year, p_value);
    end add_value;

    procedure add_key(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_year      in number,
        p_key       in varchar2)
    is
    begin
        insert into emission (country_code, pollutant_code, sector_code, year, notation_key)
        values (p_country, p_pollutant, p_sector, p_year, p_key);
    end add_key;

    procedure add_constant_series(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_from_year in number,
        p_to_year   in number,
        p_value     in number)
    is
    begin
        for y in p_from_year .. p_to_year loop
            add_value(p_country, p_pollutant, p_sector, y, p_value);
        end loop;
    end add_constant_series;

    procedure expect_cell(
        p_country   in varchar2,
        p_pollutant in varchar2,
        p_sector    in varchar2,
        p_year      in number)
    is
    begin
        insert into ut_expected_cell (country_code, pollutant_code, sector_code, year)
        values (p_country, p_pollutant, p_sector, p_year);
    end expect_cell;

    function expected_cells return sys_refcursor is
        c sys_refcursor;
    begin
        open c for
            select country_code, pollutant_code, sector_code, year
            from ut_expected_cell;
        return c;
    end expected_cells;

    function actual_cells(p_view_name in varchar2) return sys_refcursor is
        c sys_refcursor;
    begin
        open c for
            'select cast(country_code as varchar2(3)) as country_code,'
            || ' cast(pollutant_code as varchar2(20)) as pollutant_code,'
            || ' cast(sector_code as varchar2(30)) as sector_code,'
            || ' cast(year as number(4)) as year'
            || ' from ' || dbms_assert.simple_sql_name(p_view_name);
        return c;
    end actual_cells;

end ut_fixture;
/
