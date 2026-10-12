create or replace package qc_runner as

    -- Runs every enabled check in qc_check and stores what each one finds in
    -- qc_finding under a new run id, which it returns. Does not commit; the
    -- caller decides.
    function run_all return qc_run.run_id%type;

end qc_runner;
/

create or replace package body qc_runner as

    function run_all return qc_run.run_id%type is
        l_run_id qc_run.run_id%type;
    begin
        insert into qc_run (started_at) values (systimestamp)
        returning run_id into l_run_id;

        for c in (select check_id, view_name
                    from qc_check
                   where enabled = 'Y'
                   order by check_id)
        loop
            -- The view name comes from qc_check; simple_sql_name refuses
            -- anything that is not a plain identifier.
            execute immediate
                'insert into qc_finding (run_id, check_id, country_code, pollutant_code,'
                || ' sector_code, year, observed, expected, detail)'
                || ' select :run_id, :check_id, country_code, pollutant_code,'
                || ' sector_code, year, observed, expected, detail'
                || ' from ' || dbms_assert.simple_sql_name(c.view_name)
                using l_run_id, c.check_id;
        end loop;

        update qc_run set finished_at = systimestamp where run_id = l_run_id;
        return l_run_id;
    end run_all;

end qc_runner;
/
