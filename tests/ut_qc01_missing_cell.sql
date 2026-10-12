create or replace package ut_qc01_missing_cell as
    --%suite(QC01 Required cell missing)

    --%beforeeach
    procedure setup;

    --%test(Reports a required cell that is absent)
    procedure reports_absent_cell;

    --%test(A notation key counts as reported)
    procedure notation_key_counts_as_reported;

    --%test(Ignores pollutants whose reporting is not required)
    procedure ignores_pollutant_not_required;

    --%test(Ignores years before a pollutant's required start year)
    procedure ignores_years_before_required;

    --%test(Does not require national total rows)
    procedure total_rows_not_required;

    --%test(Reports every missing cell for a country that reported only one)
    procedure reports_all_gaps_for_sparse_country;
end ut_qc01_missing_cell;
/

create or replace package body ut_qc01_missing_cell as

    -- Scope used by every test:
    --   NOX required from 2022, BC not required.
    --   Sectors S1, S2 (summed), M1 (memo), TOT (national total).
    --   The latest year in the data is 2023, so NOX needs
    --   2 years x 3 sectors = 6 cells per country.
    procedure setup is
    begin
        ut_fixture.reset;
        ut_fixture.add_pollutant('NOX', 2022);
        ut_fixture.add_pollutant('BC', null);
        ut_fixture.add_sector('S1', 'SECTOR');
        ut_fixture.add_sector('S2', 'SECTOR');
        ut_fixture.add_sector('M1', 'MEMO');
        ut_fixture.add_sector('TOT', 'TOTAL');
    end setup;

    -- Fills all six required NOX cells for a country, except one if named.
    procedure fill_nox(
        p_country     in varchar2,
        p_skip_sector in varchar2 default null,
        p_skip_year   in number   default null)
    is
        type t_codes is table of varchar2(30);
        sectors constant t_codes := t_codes('S1', 'S2', 'M1');
    begin
        for i in 1 .. sectors.count loop
            for y in 2022 .. 2023 loop
                if p_skip_sector is null
                   or not (sectors(i) = p_skip_sector and y = p_skip_year)
                then
                    ut_fixture.add_value(p_country, 'NOX', sectors(i), y, 1);
                end if;
            end loop;
        end loop;
    end fill_nox;

    procedure reports_absent_cell is
    begin
        fill_nox('XA', p_skip_sector => 'S2', p_skip_year => 2023);

        ut_fixture.expect_cell('XA', 'NOX', 'S2', 2023);
        ut.expect(ut_fixture.actual_cells('QC01_MISSING_CELL'))
          .to_equal(ut_fixture.expected_cells()).unordered();
    end reports_absent_cell;

    procedure notation_key_counts_as_reported is
    begin
        fill_nox('XA', p_skip_sector => 'S2', p_skip_year => 2023);
        ut_fixture.add_key('XA', 'NOX', 'S2', 2023, 'NE');

        ut.expect(ut_fixture.actual_cells('QC01_MISSING_CELL')).to_be_empty();
    end notation_key_counts_as_reported;

    procedure ignores_pollutant_not_required is
    begin
        fill_nox('XA');
        -- BC has no rows at all, and is not required.
        ut.expect(ut_fixture.actual_cells('QC01_MISSING_CELL')).to_be_empty();
    end ignores_pollutant_not_required;

    procedure ignores_years_before_required is
    begin
        ut_fixture.add_pollutant('PM10', 2023);
        fill_nox('XA');
        -- PM10 is required from 2023 only, so 2022 is out of scope.
        ut_fixture.add_value('XA', 'PM10', 'S1', 2023, 1);
        ut_fixture.add_value('XA', 'PM10', 'S2', 2023, 1);

        ut_fixture.expect_cell('XA', 'PM10', 'M1', 2023);
        ut.expect(ut_fixture.actual_cells('QC01_MISSING_CELL'))
          .to_equal(ut_fixture.expected_cells()).unordered();
    end ignores_years_before_required;

    procedure total_rows_not_required is
    begin
        fill_nox('XA');
        -- No TOT rows exist, and none are expected.
        ut.expect(ut_fixture.actual_cells('QC01_MISSING_CELL')).to_be_empty();
    end total_rows_not_required;

    procedure reports_all_gaps_for_sparse_country is
    begin
        fill_nox('XA');
        ut_fixture.add_value('XB', 'NOX', 'S1', 2023, 1);

        ut_fixture.expect_cell('XB', 'NOX', 'S1', 2022);
        ut_fixture.expect_cell('XB', 'NOX', 'S2', 2022);
        ut_fixture.expect_cell('XB', 'NOX', 'S2', 2023);
        ut_fixture.expect_cell('XB', 'NOX', 'M1', 2022);
        ut_fixture.expect_cell('XB', 'NOX', 'M1', 2023);
        ut.expect(ut_fixture.actual_cells('QC01_MISSING_CELL'))
          .to_equal(ut_fixture.expected_cells()).unordered();
    end reports_all_gaps_for_sparse_country;

end ut_qc01_missing_cell;
/
