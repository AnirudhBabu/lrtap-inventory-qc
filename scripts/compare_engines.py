"""Compares the findings of the Oracle run with those of the DuckDB run.

Both runs execute the same SQL from db/, so they should report the same
findings. A finding is identified by its check, country, pollutant, sector,
year and, for checks that can report one cell more than once (QC06), its
detail text. The script reports findings present in only one run, and the
largest relative difference in the numbers attached to matched findings.

Run:  uv run scripts/compare_engines.py \\
          data/results/findings_oracle.csv data/results/findings_duckdb.csv
Exits with 1 if any finding is in only one of the files. Small differences
in the numbers are expected: Oracle computes in decimal, DuckDB in binary
floating point, and DuckDB adds in parallel, so the last digits of a sum can
even differ between two DuckDB runs.
"""

import csv
import re
import sys
from collections import Counter

# QC07's detail text contains a z-score, which the two engines format
# differently (Oracle "3", DuckDB "3.0"); compare the number, not the text.
Z_SCORE = re.compile(r"[0-9.]+(?= standard deviations)")


def read(path):
    findings = {}
    with open(path, newline="", encoding="utf-8") as f:
        rows = csv.reader(f)
        next(rows)  # header
        for row in rows:
            # Tolerate an unquoted comma in the detail, the last column.
            check, country, pollutant, sector, year, observed, expected = row[:7]
            detail = ",".join(row[7:])
            z = Z_SCORE.search(detail)
            key = (check.upper(), country, pollutant, sector, int(year), Z_SCORE.sub("z", detail))
            values = (to_float(observed), to_float(expected), float(z.group()) if z else None)
            findings.setdefault(key, []).append(values)
    return findings


def to_float(text):
    return float(text) if text.strip() else None


def rel_diff(a, b):
    if a is None or b is None:
        return 0.0 if a is b else float("inf")
    if a == b:
        return 0.0
    return abs(a - b) / max(abs(a), abs(b))


def main(oracle_path, duckdb_path):
    oracle, duck = read(oracle_path), read(duckdb_path)
    only_oracle = [k for k in oracle if k not in duck]
    only_duck = [k for k in duck if k not in oracle]
    matched = [k for k in oracle if k in duck]

    per_check = Counter(k[0] for k in oracle)
    print(f"{'check':6} {'oracle':>8} {'duckdb':>8}")
    for check in sorted(set(per_check) | {k[0] for k in duck}):
        print(f"{check:6} {per_check[check]:>8,} {sum(1 for k in duck if k[0] == check):>8,}")

    worst = [0.0, 0.0, 0.0]
    for k in matched:
        for a, b in zip(sorted(oracle[k], key=str), sorted(duck[k], key=str)):
            for i in range(3):
                worst[i] = max(worst[i], rel_diff(a[i], b[i]))

    print(f"\nmatched findings:      {len(matched):,}")
    print(f"only in Oracle run:    {len(only_oracle):,}")
    print(f"only in DuckDB run:    {len(only_duck):,}")
    print("largest relative difference on matched findings:")
    print(f"  observed {worst[0]:.2e}   expected {worst[1]:.2e}   QC07 z-score {worst[2]:.2e}")
    for k in (only_oracle + only_duck)[:10]:
        print("  unmatched:", k)
    sys.exit(1 if only_oracle or only_duck else 0)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
