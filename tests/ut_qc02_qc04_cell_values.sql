-- QC02, QC03 and QC04 each look at one cell on its own, so their tests share
-- one dataset and live together.

create or replace package ut_qc02_qc04_cell_values as
    --%suite(QC02-QC04 Single-cell checks)

    --%beforeeach
    procedure setup;

    --%test(QC02 reports a value of exactly zero)
    procedure qc02_reports_zero;

    --%test(QC02 does not treat a small positive value as zero)
    procedure qc02_ignores_small_value;

    --%test(QC02 ignores zeros in rows that are not source categories)
    procedure qc02_ignores_non_source_rows;

    --%test(QC03 reports NE and no other notation key)
    procedure qc03_reports_only_ne;

    --%test(QC04 reports a negative value and not zero)
    procedure qc04_reports_negative_only;

    --%test(QC04 ignores rows that are not source categories, such as adjustments)
    procedure qc04_ignores_non_source_rows;
end ut_qc02_qc04_cell_values;
/

create or replace package body ut_qc02_qc04_cell_values as

    -- One row of each kind, all for XA / NOX / 2023, one per sector:
    --   S1  1.5      ordinary value
    --   S2  0        exact zero               -> QC02
    --   S3  0.003    small but not zero
    --   S4  -2       negative                 -> QC04
    --   S5  NE       not estimated            -> QC03
    --   S6  NO       not occurring
    --   S7  IE       included elsewhere
    procedure setup is
    begin
        ut_fixture.reset;
        ut_fixture.add_pollutant('NOX', 2023);
        for i in 1 .. 7 loop
            ut_fixture.add_sector('S' || i, 'SECTOR');
        end loop;
        ut_fixture.add_value('XA', 'NOX', 'S1', 2023, 1.5);
        ut_fixture.add_value('XA', 'NOX', 'S2', 2023, 0);
        ut_fixture.add_value('XA', 'NOX', 'S3', 2023, 0.003);
        ut_fixture.add_value('XA', 'NOX', 'S4', 2023, -2);
        ut_fixture.add_key('XA', 'NOX', 'S5', 2023, 'NE');
        ut_fixture.add_key('XA', 'NOX', 'S6', 2023, 'NO');
        ut_fixture.add_key('XA', 'NOX', 'S7', 2023, 'IE');
    end setup;

    procedure qc02_reports_zero is
    begin
        ut_fixture.expect_cell('XA', 'NOX', 'S2', 2023);
        ut.expect(ut_fixture.actual_cells('QC02_ZERO_VALUE'))
          .to_equal(ut_fixture.expected_cells());
    end qc02_reports_zero;

    procedure qc02_ignores_small_value is
        n number;
    begin
        select count(*) into n from qc02_zero_value where sector_code = 'S3';
        ut.expect(n).to_equal(0);
    end qc02_ignores_small_value;

    -- A zero adjustment means no adjustment was made, and a zero total
    -- follows from the rows beneath it. Neither is a reporting choice that a
    -- notation key could explain.
    procedure qc02_ignores_non_source_rows is
        n number;
    begin
        ut_fixture.add_sector('ADJ', 'OTHER');
        ut_fixture.add_sector('TOT', 'TOTAL');
        ut_fixture.add_value('XA', 'NOX', 'ADJ', 2023, 0);
        ut_fixture.add_value('XA', 'NOX', 'TOT', 2023, 0);

        select count(*) into n from qc02_zero_value where sector_code in ('ADJ', 'TOT');
        ut.expect(n).to_equal(0);
    end qc02_ignores_non_source_rows;

    procedure qc03_reports_only_ne is
    begin
        ut_fixture.expect_cell('XA', 'NOX', 'S5', 2023);
        ut.expect(ut_fixture.actual_cells('QC03_NOT_ESTIMATED'))
          .to_equal(ut_fixture.expected_cells());
    end qc03_reports_only_ne;

    procedure qc04_reports_negative_only is
    begin
        ut_fixture.expect_cell('XA', 'NOX', 'S4', 2023);
        ut.expect(ut_fixture.actual_cells('QC04_NEGATIVE_VALUE'))
          .to_equal(ut_fixture.expected_cells());
    end qc04_reports_negative_only;

    -- Approved adjustments are subtracted from a total, so they are negative
    -- by design (the 2026 EEA file has 47 such cells).
    procedure qc04_ignores_non_source_rows is
        n number;
    begin
        ut_fixture.add_sector('ADJ', 'OTHER');
        ut_fixture.add_value('XA', 'NOX', 'ADJ', 2023, -5);

        select count(*) into n from qc04_negative_value where sector_code = 'ADJ';
        ut.expect(n).to_equal(0);
    end qc04_ignores_non_source_rows;

end ut_qc02_qc04_cell_values;
/
