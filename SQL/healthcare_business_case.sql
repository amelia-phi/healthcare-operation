/* ============================================================================
   Healthcare Operations Dashboard — Business Case Query Set
   Full context for each request: healthcare_business_case_scenarios.md
   ============================================================================ */

-- REQUEST 1:
-- Calculate total ED presentations by state and financial year.


-- REQUEST 2:
-- Classify hospitals into performance tiers (Critical / Poor / Acceptable /
-- Strong) based on pct_seen_on_time, with counts and average performance
-- per tier, per financial year.


-- REQUEST 3:
-- Rank hospitals within each state by average pct_within_4hrs for the
-- latest financial year. Return only the top 3 hospitals per state.


-- REQUEST 4:
-- For each hospital, calculate each admission category's % contribution
-- to that hospital's total admissions, ranked highest to lowest.


-- REQUEST 5:
-- Create a scalar function returning overnight_stays / total_stays per
-- hospital/year (NULL-safe). Use it in a report across all hospital/year
-- combinations.


-- REQUEST 6:
-- Create a stored procedure that takes a hospital and financial year and
-- returns one summary row: admissions, average length of stay, and ED
-- performance (pct_seen_on_time, pct_within_4hrs). Return no rows if the
-- hospital has no data for that year.
-- Test with:
-- EXEC GetHospitalYearSummary @Hospital = 'Bendigo Health Care Group [Anne Caudle]', @FinancialYear = '2022-23';


-- REQUEST 7:
-- Create a stored procedure using dynamic SQL that pivots total ED
-- presentations by the last 6 financial years, one row per state, columns
-- ordered most recent to oldest. Must remain correct as new years are added.


-- REQUEST 8:
-- Per state, count distinct specialised services offered and count of
-- distinct hospitals delivering at least one specialised service.


-- REQUEST 9:
-- For each hospital/category/financial year, calculate total admissions
-- alongside prior-year admissions and % change year-over-year.


-- REQUEST 10:
-- Flag any hospital/financial_year/category combination with more than
-- one row of source data, returning hospital, year, category, and how
-- many conflicting rows exist.