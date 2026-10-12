-- The QC checks. Each check is one view, readable on its own, and every view
-- returns the same columns:
--
--   country_code, pollutant_code, sector_code, year   the cell the finding is about
--   observed, expected                                 numbers being compared, if any
--   detail                                             what was found, in words
--
-- docs/CHECKS.md explains each rule and cites its source.

------------------------------------------------------------------------------
-- QC01 Required cell missing
-- Every required (country, pollutant, sector, year) must have a value or a
-- notation key. Required pollutants and their first year come from
-- ref_pollutant; required sectors are NFR sectors and memo items.
------------------------------------------------------------------------------
create or replace view qc01_missing_cell as
with
latest as (
    select max(year) as latest_year from emission
),
calendar as (
    select 1899 + level as year from dual connect by level <= 201   -- 1900..2100
),
countries as (
    select distinct country_code from emission
),
required_cell as (
    select c.country_code, p.pollutant_code, s.sector_code, y.year
      from countries c
     cross join ref_pollutant p
     cross join ref_sector s
     cross join latest l
      join calendar y
        on y.year between p.required_from_year and l.latest_year
     where p.required_from_year is not null
       and s.role in ('SECTOR', 'MEMO')
)
select r.country_code,
       r.pollutant_code,
       r.sector_code,
       r.year,
       cast(null as number) as observed,
       cast(null as number) as expected,
       'No value or notation key reported for a required cell' as detail
  from required_cell r
 where not exists (
        select 1
          from emission e
         where e.country_code   = r.country_code
           and e.pollutant_code = r.pollutant_code
           and e.sector_code    = r.sector_code
           and e.year           = r.year);

------------------------------------------------------------------------------
-- QC02 Zero reported instead of a notation key
------------------------------------------------------------------------------
create or replace view qc02_zero_value as
select country_code,
       pollutant_code,
       sector_code,
       year,
       value as observed,
       cast(null as number) as expected,
       'Value 0 reported; a notation key should say why there is no emission' as detail
  from emission
 where value = 0;

------------------------------------------------------------------------------
-- QC03 Emissions reported as Not Estimated
------------------------------------------------------------------------------
create or replace view qc03_not_estimated as
select country_code,
       pollutant_code,
       sector_code,
       year,
       cast(null as number) as observed,
       cast(null as number) as expected,
       'Reported as NE: the source exists but was not estimated' as detail
  from emission
 where notation_key = 'NE';

------------------------------------------------------------------------------
-- QC04 Negative emission
-- Only source categories (NFR sectors and memo items) are checked. Rows such
-- as approved adjustments are subtracted from a total and are negative by
-- design.
------------------------------------------------------------------------------
create or replace view qc04_negative_value as
select e.country_code,
       e.pollutant_code,
       e.sector_code,
       e.year,
       e.value as observed,
       cast(null as number) as expected,
       'Negative emission; every NFR category is a source' as detail
  from emission e
  join ref_sector s on s.sector_code = e.sector_code
 where s.role in ('SECTOR', 'MEMO')
   and e.value < 0;

------------------------------------------------------------------------------
-- QC05 Sectors do not sum to the national total
-- observed is the sum of NFR sectors, expected is the reported total.
-- Memo items are excluded; notation keys add nothing.
------------------------------------------------------------------------------
create or replace view qc05_sector_sum as
with
param as (
    select param_value as rel_tol
      from qc_param
     where check_id = 'QC05' and param_name = 'rel_tol'
),
national_total as (
    select e.country_code, e.pollutant_code, e.sector_code, e.year, e.value as total
      from emission e
      join ref_sector s on s.sector_code = e.sector_code
     where s.role = 'TOTAL'
       and e.value is not null
),
sector_sum as (
    select e.country_code, e.pollutant_code, e.year, sum(e.value) as sector_sum
      from emission e
      join ref_sector s on s.sector_code = e.sector_code
     where s.role = 'SECTOR'
     group by e.country_code, e.pollutant_code, e.year
)
select t.country_code,
       t.pollutant_code,
       t.sector_code,
       t.year,
       nvl(s.sector_sum, 0) as observed,
       t.total as expected,
       'Sum of NFR sectors differs from the reported national total' as detail
  from national_total t
  left join sector_sum s
    on s.country_code   = t.country_code
   and s.pollutant_code = t.pollutant_code
   and s.year           = t.year
 cross join param p
 where abs(nvl(s.sector_sum, 0) - t.total) > p.rel_tol * abs(t.total);

------------------------------------------------------------------------------
-- QC06 Particle size classes out of order
-- A finer class must not exceed a coarser one in the same sector and year:
-- BC <= PM2.5 <= PM10 <= TSP. All pairs are compared, so a contradiction is
-- still found when a middle class is reported as a notation key.
-- The finding is reported on the finer class; expected is the coarser value.
------------------------------------------------------------------------------
create or replace view qc06_pm_order as
with
param as (
    select param_value as rel_tol
      from qc_param
     where check_id = 'QC06' and param_name = 'rel_tol'
),
size_class as (
    select 'BC'    as pollutant_code, 1 as size_rank from dual union all
    select 'PM2.5',                   2              from dual union all
    select 'PM10',                    3              from dual union all
    select 'TSP',                     4              from dual
),
classed as (
    select e.country_code, e.pollutant_code, e.sector_code, e.year, e.value, c.size_rank
      from emission e
      join size_class c on c.pollutant_code = e.pollutant_code
     where e.value is not null
)
select fine.country_code,
       fine.pollutant_code,
       fine.sector_code,
       fine.year,
       fine.value   as observed,
       coarse.value as expected,
       fine.pollutant_code || ' exceeds ' || coarse.pollutant_code
           || ', which by definition contains it' as detail
  from classed fine
  join classed coarse
    on coarse.country_code = fine.country_code
   and coarse.sector_code  = fine.sector_code
   and coarse.year         = fine.year
   and coarse.size_rank    > fine.size_rank
 cross join param p
 where fine.value > coarse.value * (1 + p.rel_tol);

------------------------------------------------------------------------------
-- QC07 Time-series dip or jump (CEIP stage 2 method, CEIP-M2025 p. 17)
-- For each series (country, pollutant, sector) of positive values:
-- fit log10(value) = a + b * year, then flag a year whose residual is more
-- than z standard deviations from the mean residual, provided the value is
-- more than materiality_share of that year's national total.
-- observed is the reported value, expected is the trend value.
------------------------------------------------------------------------------
create or replace view qc07_time_series as
with
param as (
    select max(case when param_name = 'z_threshold'       then param_value end) as z_threshold,
           max(case when param_name = 'materiality_share' then param_value end) as materiality_share,
           max(case when param_name = 'min_years'         then param_value end) as min_years,
           max(case when param_name = 'min_abs_log_resid' then param_value end) as min_abs_log_resid
      from qc_param
     where check_id = 'QC07'
),
national_total as (
    select e.country_code, e.pollutant_code, e.year, e.value as total
      from emission e
      join ref_sector s on s.sector_code = e.sector_code
     where s.role = 'TOTAL'
       and e.value is not null
),
series as (
    select e.country_code, e.pollutant_code, e.sector_code, e.year, e.value,
           log(10, e.value) as log_value
      from emission e
      join ref_sector s on s.sector_code = e.sector_code
     where s.role in ('SECTOR', 'TOTAL')
       and e.value > 0
),
fitted as (
    select s.*,
           count(*)                         over (partition by country_code, pollutant_code, sector_code) as n_years,
           regr_intercept(log_value, year)  over (partition by country_code, pollutant_code, sector_code) as intercept,
           regr_slope(log_value, year)      over (partition by country_code, pollutant_code, sector_code) as slope
      from series s
),
residual as (
    select f.*,
           f.log_value - (f.intercept + f.slope * f.year) as resid
      from fitted f
),
scored as (
    select r.*,
           avg(resid)    over (partition by country_code, pollutant_code, sector_code) as mean_resid,
           stddev(resid) over (partition by country_code, pollutant_code, sector_code) as sd_resid
      from residual r
)
select sc.country_code,
       sc.pollutant_code,
       sc.sector_code,
       sc.year,
       sc.value as observed,
       power(10, sc.intercept + sc.slope * sc.year) as expected,
       'Value is ' || to_char(round(abs(sc.resid - sc.mean_resid) / nullif(sc.sd_resid, 0), 2))
           || ' standard deviations from the log-linear trend of its series' as detail
  from scored sc
  join national_total t
    on t.country_code   = sc.country_code
   and t.pollutant_code = sc.pollutant_code
   and t.year           = sc.year
 cross join param p
 where sc.n_years >= p.min_years
   and abs(sc.resid - sc.mean_resid) > p.z_threshold * sc.sd_resid
   and abs(sc.resid - sc.mean_resid) > p.min_abs_log_resid
   and sc.value > p.materiality_share * t.total;

------------------------------------------------------------------------------
-- Summary of a run, for reading results at a glance.
------------------------------------------------------------------------------
create or replace view qc_finding_summary as
select f.run_id,
       f.check_id,
       c.title,
       c.severity,
       f.country_code,
       f.pollutant_code,
       count(*) as findings
  from qc_finding f
  join qc_check c on c.check_id = f.check_id
 group by f.run_id, f.check_id, c.title, c.severity, f.country_code, f.pollutant_code;
