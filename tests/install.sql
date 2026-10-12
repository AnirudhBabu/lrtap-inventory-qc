-- Installs the utPLSQL test packages into the current schema.
-- Run after db/install.sql:
--   sqlplus qc/qc@//localhost:1521/FREEPDB1 @tests/install.sql

whenever sqlerror exit failure rollback
set define off

@@ut_fixture.sql
@@ut_loader.sql
@@ut_qc01_missing_cell.sql
@@ut_qc02_qc04_cell_values.sql
@@ut_qc05_sector_sum.sql
@@ut_qc06_pm_order.sql
@@ut_qc07_time_series.sql
@@ut_qc_runner.sql

set serveroutput on
begin
    for e in (select name, type, line, position, text
                from user_errors order by name, type, sequence) loop
        dbms_output.put_line(e.type || ' ' || e.name || ' line ' || e.line
                             || ':' || e.position || '  ' || e.text);
    end loop;
end;
/
declare
    n number;
begin
    select count(*) into n from user_errors;
    if n > 0 then
        raise_application_error(-20000, n || ' compilation error(s), listed above');
    end if;
end;
/

exit
