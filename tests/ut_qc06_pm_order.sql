create or replace package ut_qc06_pm_order as
    --%suite(QC06 Particle size classes out of order)

    --%beforeeach
    procedure setup;

    --%test(Correctly ordered classes are not reported)
    procedure ordered_not_reported;

    --%test(Equal classes are not reported)
    procedure equal_not_reported;

    --%test(PM2.5 above PM10 is reported on the PM2.5 cell)
    procedure pm25_above_pm10_reported;

    --%test(Every out-of-order pair is reported)
    procedure every_pair_reported;

    --%test(Differences inside rel_tol are ignored, just outside are reported)
    procedure tolerance_boundary;

    --%test(A pair with a notation key on one side is not compared)
    procedure key_side_not_compared;

    --%test(Classes are compared across a missing middle class)
    procedure compared_across_missing_middle;

    --%test(Values in different sectors are not compared)
    procedure different_sectors_not_compared;
end ut_qc06_pm_order;
/

create or replace package body ut_qc06_pm_order as

    procedure setup is
    begin
        ut_fixture.reset;
        ut_fixture.add_pollutant('BC');
        ut_fixture.add_pollutant('PM2.5', 2000);
        ut_fixture.add_pollutant('PM10', 2000);
        ut_fixture.add_pollutant('TSP');
        ut_fixture.add_sector('S1');
        ut_fixture.add_sector('S2');
    end setup;

    -- Sets BC, PM2.5, PM10 and TSP for one sector in 2023.
    -- Pass null to leave a class out.
    procedure set_classes(
        p_sector in varchar2,
        p_bc in number, p_pm25 in number, p_pm10 in number, p_tsp in number)
    is
    begin
        if p_bc   is not null then ut_fixture.add_value('XA', 'BC',    p_sector, 2023, p_bc);   end if;
        if p_pm25 is not null then ut_fixture.add_value('XA', 'PM2.5', p_sector, 2023, p_pm25); end if;
        if p_pm10 is not null then ut_fixture.add_value('XA', 'PM10',  p_sector, 2023, p_pm10); end if;
        if p_tsp  is not null then ut_fixture.add_value('XA', 'TSP',   p_sector, 2023, p_tsp);  end if;
    end set_classes;

    procedure ordered_not_reported is
    begin
        set_classes('S1', p_bc => 1, p_pm25 => 2, p_pm10 => 3, p_tsp => 4);
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER')).to_be_empty();
    end ordered_not_reported;

    procedure equal_not_reported is
    begin
        set_classes('S1', p_bc => 3, p_pm25 => 3, p_pm10 => 3, p_tsp => 3);
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER')).to_be_empty();
    end equal_not_reported;

    procedure pm25_above_pm10_reported is
        l_observed number;
        l_expected number;
    begin
        -- PM2.5 exceeds PM10 but not TSP: one finding.
        set_classes('S1', p_bc => 1, p_pm25 => 5, p_pm10 => 3, p_tsp => 6);

        ut_fixture.expect_cell('XA', 'PM2.5', 'S1', 2023);
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER'))
          .to_equal(ut_fixture.expected_cells());

        select observed, expected into l_observed, l_expected from qc06_pm_order;
        ut.expect(l_observed).to_equal(5);
        ut.expect(l_expected).to_equal(3);
    end pm25_above_pm10_reported;

    procedure every_pair_reported is
    begin
        -- BC 3 > PM2.5 2, and PM10 4 > TSP 3.5. Every other pair is in order.
        set_classes('S1', p_bc => 3, p_pm25 => 2, p_pm10 => 4, p_tsp => 3.5);

        ut_fixture.expect_cell('XA', 'BC',   'S1', 2023);
        ut_fixture.expect_cell('XA', 'PM10', 'S1', 2023);
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER'))
          .to_equal(ut_fixture.expected_cells()).unordered();
    end every_pair_reported;

    -- PM10 is 3 in both sectors, so the limit is 3 x 1.001 = 3.003.
    --   S1 PM2.5 3.002: inside
    --   S2 PM2.5 3.004: outside
    procedure tolerance_boundary is
    begin
        set_classes('S1', p_bc => null, p_pm25 => 3.002, p_pm10 => 3, p_tsp => null);
        set_classes('S2', p_bc => null, p_pm25 => 3.004, p_pm10 => 3, p_tsp => null);

        ut_fixture.expect_cell('XA', 'PM2.5', 'S2', 2023);
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER'))
          .to_equal(ut_fixture.expected_cells());
    end tolerance_boundary;

    procedure key_side_not_compared is
    begin
        ut_fixture.add_value('XA', 'PM2.5', 'S1', 2023, 5);
        ut_fixture.add_key  ('XA', 'PM10',  'S1', 2023, 'NE');
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER')).to_be_empty();
    end key_side_not_compared;

    procedure compared_across_missing_middle is
    begin
        -- PM10 is not estimated, but PM2.5 5 > TSP 4 is still a contradiction.
        ut_fixture.add_value('XA', 'PM2.5', 'S1', 2023, 5);
        ut_fixture.add_key  ('XA', 'PM10',  'S1', 2023, 'NE');
        ut_fixture.add_value('XA', 'TSP',   'S1', 2023, 4);

        ut_fixture.expect_cell('XA', 'PM2.5', 'S1', 2023);
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER'))
          .to_equal(ut_fixture.expected_cells());
    end compared_across_missing_middle;

    procedure different_sectors_not_compared is
    begin
        ut_fixture.add_value('XA', 'PM2.5', 'S1', 2023, 5);
        ut_fixture.add_value('XA', 'PM10',  'S2', 2023, 3);
        ut.expect(ut_fixture.actual_cells('QC06_PM_ORDER')).to_be_empty();
    end different_sectors_not_compared;

end ut_qc06_pm_order;
/
