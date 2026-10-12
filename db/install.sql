-- Installs the project into the current schema. Run with SQL*Plus or SQLcl:
--   sqlplus qc/qc@//localhost:1521/FREEPDB1 @db/install.sql

whenever sqlerror exit failure rollback
set define off

@@01_schema.sql
@@02_config.sql
@@03_reference_data.sql
@@04_checks.sql
@@05_loader.sql
@@06_qc_runner.sql

-- SQL*Plus reports PL/SQL compilation errors as warnings and carries on.
-- Fail the install instead, after showing what went wrong.
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
