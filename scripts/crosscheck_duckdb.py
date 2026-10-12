"""Runs the project's own SQL on DuckDB against the EEA file.

Oracle is the system of record: db/ is written for it and the utPLSQL suite
tests it there. This script exists for two reasons:
  1. it gives results on a laptop without an Oracle database, and
  2. comparing its findings with the Oracle run's is a check that the
     results come from the rules, not from one engine's quirks.

It does not re-implement anything. It reads the SQL files in db/, translates
them with sqlglot, and patches the three Oracle-only constructs listed in
ORACLE_ONLY below.

Run:  pip install duckdb sqlglot
      python3 scripts/crosscheck_duckdb.py data/raw/CLRTAP_NFR19_V26_1_GF.csv
Writes data/results/findings_duckdb.csv and prints a summary.
"""

import re
import sys
from pathlib import Path

import duckdb
import sqlglot

ROOT = Path(__file__).resolve().parent.parent
OUT_DIR = ROOT / "data/results"

# Oracle constructs with no direct DuckDB translation, as sqlglot prints them,
# and their DuckDB equivalents.
ORACLE_ONLY = [
    # row generator 1900..2100 (CONNECT BY LEVEL)
    (r"SELECT 1899 \+ level AS year FROM dual CONNECT BY level <= 201",
     "SELECT range AS year FROM range(1900, 2101)"),
    # TO_NUMBER(x DEFAULT NULL ON CONVERSION ERROR); sqlglot drops the DEFAULT
    (r"CAST\(TRIM\(s\.year_text\) AS DOUBLE\)", "TRY_CAST(TRIM(s.year_text) AS DOUBLE)"),
    (r"CAST\(COALESCE\(c\.value_text, c\.notation_text\) AS DOUBLE\)",
     "TRY_CAST(COALESCE(c.value_text, c.notation_text) AS DOUBLE)"),
]

TABLES = """
create table ref_notation_key (notation_key varchar, meaning varchar, source_ref varchar);
create table ref_country (country_code varchar, country_name varchar, in_scope varchar, scope_note varchar);
create table ref_pollutant (pollutant_code varchar, source_name varchar, unit varchar,
    required_from_year integer, source_ref varchar, in_scope varchar default 'Y', scope_note varchar);
create table ref_sector (sector_code varchar, sector_name varchar, role varchar);
create table stg_emission (stg_row_id bigint, country_code varchar, pollutant_name varchar,
    sector_code varchar, year_text varchar, value_text varchar, notation_text varchar);
create table emission (country_code varchar, pollutant_code varchar, sector_code varchar,
    year integer, value double, notation_key varchar,
    primary key (country_code, pollutant_code, sector_code, year));
create table load_reject (stg_row_id bigint, reason varchar);
create table qc_check (check_id varchar, title varchar, severity varchar, view_name varchar, enabled varchar default 'Y');
create table qc_param (check_id varchar, param_name varchar, param_value double, rationale varchar);
create table dual (dummy varchar);
insert into dual values ('X');
"""


def strip_comments(sql):
    return re.sub(r"--[^\n]*", "", sql)


def to_duckdb(oracle_sql):
    out = sqlglot.transpile(strip_comments(oracle_sql), read="oracle", write="duckdb")[0]
    for pattern, replacement in ORACLE_ONLY:
        out = re.sub(pattern, replacement, out)
    if "CONNECT BY" in out:
        sys.exit("an Oracle-only construct was not translated")
    return out


def run_inserts(con, path):
    for stmt in strip_comments(path.read_text()).split(";"):
        if stmt.strip().lower().startswith("insert"):
            con.execute(to_duckdb(stmt))


def create_views(con, path):
    for name, body in re.findall(r"create or replace view (\w+) as\n(.*?);\n", path.read_text(), re.S):
        if name == "qc_finding_summary":  # reads run ids, which this script does not keep
            continue
        con.execute(f"create view {name} as {to_duckdb(body)}")


def main(csv_path):
    con = duckdb.connect()
    con.execute(TABLES)
    run_inserts(con, ROOT / "db/02_config.sql")
    run_inserts(con, ROOT / "db/03_reference_data.sql")
    create_views(con, ROOT / "db/04_checks.sql")
    create_views(con, ROOT / "db/05_loader.sql")

    # Same columns the Oracle external table stages (scripts/load_and_check.sql).
    con.execute("""
        insert into stg_emission
        select row_number() over (), countryCode, pollutantName, sectorCode, year, value, notation
        from read_csv(?, delim = '\t', header = true, all_varchar = true, quote = '', escape = '')
    """, [csv_path])

    # Same two statements as inventory_loader.load.
    con.execute("""insert into emission
                   select country_code, pollutant_code, sector_code, year, value, notation_key
                   from stg_emission_classified where reject_reason is null""")
    con.execute("""insert into load_reject
                   select stg_row_id, reject_reason
                   from stg_emission_classified where reject_reason is not null""")

    print("Rows staged:", con.execute("select count(*) from stg_emission").fetchone()[0])
    print("Rows loaded:", con.execute("select count(*) from emission").fetchone()[0])
    print("Rows not loaded, by reason:")
    for reason, n in con.execute("select reason, count(*) from load_reject group by 1 order by 2 desc").fetchall():
        print(f"  {n:>9,}  {reason}")

    # Same loop as qc_runner.run_all.
    con.execute("""create table qc_finding (check_id varchar, country_code varchar, pollutant_code varchar,
                   sector_code varchar, year integer, observed double, expected double, detail varchar)""")
    for check_id, view_name in con.execute(
            "select check_id, view_name from qc_check where enabled = 'Y' order by check_id").fetchall():
        con.execute(f"""insert into qc_finding select ?, country_code, pollutant_code, sector_code,
                        year, observed, expected, detail from {view_name}""", [check_id])

    print("Findings by check:")
    for check_id, title, n in con.execute("""
            select c.check_id, c.title, count(f.check_id) from qc_check c
            left join qc_finding f using (check_id) group by all order by 1""").fetchall():
        print(f"  {check_id}  {n:>9,}  {title}")

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    out = OUT_DIR / "findings_duckdb.csv"
    con.execute(f"copy (select * from qc_finding order by all) to '{out}' (header)")
    db_out = OUT_DIR / "crosscheck.duckdb"
    db_out.unlink(missing_ok=True)
    con.execute(f"attach '{db_out}' as keep")
    for table in ("emission", "load_reject", "qc_finding", "ref_country", "ref_pollutant", "ref_sector", "qc_check"):
        con.execute(f"create table keep.{table} as select * from {table}")
    print(f"Wrote {out.relative_to(ROOT)} and {db_out.relative_to(ROOT)}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    main(sys.argv[1])
