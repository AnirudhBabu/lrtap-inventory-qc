-- Expected results in these tests were worked out independently of the
-- implementation; docs/qc07_fixture_check.py reproduces them in plain Python.
--
-- The series used:
--   trend   100 x 0.9^(year - 2010), years 2010-2019: falls 10 % a year,
--           a straight line after log10, so every residual is (near) zero.
--   spike   the trend with 2015 multiplied by 3 (59.05 -> 177.15).
--           2015's residual is 2.84 sample standard deviations from the mean.
--   dip     50 every year, except 2017 = 10.
--           2017's residual is 2.72 sample standard deviations from the mean.

create or replace package ut_qc07_time_series as
    --%suite(QC07 Time-series dip or jump)

    --%beforeeach
    procedure setup;

    --%test(A jump far from the trend is reported)
    procedure spike_reported;

    --%test(A series that follows its trend exactly is not reported)
    procedure smooth_series_not_reported;

    --%test(A dip far from the trend is reported)
    procedure dip_reported;

    --%test(A value at or below 3 percent of the national total is not reviewed)
    procedure small_value_not_reviewed;

    --%test(A dip to a value below 3 percent of the total is not reported, as in the CEIP method)
    procedure dip_below_materiality_not_reported;

    --%test(Zeros and notation keys are left out of the series)
    procedure zeros_and_keys_excluded;

    --%test(A year without a numeric national total is not assessed)
    procedure year_without_numeric_total_skipped;

    --%test(Series shorter than min_years are not analysed)
    procedure short_series_not_analysed;

    --%test(qc07_trend gives each series' fitted line)
    procedure trend_view_gives_fitted_line;
end ut_qc07_time_series;
/

create or replace package body ut_qc07_time_series as

    procedure setup is
    begin
        ut_fixture.reset;
        ut_fixture.add_pollutant('NOX', 2010);
        ut_fixture.add_sector('S1', 'SECTOR');
        ut_fixture.add_sector('TOT', 'TOTAL');
    end setup;

    -- Adds the trend series to S1, optionally multiplying one year.
    procedure add_trend(p_spike_year in number default null, p_factor in number default 1) is
        v number;
    begin
        for y in 2010 .. 2019 loop
            v := 100 * power(0.9, y - 2010);
            if y = p_spike_year then
                v := v * p_factor;
            end if;
            ut_fixture.add_value('XA', 'NOX', 'S1', y, v);
        end loop;
    end add_trend;

    procedure add_dip is
    begin
        for y in 2010 .. 2019 loop
            ut_fixture.add_value('XA', 'NOX', 'S1', y, case when y = 2017 then 10 else 50 end);
        end loop;
    end add_dip;

    procedure add_total(p_value in number) is
    begin
        ut_fixture.add_constant_series('XA', 'NOX', 'TOT', 2010, 2019, p_value);
    end add_total;

    function findings return sys_refcursor is
    begin
        return ut_fixture.actual_cells('QC07_TIME_SERIES');
    end findings;

    procedure spike_reported is
    begin
        add_trend(p_spike_year => 2015, p_factor => 3);
        add_total(1000);   -- 177.15 / 1000 = 17.7 %, material

        ut_fixture.expect_cell('XA', 'NOX', 'S1', 2015);
        ut.expect(findings()).to_equal(ut_fixture.expected_cells());
    end spike_reported;

    procedure smooth_series_not_reported is
    begin
        add_trend;
        add_total(1000);
        ut.expect(findings()).to_be_empty();
    end smooth_series_not_reported;

    procedure dip_reported is
    begin
        add_dip;
        add_total(200);    -- 10 / 200 = 5 %, material

        ut_fixture.expect_cell('XA', 'NOX', 'S1', 2017);
        ut.expect(findings()).to_equal(ut_fixture.expected_cells());
    end dip_reported;

    procedure small_value_not_reviewed is
    begin
        add_trend(p_spike_year => 2015, p_factor => 3);
        add_total(10000);  -- 177.15 / 10000 = 1.8 %, below 3 %
        ut.expect(findings()).to_be_empty();
    end small_value_not_reviewed;

    -- CEIP applies the 3 % test to the flagged value itself. A dip makes the
    -- value small, so a deep dip can fall below the threshold and go
    -- unreported. This test pins that behaviour down; CHECKS.md discusses it.
    procedure dip_below_materiality_not_reported is
    begin
        add_dip;
        add_total(1000);   -- 10 / 1000 = 1 %, below 3 %
        ut.expect(findings()).to_be_empty();
    end dip_below_materiality_not_reported;

    procedure zeros_and_keys_excluded is
    begin
        add_trend(p_spike_year => 2015, p_factor => 3);
        update emission set value = 0
         where sector_code = 'S1' and year = 2012;
        update emission set value = null, notation_key = 'NE'
         where sector_code = 'S1' and year = 2013;
        add_total(1000);

        -- Fitted on the 8 remaining years, 2015 is 2.47 standard deviations out.
        ut_fixture.expect_cell('XA', 'NOX', 'S1', 2015);
        ut.expect(findings()).to_equal(ut_fixture.expected_cells());
    end zeros_and_keys_excluded;

    procedure year_without_numeric_total_skipped is
    begin
        add_trend(p_spike_year => 2015, p_factor => 3);
        add_total(1000);
        update emission set value = null, notation_key = 'NE'
         where sector_code = 'TOT' and year = 2015;
        ut.expect(findings()).to_be_empty();
    end year_without_numeric_total_skipped;

    procedure short_series_not_analysed is
    begin
        add_trend(p_spike_year => 2015, p_factor => 3);
        add_total(1000);
        -- The series has 10 years. Requiring 11 must switch the check off.
        update qc_param set param_value = 11
         where check_id = 'QC07' and param_name = 'min_years';
        ut.expect(findings()).to_be_empty();
    end short_series_not_analysed;

    -- The trend series is 100 x 0.9^(year - 2010), so after log10 it is the
    -- line 2 + (year - 2010) x log10(0.9): slope log10(0.9), and intercept
    -- 2 - 2010 x log10(0.9). The API draws its trend line from this view.
    procedure trend_view_gives_fitted_line is
        l_years     number;
        l_intercept number;
        l_slope     number;
    begin
        add_trend;
        select n_years, intercept, slope into l_years, l_intercept, l_slope
          from qc07_trend
         where country_code = 'XA' and pollutant_code = 'NOX' and sector_code = 'S1';
        ut.expect(l_years).to_equal(10);
        ut.expect(l_slope).to_be_within(1e-9).of_(log(10, 0.9));
        ut.expect(l_intercept).to_be_within(1e-6).of_(2 - 2010 * log(10, 0.9));
    end trend_view_gives_fitted_line;

end ut_qc07_time_series;
/
