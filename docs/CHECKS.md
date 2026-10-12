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
(roles `SECTOR` and `MEMO`). The national total is not required as a separate
cell here; QC05 checks it.

**On the 2026 EEA data** this check finds nothing: every cell for the 32
reporting Parties has a value or a notation key. The only empty rows in the
file belong to the EU27 and EEA32 aggregates, which are out of scope. The check
is kept because it costs nothing and would catch a gap in a later edition, or in
a Party's own submission (see the note on the data in SOURCES.md).

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

**Rule.** `value = 0`, for NFR sectors and memo items only. One finding per
cell. The CEIP 10 % criterion is a share per country and pollutant, which
docs/FINDINGS.md computes from these findings.

**Why only those rows.** As in QC04, the rows that are not source categories
behave differently. A zero adjustment means no adjustment was made, and a
national total of zero follows from the rows beneath it; neither is a choice
that a notation key could explain. On the 2026 data these rows hold 27,520
zeros (25,525 of them adjustments), enough to push five countries over CEIP's
10 % line on adjustments alone. The Guidelines word the rule for the reporting
tables as a whole, so this is a reading of the rule, made explicit here rather
than hidden in the SQL.

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

**Rule.** `value < 0`, for NFR sectors and memo items only.

**Why only those rows.** The dataset also has an `Adjustments` row: emission
reductions approved for compliance purposes, which the dataset reports as
negative numbers (27 such cells for the 32 Parties in the 2026 file). They are not source
categories, so a negative value there is expected. Checking them would bury the
two genuine negatives the check does find.

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

    |sum(sectors with role SECTOR) − total| > rel_tol × |total|

The total checked is `NATIONAL TOTAL`, the national total for the entire
territory based on fuel sold. Which sectors count toward it is not typed in by
hand: the dataset flags them (`parentSectorCode = 'NATIONAL TOTAL'`), and
`scripts/make_reference_data.py` refuses to proceed unless that gives exactly the
127 summed sectors and 8 memo items CEIP describes (CEIP-M2025 p. 7).

Only numeric sector values are summed; notation keys contribute nothing.

**Parameters.**

| Parameter | Value | Reason |
|-----------|-------|--------|
| `rel_tol` | 0.00001 | Calibrated on the 2026 data; see below. |

**Calibration.** The tolerance was first set at 0.1 %, as a guess. On the 2026
data, the relative gap between total and sector sum falls into two groups:

| Relative gap | National totals |
|--------------|-----------------|
| ≤ 0.001 % | 27,580 |
| 0.001 % – 0.1 % | 12 |
| > 0.1 % | 109 |

(Of 28,446 numeric totals; 745 are zero with a zero sum and are excluded.)

The first group is rounding. Every one of the other 121 is PM10, in six
countries, and in every one the sectors sum to *less* than the total. The 12 in
the middle belong to the same countries and the same pattern, so a 0.1 % tolerance
would have hidden part of one systematic problem. The tolerance is therefore set
at 0.001 %, at the edge of the rounding group.

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
| `rel_tol` | 0.001 | Avoids flagging classes that are equal before rounding. Checked against the 2026 data, see below. |

**Checking the tolerance.** Unlike QC05, the 2026 data shows no natural break.
Of the comparable pairs, 298,181 are in order and 52,960 exactly equal (common
where a source emits only fine particles). Of those out of order, 26 exceed the
coarser class by less than 0.1 % and are not reported; 873 exceed it by more,
852 of them by more than 1 %. The tolerance therefore decides only a handful of
borderline cases, and stays at 0.1 %.

**Zero as the coarser class.** When the coarser class is reported as 0 and the
finer one is positive, the check reports it: a positive PM2.5 inside zero TSP is
still a contradiction. In the 2026 data such findings come almost entirely from
zeros used in place of a notation key (QC02), so docs/FINDINGS.md reports them
separately from inversions between two positive values.

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

Steps 1–3 are the view `qc07_trend`, one row per series; the check reads
from it, and so does the API's series endpoint, so both use the same line.

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

**What it finds on the 2026 data.** 27 % of QC07's findings fall on the first
or last year of their series, where about 6 % would if flags were spread evenly
over years. A single straight line fitted through a curved series, such as a
steep decline that levels off, misses most at its ends. Germany's SO2 total illustrates it:
1990 is flagged at 2.5 standard deviations from the trend line, yet its value
(5,461 kt) sits naturally next to 1991 and 1992 (3,965 and 3,237 kt). The method
is reproduced as published, and this property is reported rather than fixed;
a local comparison with neighbouring years would target dips and jumps more
directly.

**Not reproduced.** CEIP also flags whole series whose standard deviation exceeds
20 % of the series mean (CEIP-M2025 p. 17). That is a property of the series, not
of a single year, and this project does not implement it.

**Parameters.**

| Parameter | Value | Reason |
|-----------|-------|--------|
| `z_threshold` | 2 | CEIP-M2025 p. 17 |
| `materiality_share` | 0.03 | CEIP-M2025 p. 17 |
| `min_years` | 3 | CEIP-M2025 p. 17 |
| `min_abs_log_resid` | 0.041393 (= log10 1.1) | This project; see above |

## Not covered

Two of CEIP's stage 2 review areas are outside this project:

- **Recalculations** between two editions of the dataset, flagged at ±10 %
  (CEIP-M2025 p. 15; EB2018 para. 11(d)). This needs two editions loaded side
  by side.
- **Comparison with an independent inventory**, such as EDGAR, at
  national-total level (EB2018 para. 11(b)).
