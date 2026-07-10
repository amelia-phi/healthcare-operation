/* ============================================================
   00_source_discovery.sql
   Healthcare Operations Dashboard — Source Discovery & Assessment
   Database: healthcare_operations (SQL Server, 192.168.126.119)
   Purpose: Profile the 7 loaded source tables before any Transform
            or Data Modeling work begins. Read-only — no DDL/DML.
   ============================================================ */

USE healthcare_operations;

/* ============================================================
   SECTION 1: Metadata — every table, column, type, max length
   (Baseline inventory. Re-run any time to confirm schema hasn't drifted.)
   ============================================================ */
SELECT
    t.name AS table_name,
    c.name AS column_name,
    ty.name AS data_type,
    c.max_length,
    c.is_nullable
FROM sys.tables t
JOIN sys.columns c ON c.object_id = t.object_id
JOIN sys.types ty ON ty.user_type_id = c.user_type_id
ORDER BY t.name, c.column_id;


/* ============================================================
   SECTION 2: Row counts per table
   Sanity check against expected source file row counts.
   ============================================================ */
SELECT 'admissions' AS table_name, COUNT(*) AS row_count FROM dbo.admissions
UNION ALL SELECT 'average_length_of_stay', COUNT(*) FROM dbo.average_length_of_stay
UNION ALL SELECT 'ed_presentations', COUNT(*) FROM dbo.ed_presentations
UNION ALL SELECT 'ed_seen_on_time', COUNT(*) FROM dbo.ed_seen_on_time
UNION ALL SELECT 'ed_time_in_ed', COUNT(*) FROM dbo.ed_time_in_ed
UNION ALL SELECT 'ed_within_4hrs', COUNT(*) FROM dbo.ed_within_4hrs
UNION ALL SELECT 'specialised_services', COUNT(*) FROM dbo.specialised_services
ORDER BY table_name;


/* ============================================================
   SECTION 3: Distinct values on shared dimension-like columns
   These columns repeat across tables and are candidates for
   shared dims (dim_hospital, dim_year, dim_category). Mismatched
   spellings or codes here will break joins later.
   ============================================================ */

-- 3a. state — should be a small, consistent set of AU state codes
SELECT 'admissions' AS source_table, state, COUNT(*) AS n FROM dbo.admissions GROUP BY state
UNION ALL SELECT 'average_length_of_stay', state, COUNT(*) FROM dbo.average_length_of_stay GROUP BY state
UNION ALL SELECT 'ed_presentations', state, COUNT(*) FROM dbo.ed_presentations GROUP BY state
UNION ALL SELECT 'ed_seen_on_time', state, COUNT(*) FROM dbo.ed_seen_on_time GROUP BY state
UNION ALL SELECT 'ed_time_in_ed', state, COUNT(*) FROM dbo.ed_time_in_ed GROUP BY state
UNION ALL SELECT 'ed_within_4hrs', state, COUNT(*) FROM dbo.ed_within_4hrs GROUP BY state
UNION ALL SELECT 'specialised_services', state, COUNT(*) FROM dbo.specialised_services GROUP BY state
ORDER BY state, source_table;

-- 3b. reporting_unit_type — hospital / peer group / national level etc.
SELECT 'admissions' AS source_table, reporting_unit_type, COUNT(*) AS n FROM dbo.admissions GROUP BY reporting_unit_type
UNION ALL SELECT 'average_length_of_stay', reporting_unit_type, COUNT(*) FROM dbo.average_length_of_stay GROUP BY reporting_unit_type
UNION ALL SELECT 'ed_presentations', reporting_unit_type, COUNT(*) FROM dbo.ed_presentations GROUP BY reporting_unit_type
UNION ALL SELECT 'ed_seen_on_time', reporting_unit_type, COUNT(*) FROM dbo.ed_seen_on_time GROUP BY reporting_unit_type
UNION ALL SELECT 'ed_time_in_ed', reporting_unit_type, COUNT(*) FROM dbo.ed_time_in_ed GROUP BY reporting_unit_type
UNION ALL SELECT 'ed_within_4hrs', reporting_unit_type, COUNT(*) FROM dbo.ed_within_4hrs GROUP BY reporting_unit_type
UNION ALL SELECT 'specialised_services', reporting_unit_type, COUNT(*) FROM dbo.specialised_services GROUP BY reporting_unit_type
ORDER BY reporting_unit_type, source_table;

-- 3c. financial_year / year range per table — do the periods line up?
SELECT 'admissions' AS source_table, MIN(financial_year) AS min_fy, MAX(financial_year) AS max_fy, MIN(year) AS min_yr, MAX(year) AS max_yr FROM dbo.admissions
UNION ALL SELECT 'average_length_of_stay', MIN(financial_year), MAX(financial_year), MIN(year), MAX(year) FROM dbo.average_length_of_stay
UNION ALL SELECT 'ed_presentations', MIN(financial_year), MAX(financial_year), MIN(year), MAX(year) FROM dbo.ed_presentations
UNION ALL SELECT 'ed_seen_on_time', MIN(financial_year), MAX(financial_year), MIN(year), MAX(year) FROM dbo.ed_seen_on_time
UNION ALL SELECT 'ed_time_in_ed', MIN(financial_year), MAX(financial_year), MIN(year), MAX(year) FROM dbo.ed_time_in_ed
UNION ALL SELECT 'ed_within_4hrs', MIN(financial_year), MAX(financial_year), MIN(year), MAX(year) FROM dbo.ed_within_4hrs
UNION ALL SELECT 'specialised_services', MIN(financial_year), MAX(financial_year), MIN(year), MAX(year) FROM dbo.specialised_services
ORDER BY source_table;

-- 3d. category / triage_category / patient_cohort / specialised_service
-- (each table's "what is this row measuring" column — check for overlap/typos)
SELECT DISTINCT category FROM dbo.admissions ORDER BY category;
SELECT DISTINCT category FROM dbo.average_length_of_stay ORDER BY category;
SELECT DISTINCT triage_category FROM dbo.ed_presentations ORDER BY triage_category;
SELECT DISTINCT triage_category FROM dbo.ed_seen_on_time ORDER BY triage_category;
SELECT DISTINCT patient_cohort FROM dbo.ed_time_in_ed ORDER BY patient_cohort;
SELECT DISTINCT patient_cohort FROM dbo.ed_within_4hrs ORDER BY patient_cohort;
SELECT DISTINCT specialised_service FROM dbo.specialised_services ORDER BY specialised_service;

-- 3e. peer_group — only present on 4 of the 7 tables
SELECT DISTINCT peer_group FROM dbo.average_length_of_stay ORDER BY peer_group;
SELECT DISTINCT peer_group FROM dbo.ed_seen_on_time ORDER BY peer_group;
SELECT DISTINCT peer_group FROM dbo.ed_time_in_ed ORDER BY peer_group;
SELECT DISTINCT peer_group FROM dbo.ed_within_4hrs ORDER BY peer_group;


/* ============================================================
   SECTION 4: Null / blank rate on measure and flag columns
   Flag columns are likely footnote/suppression markers (e.g. small
   counts suppressed for privacy) — worth understanding before Transform.
   ============================================================ */

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN number_of_admissions IS NULL THEN 1 ELSE 0 END) AS null_measure,
    SUM(CASE WHEN number_of_admissions_flag IS NOT NULL THEN 1 ELSE 0 END) AS flagged_rows,
    COUNT(DISTINCT number_of_admissions_flag) AS distinct_flag_values
FROM dbo.admissions;

SELECT DISTINCT number_of_admissions_flag FROM dbo.admissions WHERE number_of_admissions_flag IS NOT NULL;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN avg_los_days IS NULL THEN 1 ELSE 0 END) AS null_avg_los,
    SUM(CASE WHEN total_stays IS NULL THEN 1 ELSE 0 END) AS null_total_stays,
    SUM(CASE WHEN avg_los_days_flag IS NOT NULL THEN 1 ELSE 0 END) AS flagged_rows
FROM dbo.average_length_of_stay;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN number_of_presentations IS NULL THEN 1 ELSE 0 END) AS null_measure,
    SUM(CASE WHEN number_of_presentations_flag IS NOT NULL THEN 1 ELSE 0 END) AS flagged_rows
FROM dbo.ed_presentations;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN pct_seen_on_time IS NULL THEN 1 ELSE 0 END) AS null_pct,
    SUM(CASE WHEN pct_seen_on_time_flag IS NOT NULL THEN 1 ELSE 0 END) AS flagged_rows
FROM dbo.ed_seen_on_time;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN median_time IS NULL THEN 1 ELSE 0 END) AS null_median,
    SUM(CASE WHEN p90_time IS NULL THEN 1 ELSE 0 END) AS null_p90
FROM dbo.ed_time_in_ed;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN pct_within_4hrs IS NULL THEN 1 ELSE 0 END) AS null_pct,
    SUM(CASE WHEN pct_within_4hrs_flag IS NOT NULL THEN 1 ELSE 0 END) AS flagged_rows
FROM dbo.ed_within_4hrs;

SELECT
    COUNT(*) AS total_rows,
    SUM(CASE WHEN number_of_units IS NULL THEN 1 ELSE 0 END) AS null_units
FROM dbo.specialised_services;


/* ============================================================
   SECTION 5: Sample rows — eyeball actual data shape and
   figure out what the _flag columns actually contain.
   ============================================================ */
SELECT TOP 20 * FROM dbo.admissions;
SELECT TOP 20 * FROM dbo.average_length_of_stay;
SELECT TOP 20 * FROM dbo.ed_presentations;
SELECT TOP 20 * FROM dbo.ed_seen_on_time;
SELECT TOP 20 * FROM dbo.ed_time_in_ed;
SELECT TOP 20 * FROM dbo.ed_within_4hrs;
SELECT TOP 20 * FROM dbo.specialised_services;


/* ============================================================
   SECTION 6: Candidate key / grain check
   If any of these return rows, the listed column combination is
   NOT unique — the fact table grain needs an extra column.
   ============================================================ */

-- admissions: expected grain = reporting_unit + financial_year + category
SELECT reporting_unit, financial_year, category, COUNT(*) AS n
FROM dbo.admissions
GROUP BY reporting_unit, financial_year, category
HAVING COUNT(*) > 1;

-- average_length_of_stay: expected grain = reporting_unit + financial_year + category
SELECT reporting_unit, financial_year, category, COUNT(*) AS n
FROM dbo.average_length_of_stay
GROUP BY reporting_unit, financial_year, category
HAVING COUNT(*) > 1;

-- ed_presentations: expected grain = reporting_unit + financial_year + triage_category
SELECT reporting_unit, financial_year, triage_category, COUNT(*) AS n
FROM dbo.ed_presentations
GROUP BY reporting_unit, financial_year, triage_category
HAVING COUNT(*) > 1;

-- ed_seen_on_time: expected grain = reporting_unit + financial_year + triage_category
SELECT reporting_unit, financial_year, triage_category, COUNT(*) AS n
FROM dbo.ed_seen_on_time
GROUP BY reporting_unit, financial_year, triage_category
HAVING COUNT(*) > 1;

-- ed_time_in_ed: expected grain = reporting_unit + financial_year + patient_cohort
SELECT reporting_unit, financial_year, patient_cohort, COUNT(*) AS n
FROM dbo.ed_time_in_ed
GROUP BY reporting_unit, financial_year, patient_cohort
HAVING COUNT(*) > 1;

-- ed_within_4hrs: expected grain = reporting_unit + financial_year + patient_cohort
SELECT reporting_unit, financial_year, patient_cohort, COUNT(*) AS n
FROM dbo.ed_within_4hrs
GROUP BY reporting_unit, financial_year, patient_cohort
HAVING COUNT(*) > 1;

-- specialised_services: expected grain = reporting_unit + financial_year + specialised_service
SELECT reporting_unit, financial_year, specialised_service, COUNT(*) AS n
FROM dbo.specialised_services
GROUP BY reporting_unit, financial_year, specialised_service
HAVING COUNT(*) > 1;


/* ============================================================
   SECTION 7: Cross-table consistency check
   Do reporting_unit names match exactly across all 7 tables, so
   they can share one dim_hospital? Anything listed here is in one
   table's set but not another's — investigate spelling/coverage.
   ============================================================ */

-- Units present in admissions but missing from average_length_of_stay
SELECT DISTINCT reporting_unit FROM dbo.admissions
EXCEPT
SELECT DISTINCT reporting_unit FROM dbo.average_length_of_stay;

-- Units present in average_length_of_stay but missing from admissions
SELECT DISTINCT reporting_unit FROM dbo.average_length_of_stay
EXCEPT
SELECT DISTINCT reporting_unit FROM dbo.admissions;

-- Units present in ed_presentations but missing from ed_within_4hrs
SELECT DISTINCT reporting_unit FROM dbo.ed_presentations
EXCEPT
SELECT DISTINCT reporting_unit FROM dbo.ed_within_4hrs;

-- Units present in ed_within_4hrs but missing from ed_presentations
SELECT DISTINCT reporting_unit FROM dbo.ed_within_4hrs
EXCEPT
SELECT DISTINCT reporting_unit FROM dbo.ed_presentations;

-- Full list of distinct reporting_unit values across ALL tables combined
-- (this becomes the candidate source list for dim_hospital)
SELECT DISTINCT reporting_unit FROM dbo.admissions
UNION
SELECT DISTINCT reporting_unit FROM dbo.average_length_of_stay
UNION
SELECT DISTINCT reporting_unit FROM dbo.ed_presentations
UNION
SELECT DISTINCT reporting_unit FROM dbo.ed_seen_on_time
UNION
SELECT DISTINCT reporting_unit FROM dbo.ed_time_in_ed
UNION
SELECT DISTINCT reporting_unit FROM dbo.ed_within_4hrs
UNION
SELECT DISTINCT reporting_unit FROM dbo.specialised_services
ORDER BY reporting_unit;

/* ============================================================
   END OF 00_source_discovery.sql
   Next: review results above, then build 01_schema.sql
   ============================================================ */

SELECT n, COUNT(*) AS how_many_groups
FROM (
    SELECT reporting_unit, financial_year, category, number_of_admissions, number_of_admissions_flag, COUNT(*) AS n
    FROM dbo.admissions
    GROUP BY reporting_unit, financial_year, category, number_of_admissions, number_of_admissions_flag
) x
GROUP BY n;