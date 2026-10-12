-- Run as SYS in the pluggable database. Gives the project schema what it
-- needs, stated explicitly rather than relying on the container's defaults.
whenever sqlerror exit failure
grant create session, create table, create view, create procedure to qc;
grant unlimited tablespace to qc;
exit
