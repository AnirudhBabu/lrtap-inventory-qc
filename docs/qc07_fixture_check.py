"""Independent check of the expected results in tests/ut_qc07_time_series.sql.

The QC07 tests assert which years are flagged. Those expectations should not
come from the code under test, so this script recomputes them with nothing
but the Python standard library, following CEIP-M2025 p. 17:

    log10 the values, fit a least-squares line against year, and flag a year
    whose residual is more than 2 sample standard deviations from the mean
    residual.

Run:  uv run docs/qc07_fixture_check.py
"""

import math
import statistics

Z_THRESHOLD = 2
MIN_ABS_LOG_RESID = math.log10(1.1)


def flagged_years(series):
    """Years in {year: value} that QC07 should flag, ignoring materiality."""
    years = sorted(series)
    logs = [math.log10(series[y]) for y in years]
    mean_x = statistics.fmean(years)
    mean_y = statistics.fmean(logs)
    slope = sum((x - mean_x) * (y - mean_y) for x, y in zip(years, logs)) / sum(
        (x - mean_x) ** 2 for x in years
    )
    intercept = mean_y - slope * mean_x
    residuals = [y - (intercept + slope * x) for x, y in zip(years, logs)]
    mean_r = statistics.fmean(residuals)
    sd = statistics.stdev(residuals)
    result = {}
    for year, r in zip(years, residuals):
        z = abs(r - mean_r) / sd if sd > 0 else 0.0
        if abs(r - mean_r) > Z_THRESHOLD * sd and abs(r - mean_r) > MIN_ABS_LOG_RESID:
            result[year] = round(z, 3)
    return result


def trend(spike_year=None, factor=1.0):
    return {
        y: 100 * 0.9 ** (y - 2010) * (factor if y == spike_year else 1.0)
        for y in range(2010, 2020)
    }


def main():
    cases = {}

    cases["spike"] = (trend(2015, 3), {2015})
    cases["smooth"] = (trend(), set())

    dip = {y: 50.0 for y in range(2010, 2020)}
    dip[2017] = 10.0
    cases["dip"] = (dip, {2017})

    without_two = trend(2015, 3)
    del without_two[2012]  # zero in the test, excluded
    del without_two[2013]  # NE in the test, excluded
    cases["zeros_and_keys_excluded"] = (without_two, {2015})

    ok = True
    for name, (series, expected) in cases.items():
        got = flagged_years(series)
        status = "ok" if set(got) == expected else "MISMATCH"
        ok &= status == "ok"
        print(f"{name:26s} flagged={got}  expected={sorted(expected)}  {status}")

    # Samuelson's inequality: in any n values, no value is more than
    # (n - 1) / sqrt(n) sample standard deviations from their mean. With a
    # threshold of 2, a year can only be flagged when the series has at least
    # 6 values, so CEIP's 3-year minimum never decides the outcome.
    smallest = next(n for n in range(2, 100) if (n - 1) / math.sqrt(n) > Z_THRESHOLD)
    print(f"smallest series length that can be flagged at z={Z_THRESHOLD}: {smallest}")

    raise SystemExit(0 if ok else 1)


if __name__ == "__main__":
    main()
