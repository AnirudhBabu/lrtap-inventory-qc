create or replace package ut_qc_runner as
    --%suite(QC runner)

    --%beforeeach
    procedure setup;

    --%test(A run stores every enabled check's findings under its run id)
    procedure run_stores_findings;

    --%test(A disabled check is skipped)
    procedure disabled_check_skipped;

    --%test(Each run keeps its own findings)
    procedure runs_kept_apart;
end ut_qc_runner;
/

create or replace package body ut_qc_runner as

    -- Data that trips exactly two checks:
    --   S1 = -1  -> QC04 negative value
    --   S2 = NE  -> QC03 not estimated
    -- NOX is not required, so QC01 is silent; there is no national total,
    -- so QC05 and QC07 are silent; there is no PM, so QC06 is silent.
    procedure setup is
    begin
        ut_fixture.reset;
        ut_fixture.add_pollutant('NOX', null);
        ut_fixture.add_sector('S1');
        ut_fixture.add_sector('S2');
        ut_fixture.add_value('XA', 'NOX', 'S1', 2023, -1);
        ut_fixture.add_key  ('XA', 'NOX', 'S2', 2023, 'NE');
    end setup;

    procedure run_stores_findings is
        l_run_id     number;
        l_checks     varchar2(100);
        l_finished   timestamp;
    begin
        l_run_id := qc_runner.run_all;

        select listagg(check_id, ',') within group (order by check_id)
          into l_checks
          from qc_finding where run_id = l_run_id;
        ut.expect(l_checks).to_equal('QC03,QC04');

        select finished_at into l_finished from qc_run where run_id = l_run_id;
        ut.expect(l_finished).not_to_be_null();
    end run_stores_findings;

    procedure disabled_check_skipped is
        l_run_id number;
        l_checks varchar2(100);
    begin
        update qc_check set enabled = 'N' where check_id = 'QC03';
        l_run_id := qc_runner.run_all;

        select listagg(check_id, ',') within group (order by check_id)
          into l_checks
          from qc_finding where run_id = l_run_id;
        ut.expect(l_checks).to_equal('QC04');
    end disabled_check_skipped;

    procedure runs_kept_apart is
        l_first  number;
        l_second number;
        n        number;
    begin
        l_first  := qc_runner.run_all;
        l_second := qc_runner.run_all;

        ut.expect(l_second).to_be_greater_than(l_first);
        select count(*) into n from qc_finding where run_id = l_first;
        ut.expect(n).to_equal(2);
        select count(*) into n from qc_finding where run_id = l_second;
        ut.expect(n).to_equal(2);
    end runs_kept_apart;

end ut_qc_runner;
/
