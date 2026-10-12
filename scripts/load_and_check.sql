-- Loads the EEA file into stg_emission, loads it, runs every check, and
-- spools the findings. Called by scripts/run_on_data.sh, which creates the
-- EEA_DATA directory object pointing at the file.

whenever sqlerror exit failure rollback
set define off
set serveroutput on

-- The file as published: UTF-8 with a byte-order mark, tab-separated, CRLF
-- line ends, no quoting, one header line. The byte-order mark sits in the
-- header, which is skipped. Fields are read as text and not trimmed, so the
-- staging table holds exactly what the file holds.
create table ext_lrtap (
    country_code        varchar2(10),
    country_name        varchar2(200),
    pollutant_name      varchar2(200),
    sector_code         varchar2(200),
    year_text           varchar2(50),
    value_text          varchar2(100),
    unit                varchar2(50),
    notation_text       varchar2(10),
    parent_sector_code  varchar2(255),
    sector_name         varchar2(1000)
)
organization external (
    type oracle_loader
    default directory eea_data
    access parameters (
        records delimited by 0x'0D0A'
        characterset al32utf8
        skip 1
        nobadfile nologfile nodiscardfile
        fields terminated by 0x'09'
        notrim
        missing field values are null
        (
            country_code        char(10),
            country_name        char(200),
            pollutant_name      char(200),
            sector_code         char(200),
            year_text           char(50),
            value_text          char(100),
            unit                char(50),
            notation_text       char(10),
            parent_sector_code  char(255),
            sector_name         char(1000)
        )
    )
    location ('CLRTAP_NFR19_V26_1_GF.csv')
)
reject limit 0;

insert /*+ append */ into stg_emission
    (country_code, pollutant_name, sector_code, year_text, value_text, notation_text)
select country_code, pollutant_name, sector_code, year_text, value_text, notation_text
  from ext_lrtap;
commit;

exec inventory_loader.load
commit;

prompt Rows staged, loaded and not loaded (by reason):
select count(*) as staged from stg_emission;
select count(*) as loaded from emission;
select reason, count(*) as rows_not_loaded from load_reject group by reason order by 2 desc;

variable run_id number
exec :run_id := qc_runner.run_all
commit;

prompt Findings by check:
select check_id, count(*) as findings from qc_finding where run_id = :run_id group by check_id order by 1;

-- Same columns and order as data/results/findings_duckdb.csv, so the two
-- engines' results can be compared directly.
set markup csv on quote off
set feedback off
set termout off
spool /results/findings_oracle.csv
select check_id, country_code, pollutant_code, sector_code, year, observed, expected, detail
  from qc_finding
 where run_id = :run_id
 order by check_id, country_code, pollutant_code, sector_code, year, observed, expected, detail;
spool off

exit
