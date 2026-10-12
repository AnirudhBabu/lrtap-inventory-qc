# Findings: the 2026 EEA LRTAP dataset

**How these numbers were produced.** The checks were run twice on the same
file, by two different database engines executing the same SQL: Oracle
Database Free (`scripts/run_on_data.sh`) and DuckDB
(`scripts/crosscheck_duckdb.py`). Both reported the same findings, cell for
cell, with no finding found by only one engine (`scripts/compare_engines.py`).
The numbers attached to the findings agree to the nine significant digits the
Oracle run exported; the QC07 z-scores agree exactly. That comparison was made
before QC02 was restricted to source categories; applying the restriction to
the Oracle run's QC02 findings selects exactly the 84,949 that DuckDB reports
under the new rule. The figures below total 459,177 findings.

## Question

How consistent is the consolidated air pollutant inventory that 32 European
countries reported under the UNECE Air Convention, judged by the reporting rules
they report under and the automated tests CEIP applies in its review?

## Data

The EEA's *National emissions reported to the LRTAP Convention, 2026*
(1980–2024, NFR19 format; full reference in SOURCES.md). The file has 4,511,772
rows. Every one is accounted for:

| Rows | Outcome |
|-----:|---------|
| 4,065,618 | Loaded: 1,256,853 numbers and 2,808,765 notation keys, for 32 Parties |
| 192,510 | Not loaded: EEA32, an EEA aggregate, not a reporting Party |
| 127,650 | Not loaded: activity data (fuel use), not emissions |
| 125,994 | Not loaded: EU27, which in this file is the exact sum of its 27 Member States (all 76,741 of its numeric cells), so its findings would repeat theirs |

The data may be gap-filled by the EEA (see "Note on the data" in SOURCES.md), so
each finding describes this dataset and is not necessarily present in the
Party's own submission.

Preparing the data also turned up three small defects in the file itself: three
sector codes (`'2G '`, `'2H3 '`, `'1A2gvii '`) carry a trailing space in Norway's
rows (3,255) and Liechtenstein's (279); three of Czechia's cells use the notation
key `iE` in lower case; and the
EEA's own pollutant code list misspells two codes (`bnezo_k_fluoranthene`,
`Ideno_1_2_3_cd_pyrene`). None changes a result: codes are trimmed, keys are
upper-cased, and this project uses its own pollutant codes.

## Results

| Check | Findings | In short |
|-------|---------:|----------|
| QC01 Required cell missing | 0 | No reporting Party has an empty cell. |
| QC02 Zero instead of a notation key | 84,949 | Concentrated: Türkiye reports 0 in 90.1 % of its numeric source cells. |
| QC03 Not estimated (NE) | 365,261 | 245,039 of them in pollutants and years that must be reported. |
| QC04 Negative emission | 2 | Two small negative values in one sector. |
| QC05 Sectors ≠ national total | 121 | All PM10, all in six countries, all with the total above the sector sum. |
| QC06 Size classes out of order | 3,138 | 2,265 are zeros standing in for "not estimated"; 873 are real inversions. |
| QC07 Time-series dip or jump | 5,706 | 27 % fall at the ends of a series, a property of the method. |

### QC02 and QC03: zeros and gaps

The Reporting Guidelines ask for a notation key, never a 0, where there is no
emission (RG2022 para. 12). The check looks at source categories only: NFR
sectors and memo items (see CHECKS.md, QC02). Zeros there are rare in most
countries and concentrated in two: Türkiye (75,686 zero cells, 90.1 % of its
numeric source cells) and Liechtenstein (7,280, 37.1 %). CEIP's stage 1 test
flags a pollutant when more than 10 % of its cells are zero (CEIP-M2025 p. 14);
42 of the 808 country–pollutant combinations with numeric data meet that
criterion, all in these two countries (Liechtenstein 26, Türkiye 16).

Counting every row instead, as a first version of this check did, adds 27,520
zeros: 25,525 in `Adjustments` rows, where 0 means no adjustment was made,
1,250 in national totals for compliance and 745 in national totals that are
zero because everything beneath them is. It would also put five more countries
over CEIP's 10 % line (Austria, Norway, Luxembourg, Poland and Cyprus) purely
because of zero adjustments.

`NE` (emissions occur but were not estimated) is a legitimate key that marks a
known gap. 365,261 cells use it; 245,039 of these are in pollutants and years
the Guidelines require. Norway (25,750), Slovenia (19,860) and Czechia (19,350)
use it most.

### QC04: negative emissions

Two cells, both in sector 1A2f (combustion in non-metallic mineral industries):
Latvia, PCBs, 2024, −0.0027 kg; and Ireland, PCDD/F, 2014, −0.0010 g I-TEQ. Both
are tiny, which suggests rounding or a correction applied to a near-zero value
rather than a sign error in a large source. The check ignores the 27 negative
values in these Parties' `Adjustments` rows, which are negative by design.

### QC05: PM10 totals above their sector sums

Of 27,701 non-zero national totals, 27,580 equal the sum of their 127 sectors to
within 0.001 %, which is rounding. The other 121 are all PM10:

| Country | Years affected | Total above sector sum by |
|---------|----------------|---------------------------|
| Latvia | 35 (1990–2024) | 0.06 % – 5.31 % |
| Slovakia | 35 (1990–2024) | 0.79 % – 3.42 % |
| Luxembourg | 35 (1990–2024) | 0.09 % – 0.72 % |
| Netherlands | 11 (1990–2003) | 0.05 % – 0.15 % |
| Bulgaria | 4 (1991–2021) | 0.02 % – 0.06 % |
| Cyprus | 1 (2017) | 0.01 % |

In every case the total is larger than its sectors, and in three countries the
gap is present in every year. That points to something systematic in how these
PM10 totals were produced, not to scattered errors. No single sector's value
accounts for the gap (checked for Latvia and Slovakia 2024), so it is not one
sector left out of the sum. This dataset alone cannot say more; comparing the
same cells in the countries' own submissions would.

This finding also shows why the tolerance mattered. It was first set at 0.1 %,
a guess, which would have hidden 12 of these 121 cells, all part of the same
pattern. It is now set from the data (CHECKS.md, QC05).

### QC06: particle size classes

By definition, PM2.5 is part of PM10, which is part of TSP (RG2022 para. 7(f)),
and black carbon is part of fine particulate matter. Of the 3,138 findings:

- **2,265 have a coarser class reported as exactly 0** while a finer class is
  positive: Türkiye 2,111 (TSP reported as 0 while PM10 and PM2.5 are positive),
  Ireland 142, Hungary 8, Estonia 4. These are the zeros of QC02 surfacing as a
  contradiction: a 0 used where a notation key such as NE was meant.
- **873 are inversions between two positive values**, in 499 distinct cells
  (one cell can break more than one pair). The finer class exceeds the coarser
  one by a median factor of 1.73 (interquartile range 1.21–4.01). The most
  common are PM2.5 above PM10 (310) and PM2.5 above TSP (248), then black
  carbon above a PM class (307 across three pairs). Estonia (194), Germany
  (118) and Lithuania (84) have the most.

### QC07: what the time-series test actually detects

The test reproduces CEIP's stage 2 method: fit a straight line to log10 of the
series, flag values far from it (CEIP-M2025 p. 17). Of 32,109 series analysed,
3,707 have at least one flagged year, 5,706 flags in all.

27 % of the flags fall on the first or last year of their series, against about
6 % if flags were spread evenly; 1990 alone has 830 and 2024 has 586. When a
series falls steeply and then levels off, a straight line through it misses
most at its ends. Germany's SO2 total shows the effect: 1990 is
flagged at 2.5 standard deviations from the line, but its value of 5,461 kt
sits naturally beside 1991 (3,965 kt) and 1992 (3,237 kt). It is not an error.

Two further properties of the method follow from its definition (CHECKS.md,
QC07): a series needs at least six years before any year can be flagged, so
CEIP's three-year minimum never decides anything; and because materiality is
judged on the flagged value itself, a deep dip can fall below the 3 % threshold
and escape review.

The findings are reported as the method produces them. A comparison with
neighbouring years would target dips and jumps more directly, but it would be a
different method from CEIP's, so it is not used here.

## Limitations

- The data may be gap-filled (see above), so findings describe this dataset.
- Which heavy metals and POPs a Party must report depends on the protocols it
  has ratified (RG2022 para. 43); this project applies one rule to all.
- QC04's rule that no source category can be negative is derived from the
  definition of the source categories, not quoted from a document.

## Reproducing

```
python3 scripts/make_reference_data.py data/raw/CLRTAP_NFR19_V26_1_GF.csv
python3 scripts/crosscheck_duckdb.py   data/raw/CLRTAP_NFR19_V26_1_GF.csv
scripts/run_on_data.sh                 # the same on Oracle
```
