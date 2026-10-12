# QC check catalogue

Every check in this project answers one question about a national air pollutant
inventory reported under the UNECE Air Convention (CLRTAP). For each check this
file states what it looks for, why that matters, where the rule comes from, and
which parameters it uses and why they have the values they do.

Two principles decide where a rule lives:

- **A rule that makes a row meaningless is a constraint.** If a value cannot be
  interpreted at all (an unknown notation key, a year that is not a number), the
  loader rejects the row into `load_reject` with a reason. It never reaches the
  `emission` table.
- **A rule that makes a row suspicious is a check.** If a value can be stored but
  should be explained (a negative emission, a sudden jump), the row is kept and
  the check records a finding. Dropping suspicious rows would hide them and would
  also break other checks, such as sector sums.

Source abbreviations are defined in [SOURCES.md](SOURCES.md).

## Summary

| ID   | Check                               | Severity | Primary source                          |
|------|-------------------------------------|----------|-----------------------------------------|
| QC01 | Required cell missing               | ERROR    | RG2022 para. 12, para. 38               |
| QC02 | Zero reported instead of a key      | WARNING  | RG2022 para. 12; CEIP-M2025 p. 14       |
| QC03 | Emissions reported as Not Estimated | WARNING  | RG2022 para. 12(a); CEIP-M2025 p. 14    |
| QC04 | Negative emission                   | ERROR    | Physical constraint (see below)         |
| QC05 | Sectors do not sum to national total| ERROR    | CEIP-M2025 p. 7; RG2022 paras. 24–26    |
| QC06 | Particle size classes out of order  | ERROR    | RG2022 para. 7(f); FI-IIR2025 p. 44     |
| QC07 | Time-series dip or jump             | WARNING  | CEIP-M2025 p. 17; EB2018 para. 11(c)    |

Severities:

- **ERROR**: violates a reporting rule or a logical/physical constraint.
- **WARNING**: allowed, but a reviewer would ask for an explanation.

## QC01 Required cell missing

**Question.** Is there a cell the Party was required to fill that has neither a
number nor a notation key?

**Why it matters.** The Reporting Guidelines say cells must not be left empty
(RG2022 para. 12). An empty cell is ambiguous: the reader cannot tell whether the
source does not occur, was not estimated, or was simply lost in processing.

**Rule.** For each country present in the data, every combination of
(pollutant, sector, year) inside the required scope must exist in `emission`.

**Scope.**

| Pollutants | Required years | Source |
|------------|----------------|--------|
| SOx, NOx, NMVOC, NH3, CO | 1990 to latest year in the data | RG2022 paras. 7(a)–(e), 38 |
| PM2.5, PM10 | 2000 to latest year in the data | RG2022 paras. 7(f), 38 |
| Cd, Pb, Hg, PAHs, PCDD/F, PCBs, HCB | 1990 to latest year in the data | RG2022 paras. 7(g)–(m), 43; CEIP stage 1 tables use 1990 onward |
| BC, TSP | not required (encouraged) | RG2022 paras. 8(a), 8(b) |
| Other heavy metals (As, Cr, Cu, Ni, Se, Zn) | not required | not listed in RG2022 para. 7 |

Which pollutants are required, and from which year, is held as data in
`ref_pollutant.required_from_year` (null means not required), each row citing
its paragraph. PAHs are taken as the four indicator compounds and their total,
as reported in the EEA dataset.

Sectors in scope are the NFR sectors and memo items in `ref_sector`
(roles `SECTOR` and `MEMO`), which is loaded from the NFR19 template. The
national total is not required as a separate cell here; QC05 checks it.

**Known limitation.** Heavy metal and POP obligations depend on which Aarhus
protocols a Party has ratified (RG2022 para. 43). This project does not hold
ratification status, so it applies the CEIP stage 1 convention of 1990 onward to
all Parties. Findings for these pollutants may therefore include cells a Party
was not obliged to fill. `NR` (not relevant) exists precisely for this case.

## QC02 Zero reported instead of a key

**Question.** Is a cell reported as the number 0?

**Why it matters.** RG2022 para. 12 says the value 0 should not be used; a
notation key says *why* there is no number. CEIP stage 1 also flags pollutants
where more than 10 % of cells are zero (CEIP-M2025 p. 14).

**Rule.** `value = 0`. One finding per cell. The share of zeros per country and
pollutant appears in the summary view so the CEIP 10 % criterion can be read off
directly.

**Note.** CEIP counts any number below 0.005 as "0" because its tables are
displayed at that precision. This project stores full precision and only flags
exact zeros, so a reported 0.003 is not treated as zero.

## QC03 Emissions reported as Not Estimated

**Question.** Is a cell reported as `NE`?

**Why it matters.** `NE` means the activity exists but emissions were not
estimated (RG2022 para. 12(a)). It is a legitimate key, but it is a known gap
in the inventory, which is why CEIP stage 1 lists every NE cell
(CEIP-M2025 p. 14).

**Rule.** `notation_key = 'NE'`.

## QC04 Negative emission

**Question.** Is an emission value below zero?

**Why it matters.** Every NFR category for air pollutants is a source: it
describes mass released to the atmosphere. Unlike greenhouse gas inventories,
which have land-use sinks, there is no removal category in which a negative air
pollutant emission would be meaningful. A negative number is almost certainly a
sign error or a unit error.

**Source.** None of the documents consulted states this rule explicitly. It is
derived from the definition of the NFR source categories, and is labelled as such
rather than attributed to a source that does not say it.

**Rule.** `value < 0`.

## QC05 Sectors do not sum to the national total

**Question.** Does the reported national total equal the sum of the sectors that
make it up?

**Why it matters.** The NFR sectors are summed to give the national total, and
memo items are excluded from it (CEIP-M2025 p. 7). The Guidelines name what the
memo items are: aviation cruise (para. 24), international maritime shipping
(para. 25), and natural sources such as forest fires and volcanoes (para. 26).
A mismatch means either a sector was dropped, a memo item was wrongly added, or
the total was edited by hand.

**Rule.** For each (country, pollutant, year) with a numeric national total:

    |sum(sectors with in_national_total = 'Y') − total| > rel_tol × |total|

Only numeric sector values are summed; notation keys contribute nothing.

**Parameters.**

| Parameter | Value | Reason |
|-----------|-------|--------|
| `rel_tol` | 0.001 | Provisional. Allows for rounding in reported values. To be calibrated against the distribution of discrepancies in the real data, and the calibration recorded here. |

## QC06 Particle size classes out of order

**Question.** For the same sector and year, is BC ≤ PM2.5 ≤ PM10 ≤ TSP?

**Why it matters.** PM2.5 is defined as particles with an aerodynamic diameter of
2.5 µm or less and PM10 as 10 µm or less (RG2022 para. 7(f)), so every PM2.5
particle is also a PM10 particle. TSP has no size cut-off and therefore contains
both. Black carbon is a component of fine particulate matter. Finland's national
inventory QA/QC tooling flags exactly this ordering (FI-IIR2025 p. 44).

**Rule.** For every pair of classes where the first is finer than the second
(six pairs among BC, PM2.5, PM10, TSP), in the same country, sector and year,
where both cells are numeric:

    finer > coarser × (1 + rel_tol)

All pairs are compared, not only neighbours, so PM2.5 above TSP is still found
when PM10 is reported as a notation key. Pairs where either side is a notation
key are skipped, because there is nothing to compare. The finding is recorded
on the finer class's cell.

**Parameters.**

| Parameter | Value | Reason |
|-----------|-------|--------|
| `rel_tol` | 0.001 | Provisional. Avoids flagging values that are equal before rounding. |

## QC07 Time-series dip or jump

**Question.** Does a value depart sharply from the trend of its own time series?

**Why it matters.** Completeness and consistency of the time series is one of the
four stage 2 review areas (EB2018 para. 11(c)). Sudden dips and jumps often come
from a changed method applied to only some years, a missing source in one year,
or a unit error.

**Method.** This reproduces the CEIP stage 2 test (CEIP-M2025 p. 17):

1. Take one series: a (country, pollutant, sector) over all years with a
   positive numeric value. NFR sectors and the national total are analysed;
   memo items are not, since they are not part of the total the materiality
   test refers to.
2. Transform values with log10.
3. Fit a least-squares line of log10(value) against year.
4. Flag a year if its residual is more than 2 standard deviations of all the
   series' residuals away from their mean.
5. Only report a year if the flagged value is more than 3 % of that year's
   national total for the pollutant. CEIP applies this to "the flagged data
   value" for "the respective year", and this project does the same.
6. Only assess series with at least 3 years of data.

**Choices this project adds, and why.**

- **Sample standard deviation** (Oracle `STDDEV`). The CEIP text does not say
  whether it uses sample or population standard deviation. The sample version
  is slightly larger, so it flags slightly less.
- **Minimum residual of log10(1.1).** A series that follows its trend exactly
  has residuals that are floating-point noise (around 1e-16). Two standard
  deviations of noise is still noise, and without a floor such a series can
  produce meaningless flags. The floor means a value must also be at least
  about 10 % off its trend line. This guard is not in the CEIP method.
- **Zeros and notation keys are excluded**, because log10 is undefined for them.
- **Years without a numeric national total are not assessed**, because the 3 %
  materiality test cannot be computed. QC01 and QC05 report those gaps.

**Consequences of the CEIP method worth knowing.**

- *Deep dips can escape review.* Because the 3 % test is applied to the
  flagged value itself, a dip that pushes a value below 3 % of the total is
  not reported, however sharp it is. A test pins this behaviour down
  (`dip_below_materiality_not_reported`). Testing the trend value instead
  would catch such dips; it would be a departure from CEIP and is not done.
- *Short series cannot be flagged at all.* In any set of n numbers, no value
  lies more than (n − 1)/√n sample standard deviations from their mean
  (Samuelson's inequality). With a threshold of 2 that bound only exceeds 2
  from n = 6, so a series needs at least 6 years before any year can be
  flagged, and CEIP's 3-year minimum never decides the outcome. It is kept
  as a parameter for fidelity. `docs/qc07_fixture_check.py` computes the 6.

**Not reproduced.** CEIP also flags whole series whose standard deviation exceeds
20 % of the series mean (CEIP-M2025 p. 17). That is a property of the series, not
of a single year, and is left for a later version.

**Parameters.**

| Parameter | Value | Reason |
|-----------|-------|--------|
| `z_threshold` | 2 | CEIP-M2025 p. 17 |
| `materiality_share` | 0.03 | CEIP-M2025 p. 17 |
| `min_years` | 3 | CEIP-M2025 p. 17 |
| `min_abs_log_resid` | 0.041393 (= log10 1.1) | This project; see above |

## Planned, not yet implemented

- **Recalculations** between two editions of the dataset, flagged at ±10 %
  (CEIP-M2025 p. 15; EB2018 para. 11(d)). Needs the previous edition loaded
  alongside the current one.
- **Comparison with an independent inventory** such as EDGAR at national-total
  level (EB2018 para. 11(b)).
