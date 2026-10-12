# LRTAP inventory QC

Automated quality checks for national air pollutant emission inventories
reported under the UNECE Air Convention (CLRTAP), built in Oracle SQL and
PL/SQL and tested with utPLSQL.

The data is the European Environment Agency's consolidated dataset of what
32 countries reported for 1980–2024 (see [docs/SOURCES.md](docs/SOURCES.md)).
**What the checks found is in [docs/FINDINGS.md](docs/FINDINGS.md).**
The checks follow the rules those countries report under and the review
methods used by CEIP, the EMEP centre in Vienna that reviews these
inventories each year.

## What it checks

| ID   | Check | Severity |
|------|-------|----------|
| QC01 | A required cell has neither a value nor a notation key | ERROR |
| QC02 | A cell reports 0 instead of a notation key | WARNING |
| QC03 | A cell is reported as Not Estimated (NE) | WARNING |
| QC04 | An emission is negative | ERROR |
| QC05 | NFR sectors do not add up to the national total | ERROR |
| QC06 | Particle size classes are out of order (BC ≤ PM2.5 ≤ PM10 ≤ TSP) | ERROR |
| QC07 | A value is a dip or jump against its own time series | WARNING |

[docs/CHECKS.md](docs/CHECKS.md) gives, for every check, the reason it matters,
the source of the rule (to the paragraph or page), and why each threshold has
the value it does. Where this project departs from or adds to a source, it says
so.

## Design

A few decisions shape everything else:

- **Constraints for what is meaningless, checks for what is suspicious.** A
  row that cannot be read at all (unknown notation key, no year) is rejected
  by the loader with a reason. A row that can be stored but looks wrong is
  kept, and a check reports it. Dropping suspicious rows would hide them and
  break other checks, such as sector sums.
- **One check, one view.** Each check is a single SQL view that a scientist
  can read on its own. All views return the same columns, so a small runner
  stores every check's findings in one table. Adding a check means writing a
  view and adding a row to `qc_check`.
- **Thresholds are data, with reasons.** Every tunable number lives in
  `qc_param` next to a sentence saying where it comes from.
- **Notation keys are never turned into numbers.** `NE` (not estimated) and
  `NO` (not occurring) mean very different things, and both are different
  from zero.

## Layout

```
db/        schema, config, reference data, check views, loader, runner
           (install.sql runs them in order)
tests/     utPLSQL test packages (install.sql installs them)
docs/      CHECKS.md (each rule and its source), SOURCES.md, FINDINGS.md,
           the EEA's table definition, and an independent check of QC07's
           expected test results
scripts/   run_tests.sh             all tests on a fresh Oracle Free container
           run_on_data.sh           load the EEA file into Oracle and run the checks
           fetch_data.sh            download the EEA file if missing, and verify it
           make_reference_data.py   build db/03_reference_data.sql from the EEA's code lists
           crosscheck_duckdb.py     run the same SQL on DuckDB, to compare engines
           compare_engines.py       compare the Oracle and DuckDB findings
pyproject.toml, uv.lock             Python dependencies (see Requirements)
```

## Requirements

Python dependencies are managed with [uv](https://docs.astral.sh/uv/).
`pyproject.toml` lists them and `uv.lock` pins their exact versions, so
every run uses the versions the findings were produced with. Install uv,
then run any Python script through it:

```
uv run scripts/crosscheck_duckdb.py data/raw/CLRTAP_NFR19_V26_1_GF.csv
```

uv creates the project environment (`.venv/`) and installs the locked
versions on first use; no separate install step is needed. The pin on
sqlglot matters: `scripts/crosscheck_duckdb.py` adapts the SQL text sqlglot
prints, and another version may print it differently.

The Oracle side runs in Docker and needs tools uv cannot install. Each
script checks for the ones it uses before starting, and stops with a
message naming any that are missing:

| Tool | Used by |
|------|---------|
| Docker, running | `run_tests.sh`, `run_on_data.sh` |
| Java 11 or later | `run_tests.sh` (the utPLSQL command-line runner) |
| curl, unzip | `run_tests.sh`, `run_on_data.sh`, `fetch_data.sh` |
| sha256sum or shasum | `fetch_data.sh` |

## Running it on the data

```
scripts/run_on_data.sh
```

On first run this downloads the EEA file (about 1.3 GB) and checks it is
byte for byte the file the findings were produced from. It then loads the
file into Oracle, runs every check, and writes
`data/results/findings_oracle.csv`. `scripts/fetch_data.sh` does the
download step on its own, for the DuckDB cross-check:

```
scripts/fetch_data.sh
uv run scripts/crosscheck_duckdb.py data/raw/CLRTAP_NFR19_V26_1_GF.csv
uv run scripts/compare_engines.py \
    data/results/findings_oracle.csv data/results/findings_duckdb.csv
```

The DuckDB cross-check runs the same SQL on a second engine.
`scripts/compare_engines.py` compares the two runs' findings; on the 2026 file
they are identical (docs/FINDINGS.md).

## Running the tests

```
scripts/run_tests.sh
```

This starts a fresh Oracle Database Free container, installs utPLSQL, the
project and the tests, and runs every test. GitHub Actions runs the same
script on every push.

The tests were written before the code they test. Each uses a small dataset
whose expected result is worked out by hand; for the time-series check, the
expected results are also reproduced independently in
`docs/qc07_fixture_check.py`.

## Data licence

The EEA dataset is published under CC BY 4.0. It is not included in this
repository; `scripts/fetch_data.sh` downloads it.
