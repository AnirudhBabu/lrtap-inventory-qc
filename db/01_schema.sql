-- Schema for the LRTAP inventory QC project.
--
-- Three groups of tables:
--   ref_*   reference data: what the reporting rules say should exist
--   stg_*, emission, load_reject   the inventory data, raw and loaded
--   qc_*    the checks, their parameters, and what they found
--
-- Written for Oracle 19c and later. Flags are CHAR(1) 'Y'/'N' rather than
-- BOOLEAN so the schema also runs on releases before 23ai.

------------------------------------------------------------------------------
-- Reference data
------------------------------------------------------------------------------

-- Notation keys explain why a cell has no number (RG2022 para. 12).
create table ref_notation_key (
    notation_key  varchar2(2)   not null,
    meaning       varchar2(200) not null,
    source_ref    varchar2(100) not null,
    constraint ref_notation_key_pk primary key (notation_key)
);

-- pollutant_code is this project's name for a pollutant; source_name is the
-- name used in the EEA dataset. Keeping both means a renamed pollutant in a
-- future edition is a one-row change here, not a change to every check.
create table ref_pollutant (
    pollutant_code      varchar2(20)  not null,
    source_name         varchar2(100) not null,
    unit                varchar2(20)  not null,
    required_from_year  number(4),     -- null: reporting is not required
    source_ref          varchar2(100) not null,
    constraint ref_pollutant_pk primary key (pollutant_code),
    constraint ref_pollutant_source_uk unique (source_name)
);

-- role says how a sector takes part in the national total:
--   SECTOR  an NFR sector that is summed into the national total
--   MEMO    a memo item, reported but excluded from the total
--           (aviation cruise, international shipping, natural sources)
--   TOTAL   the national total that QC05 checks the sectors against
--   OTHER   any other aggregate row; loaded but not checked
create table ref_sector (
    sector_code  varchar2(30)  not null,
    sector_name  varchar2(300) not null,
    role         varchar2(6)   not null,
    constraint ref_sector_pk primary key (sector_code),
    constraint ref_sector_role_ck check (role in ('SECTOR', 'MEMO', 'TOTAL', 'OTHER'))
);

------------------------------------------------------------------------------
-- Inventory data
------------------------------------------------------------------------------

-- Raw rows exactly as read from the source file, all as text. Nothing is
-- interpreted here, so a bad row can always be shown as it arrived.
create table stg_emission (
    stg_row_id     number generated always as identity,
    country_code   varchar2(4000),
    pollutant_name varchar2(4000),
    sector_code    varchar2(4000),
    year_text      varchar2(4000),
    value_text     varchar2(4000),
    notation_text  varchar2(4000),
    constraint stg_emission_pk primary key (stg_row_id)
);

-- One cell of the inventory: a number or a notation key, never both, never
-- neither. These are constraints, not checks: a row breaking them could not
-- be interpreted at all.
create table emission (
    country_code    varchar2(3)  not null,
    pollutant_code  varchar2(20) not null,
    sector_code     varchar2(30) not null,
    year            number(4)    not null,
    value           number,
    notation_key    varchar2(2),
    constraint emission_pk primary key (country_code, pollutant_code, sector_code, year),
    constraint emission_pollutant_fk foreign key (pollutant_code) references ref_pollutant,
    constraint emission_sector_fk foreign key (sector_code) references ref_sector,
    constraint emission_key_fk foreign key (notation_key) references ref_notation_key,
    constraint emission_value_or_key_ck check (
        (value is not null and notation_key is null)
        or (value is null and notation_key is not null))
);

-- Staging rows the loader could not interpret, with the first reason found.
create table load_reject (
    stg_row_id  number         not null,
    reason      varchar2(200)  not null,
    constraint load_reject_pk primary key (stg_row_id)
);

------------------------------------------------------------------------------
-- Quality control
------------------------------------------------------------------------------

-- One row per check. view_name is the view that returns its findings; the
-- runner reads this table, so adding a check is: write the view, add a row.
create table qc_check (
    check_id   varchar2(10)  not null,
    title      varchar2(200) not null,
    severity   varchar2(7)   not null,
    view_name  varchar2(128) not null,
    enabled    char(1)       default 'Y' not null,
    constraint qc_check_pk primary key (check_id),
    constraint qc_check_severity_ck check (severity in ('ERROR', 'WARNING')),
    constraint qc_check_enabled_ck check (enabled in ('Y', 'N'))
);

-- Tunable thresholds, each with the reason for its value.
create table qc_param (
    check_id     varchar2(10)  not null,
    param_name   varchar2(30)  not null,
    param_value  number        not null,
    rationale    varchar2(400) not null,
    constraint qc_param_pk primary key (check_id, param_name),
    constraint qc_param_check_fk foreign key (check_id) references qc_check
);

create table qc_run (
    run_id       number generated always as identity,
    started_at   timestamp default systimestamp not null,
    finished_at  timestamp,
    constraint qc_run_pk primary key (run_id)
);

-- Every check view returns these same columns, so findings from all checks
-- land in one table. observed and expected are filled where a check compares
-- two numbers; detail says in words what was found.
create table qc_finding (
    run_id          number        not null,
    check_id        varchar2(10)  not null,
    country_code    varchar2(3)   not null,
    pollutant_code  varchar2(20)  not null,
    sector_code     varchar2(30)  not null,
    year            number(4)     not null,
    observed        number,
    expected        number,
    detail          varchar2(400) not null,
    constraint qc_finding_run_fk foreign key (run_id) references qc_run,
    constraint qc_finding_check_fk foreign key (check_id) references qc_check
);

create index qc_finding_run_ix on qc_finding (run_id, check_id);
