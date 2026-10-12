create or replace package ut_qc05_sector_sum as
    --%suite(QC05 Sectors do not sum to the national total)

    --%beforeeach
    procedure setup;

    --%test(A total equal to the sum of its sectors is not reported)
    procedure matching_sum_not_reported;

    --%test(Memo items are excluded from the sum)
    procedure memo_items_excluded;

    --%test(A mismatch is reported with the sum as observed and the total as expected)
    procedure mismatch_reported_with_numbers;

    --%test(Differences inside rel_tol are ignored, just outside are reported)
    procedure tolerance_boundary;

    --%test(Notation keys contribute nothing to the sum)
    procedure notation_keys_add_nothing;

    --%test(A total that is a notation key is not checked)
    procedure total_as_key_skipped;

    --%test(A numeric total whose sectors are all notation keys is reported)
    procedure total_without_numeric_sectors_reported;
end ut_qc05_sector_sum;
/

create or replace package body ut_qc05_sector_sum as

    procedure setup is
    begin
        ut_fixture.reset;
        ut_fixture.add_pollutant('NOX', 2023);
        ut_fixture.add_sector('S1', 'SECTOR');
        ut_fixture.add_sector('S2', 'SECTOR');
        ut_fixture.add_sector('M1', 'MEMO');
        ut_fixture.add_sector('TOT', 'TOTAL');
    end setup;

    procedure matching_sum_not_reported is
    begin
        ut_fixture.add_value('XA', 'NOX', 'S1',  2023, 10);
        ut_fixture.add_value('XA', 'NOX', 'S2',  2023, 5);
        ut_fixture.add_value('XA', 'NOX', 'TOT', 2023, 15);

        ut.expect(ut_fixture.actual_cells('QC05_SECTOR_SUM')).to_be_empty();
    end matching_sum_not_reported;

    procedure memo_items_excluded is
    begin
        ut_fixture.add_value('XA', 'NOX', 'S1',  2023, 10);
        ut_fixture.add_value('XA', 'NOX', 'S2',  2023, 5);
        ut_fixture.add_value('XA', 'NOX', 'M1',  2023, 100);
        ut_fixture.add_value('XA', 'NOX', 'TOT', 2023, 15);

        ut.expect(ut_fixture.actual_cells('QC05_SECTOR_SUM')).to_be_empty();
    end memo_items_excluded;

    procedure mismatch_reported_with_numbers is
        l_observed number;
        l_expected number;
    begin
        ut_fixture.add_value('XA', 'NOX', 'S1',  2023, 10);
        ut_fixture.add_value('XA', 'NOX', 'S2',  2023, 5);
        ut_fixture.add_value('XA', 'NOX', 'TOT', 2023, 16);

        ut_fixture.expect_cell('XA', 'NOX', 'TOT', 2023);
        ut.expect(ut_fixture.actual_cells('QC05_SECTOR_SUM'))
          .to_equal(ut_fixture.expected_cells());

        select observed, expected into l_observed, l_expected from qc05_sector_sum;
        ut.expect(l_observed).to_equal(15);
        ut.expect(l_expected).to_equal(16);
    end mismatch_reported_with_numbers;

    -- Sum is 15 in both countries; rel_tol is 0.00001.
    --   XA total 15.0001: |15 - 15.0001| / 15.0001 = 0.0000067, inside
    --   XB total 15.0002: |15 - 15.0002| / 15.0002 = 0.0000133, outside
    procedure tolerance_boundary is
    begin
        for c in (select 'XA' as code, 15.0001 as total from dual
                  union all
                  select 'XB', 15.0002 from dual) loop
            ut_fixture.add_value(c.code, 'NOX', 'S1',  2023, 10);
            ut_fixture.add_value(c.code, 'NOX', 'S2',  2023, 5);
            ut_fixture.add_value(c.code, 'NOX', 'TOT', 2023, c.total);
        end loop;

        ut_fixture.expect_cell('XB', 'NOX', 'TOT', 2023);
        ut.expect(ut_fixture.actual_cells('QC05_SECTOR_SUM'))
          .to_equal(ut_fixture.expected_cells());
    end tolerance_boundary;

    procedure notation_keys_add_nothing is
    begin
        ut_fixture.add_value('XA', 'NOX', 'S1',  2023, 10);
        ut_fixture.add_key  ('XA', 'NOX', 'S2',  2023, 'NE');
        ut_fixture.add_value('XA', 'NOX', 'TOT', 2023, 10);

        ut.expect(ut_fixture.actual_cells('QC05_SECTOR_SUM')).to_be_empty();
    end notation_keys_add_nothing;

    procedure total_as_key_skipped is
    begin
        ut_fixture.add_value('XA', 'NOX', 'S1',  2023, 10);
        ut_fixture.add_value('XA', 'NOX', 'S2',  2023, 5);
        ut_fixture.add_key  ('XA', 'NOX', 'TOT', 2023, 'NE');

        ut.expect(ut_fixture.actual_cells('QC05_SECTOR_SUM')).to_be_empty();
    end total_as_key_skipped;

    procedure total_without_numeric_sectors_reported is
        l_observed number;
    begin
        ut_fixture.add_key  ('XA', 'NOX', 'S1',  2023, 'NO');
        ut_fixture.add_key  ('XA', 'NOX', 'S2',  2023, 'IE');
        ut_fixture.add_value('XA', 'NOX', 'TOT', 2023, 5);

        ut_fixture.expect_cell('XA', 'NOX', 'TOT', 2023);
        ut.expect(ut_fixture.actual_cells('QC05_SECTOR_SUM'))
          .to_equal(ut_fixture.expected_cells());

        select observed into l_observed from qc05_sector_sum;
        ut.expect(l_observed).to_equal(0);
    end total_without_numeric_sectors_reported;

end ut_qc05_sector_sum;
/
