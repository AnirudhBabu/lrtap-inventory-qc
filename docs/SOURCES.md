# Sources

Every rule and threshold in [CHECKS.md](CHECKS.md) cites one of these documents.
Paragraph and page numbers were checked against the documents themselves.

**RG2022** — UNECE Executive Body, *Decision 2022/1: Guidelines for Reporting
Emissions and Projections Data under the Convention on Long-range Transboundary
Air Pollution*. In ECE/EB.AIR/150/Add.1, issued 27 March 2023; adopted at the
42nd session of the Executive Body, Geneva, 12–16 December 2022; applies to
reporting in 2024 and later years.
<https://ceip.at/fileadmin/inhalte/ceip/1_reporting_guidelines2014/ece_eb.air_150_add.1_2305250e__1_.pdf>

**EB2018** — UNECE Executive Body, *Decision 2018/1: Updated methods and
procedures for the technical reviews of air pollutant emission inventories
reported under the Convention*. In ECE/EB.AIR/142/Add.1, issued 22 February 2019.
<https://www.ceip.at/fileadmin/inhalte/ceip/00_pdf_other/2023/ece_eb.air_142_add.1-1902937e.pdf>

**CEIP-M2025** — EMEP Centre on Emission Inventories and Projections (CEIP),
*Methodology report 2025* (inventory review procedures and data processing).
<https://www.ceip.at/fileadmin/inhalte/ceip/00_pdf_other/2025/ceip_methodology_report_2025_compressed.pdf>

**FI-IIR2025** — Finnish Environment Institute (Syke), *Finland's Informative
Inventory Report 2025: Air Pollutant Emissions 1980–2023 under the UNECE CLRTAP
and the EU NECD, Part I – General A*, March 2025. Cited for its QA/QC rule on
particle size ordering (p. 44).
<https://ckan.ymparisto.fi/fi/dataset/af3e311e-ff30-45d0-bf50-27e9955fa8ca/resource/21f6f454-b743-4b52-8bf8-bfaa7ac671ec/download/fi-iir-2025-part-1a-general.pdf>

**CEIP-EU-S3-2017** — CEIP, *Stage 3 review report 2017: European Union*.
Cited for how the EU inventory fills gaps in Member State data (paras. 9, 33, 42).
<https://www.ceip.at/fileadmin/inhalte/ceip/00_pdf_other/2017_s3/eu-stage3reviewreport-2017.pdf>

## Data

**EEA-LRTAP-2026** — European Environment Agency, *National emissions reported to
the Convention on Long-range Transboundary Air Pollution (LRTAP Convention), 2026*,
edition 01.00, published 29 June 2026, coverage 1980–2024, NFR19 format,
licence CC BY 4.0. DOI: 10.2909/f74a566a-0fe9-44fd-969e-d864e3ff364e.
<https://sdi.eea.europa.eu/catalogue/srv/api/records/f74a566a-0fe9-44fd-969e-d864e3ff364e>

Units in this dataset, as stated in its metadata:

| Unit | Pollutants |
|------|------------|
| Gg (kt) | CO, NH3, NMVOC, NOx (as NO2), SOx (as SO2), PM10, PM2.5, TSP, BC |
| Mg (t) | As, Cd, Cr, Cu, Hg, Ni, Pb, Se, Zn, the four indicator PAHs, total PAHs |
| kg | HCB, PCBs |
| g I-TEQ | PCDD/F (dioxins and furans) |

**File used.** `CLRTAP_NFR19_V26_1_GF.csv`, from the archive
`eea_t_lrtap-convention_p_1980-2024_v01_r00.zip` behind the record's "Download
all files" link (<https://sdi.eea.europa.eu/datashare/s/ot4TQCkALbXQEnB/download>).
SHA-256 `b4f04584358f36b6b643976593bfe0b400e174c00827bb45066a4e3da008c505`,
426,434,388 bytes; scripts/fetch_data.sh checks both. 4,511,772 rows; UTF-8 with a byte-order mark; tab-separated; CRLF line ends; no
quoting. Columns, as documented in **EEA-TD** below: countryCode, country,
pollutantName, sectorCode, year, value, unit, notation, parentSectorCode,
sectorName. (The table definition also lists a datasetId column, which this
file does not have.)

**EEA-TD** — EEA, *LRTAP Table definition* (xlsx attached to the dataset's
metadata record). Kept in this repository as docs/eea/LRTAP_Table_definition.xlsx.
It is the source of the sector, pollutant, unit and notation-key code lists.

### Note on the data: what "GF" probably means

The file name ends in `_GF`, which neither the metadata nor the table
definition explains. The dataset is described as consistent with the European
Union's submission, and the EU fills gaps in Member State data, mainly from the
Parties' own earlier or other official submissions (CEIP-EU-S3-2017 paras. 9,
42), primarily where values were reported before (para. 33). That every
numeric EU27 cell equals the sum of the 27 Member States fits this. That no
reporting Party has an empty cell is not evidence either way: RG2022 para. 12
asks for exactly that, and the five Parties outside the EU have none either.
This project therefore
treats the data as **possibly gap-filled**: a finding describes this
consolidated dataset, and is not necessarily present in the Party's own
submission. Confirming against a Party's submission on CEIP's database would
settle it for any single finding.

## Source notes

- The CEIP reporting-instructions page labels the current guidelines with a
  different document symbol (ECE/EB.AIR/156/Add.3). The paragraph numbers in
  this project were verified against ECE/EB.AIR/150/Add.1 only.
- The CEIP methodology report states that 127 NFR sectors sum to the national
  total and that 8 memo items, 3 of them natural sources, are excluded
  (CEIP-M2025 p. 7). The sector list is not typed in by hand: it comes from
  EEA-TD and the dataset's own flag, and scripts/make_reference_data.py stops
  unless the result matches those counts. It does.
