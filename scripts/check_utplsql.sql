-- Run as the project schema after installing utPLSQL. Fails if the public
-- "ut" synonym is missing, which would otherwise only show up later as
-- PLS-00201 errors on every ut.expect in the test packages.
whenever sqlerror exit failure
set serveroutput on
begin
    dbms_output.put_line('utPLSQL ' || ut.version());
end;
/
exit
