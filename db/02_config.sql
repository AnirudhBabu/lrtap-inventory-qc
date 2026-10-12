-- Fixed reference data and the check catalogue.
-- Sources are cited by the abbreviations defined in docs/SOURCES.md.

------------------------------------------------------------------------------
-- Notation keys (RG2022 para. 12)
------------------------------------------------------------------------------
insert into ref_notation_key values ('NE', 'Not estimated: emissions occur but have not been estimated', 'RG2022 para. 12(a)');
insert into ref_notation_key values ('IE', 'Included elsewhere: estimated but reported under another category', 'RG2022 para. 12(b)');
insert into ref_notation_key values ('C',  'Confidential: reporting could disclose confidential information', 'RG2022 para. 12(c)');
insert into ref_notation_key values ('NA', 'Not applicable: the activity occurs but does not emit this pollutant', 'RG2022 para. 12(d)');
insert into ref_notation_key values ('NO', 'Not occurring: the category or process does not occur in the Party', 'RG2022 para. 12(e)');
insert into ref_notation_key values ('NR', 'Not relevant: reporting not strictly required, e.g. before a base year', 'RG2022 para. 12(f)');

------------------------------------------------------------------------------
-- Checks (see docs/CHECKS.md for the reasoning behind each one)
------------------------------------------------------------------------------
insert into qc_check (check_id, title, severity, view_name) values
    ('QC01', 'Required cell missing', 'ERROR', 'QC01_MISSING_CELL');
insert into qc_check (check_id, title, severity, view_name) values
    ('QC02', 'Zero reported instead of a notation key', 'WARNING', 'QC02_ZERO_VALUE');
insert into qc_check (check_id, title, severity, view_name) values
    ('QC03', 'Emissions reported as Not Estimated', 'WARNING', 'QC03_NOT_ESTIMATED');
insert into qc_check (check_id, title, severity, view_name) values
    ('QC04', 'Negative emission', 'ERROR', 'QC04_NEGATIVE_VALUE');
insert into qc_check (check_id, title, severity, view_name) values
    ('QC05', 'Sectors do not sum to the national total', 'ERROR', 'QC05_SECTOR_SUM');
insert into qc_check (check_id, title, severity, view_name) values
    ('QC06', 'Particle size classes out of order', 'ERROR', 'QC06_PM_ORDER');
insert into qc_check (check_id, title, severity, view_name) values
    ('QC07', 'Time-series dip or jump', 'WARNING', 'QC07_TIME_SERIES');

insert into qc_param values ('QC05', 'rel_tol', 0.001,
    'Provisional: allows for rounding in reported values. To be calibrated on the real data.');
insert into qc_param values ('QC06', 'rel_tol', 0.001,
    'Provisional: avoids flagging classes that are equal before rounding.');
insert into qc_param values ('QC07', 'z_threshold', 2,
    'Residual more than 2 standard deviations from the mean residual (CEIP-M2025 p. 17).');
insert into qc_param values ('QC07', 'materiality_share', 0.03,
    'Only values above 3 % of the national total are reviewed (CEIP-M2025 p. 17).');
insert into qc_param values ('QC07', 'min_years', 3,
    'Only series with at least three years of data are analysed (CEIP-M2025 p. 17).');
insert into qc_param values ('QC07', 'min_abs_log_resid', 0.041393,
    'log10(1.1). This project''s guard against flagging floating-point noise in series that fit their trend exactly.');

commit;
