/* ============================================================================
   02_transform.sql
   Healthcare Operations Dashboard — Transform
   Purpose: Clean source tables into staging tables (stg_*). Raw source tables
   are left untouched (ELT pattern, permanent audit trail).

   NOTE: No dedupe logic here. Investigation confirmed every row across all 7
   source tables is genuinely unique once reporting_unit_type is included --
   the earlier "duplicates" were real Hospital vs Local Hospital Network rows,
   not load artifacts. See 00_source_discovery_findings.md for details.

   Actual transform work needed:
   1. Parse median_time / p90_time ("X hrs Y mins" text) into numeric minutes
   2. Derive locality (Regional/Metropolitan) from peer_group text
   3. Derive is_suppressed boolean from each table's headline _flag column
   ============================================================================ */

USE healthcare_operations;

DROP TABLE IF EXISTS dbo.stg_admissions;
DROP TABLE IF EXISTS dbo.stg_average_length_of_stay;
DROP TABLE IF EXISTS dbo.stg_ed_presentations;
DROP TABLE IF EXISTS dbo.stg_ed_seen_on_time;
DROP TABLE IF EXISTS dbo.stg_ed_time_in_ed;
DROP TABLE IF EXISTS dbo.stg_ed_within_4hrs;
DROP TABLE IF EXISTS dbo.stg_specialised_services;


/* ----------------------------------------------------------------------------
   stg_admissions
   No parsing/derivation needed beyond is_suppressed.
---------------------------------------------------------------------------- */
SELECT *,
    CASE WHEN number_of_admissions_flag = 'suppressed_small_count' THEN 1 ELSE 0 END AS is_suppressed
INTO dbo.stg_admissions
FROM dbo.admissions;


/* ----------------------------------------------------------------------------
   stg_average_length_of_stay
   is_suppressed derived from avg_los_days_flag (the headline ALOS metric).
   No locality here -- this table only has the coarse peer_group (ALOS
   scheme), no regional/metropolitan qualifier to parse.
---------------------------------------------------------------------------- */
SELECT *,
    CASE WHEN avg_los_days_flag = 'suppressed_small_count' THEN 1 ELSE 0 END AS is_suppressed
INTO dbo.stg_average_length_of_stay
FROM dbo.average_length_of_stay;


/* ----------------------------------------------------------------------------
   stg_ed_presentations
   No flag-worthy headline metric beyond presentations count itself.
---------------------------------------------------------------------------- */
SELECT *,
    CASE WHEN number_of_presentations_flag = 'suppressed_small_count' THEN 1 ELSE 0 END AS is_suppressed
INTO dbo.stg_ed_presentations
FROM dbo.ed_presentations;


/* ----------------------------------------------------------------------------
   stg_ed_seen_on_time
   Derive locality from peer_group (ED-grain scheme, e.g. "Medium regional
   hospitals"). is_suppressed from pct_seen_on_time_flag (headline metric).
---------------------------------------------------------------------------- */
SELECT *,
    CASE
        WHEN peer_group LIKE '%regional%' THEN 'Regional'
        WHEN peer_group LIKE '%metropolitan%' THEN 'Metropolitan'
        ELSE NULL
    END AS locality,
    CASE WHEN pct_seen_on_time_flag = 'suppressed_small_count' THEN 1 ELSE 0 END AS is_suppressed
INTO dbo.stg_ed_seen_on_time
FROM dbo.ed_seen_on_time;


/* ----------------------------------------------------------------------------
   stg_ed_time_in_ed
   Derive locality + parse median_time/p90_time from "X hrs Y mins" text into
   total minutes (numeric). Confirmed non-numeric values are only '-', 'NP',
   'NP†' (suppression markers) -- these fall through to NULL since they don't
   match the '%hrs%mins%' pattern.
---------------------------------------------------------------------------- */
SELECT *,
    CASE
        WHEN peer_group LIKE '%regional%' THEN 'Regional'
        WHEN peer_group LIKE '%metropolitan%' THEN 'Metropolitan'
        ELSE NULL
    END AS locality,
    CASE
        WHEN median_time LIKE '%hrs%mins%' THEN
            TRY_CAST(LEFT(median_time, CHARINDEX(' hrs', median_time) - 1) AS INT) * 60
            + TRY_CAST(
                SUBSTRING(
                    median_time,
                    CHARINDEX(' hrs', median_time) + 5,
                    CHARINDEX(' mins', median_time) - (CHARINDEX(' hrs', median_time) + 5)
                ) AS INT
              )
        ELSE NULL
    END AS median_time_minutes,
    CASE
        WHEN p90_time LIKE '%hrs%mins%' THEN
            TRY_CAST(LEFT(p90_time, CHARINDEX(' hrs', p90_time) - 1) AS INT) * 60
            + TRY_CAST(
                SUBSTRING(
                    p90_time,
                    CHARINDEX(' hrs', p90_time) + 5,
                    CHARINDEX(' mins', p90_time) - (CHARINDEX(' hrs', p90_time) + 5)
                ) AS INT
              )
        ELSE NULL
    END AS p90_time_minutes
INTO dbo.stg_ed_time_in_ed
FROM dbo.ed_time_in_ed;

-- Sanity check: confirm the parser worked as expected
SELECT TOP 20 median_time, median_time_minutes, p90_time, p90_time_minutes
FROM dbo.stg_ed_time_in_ed
WHERE median_time IS NOT NULL
ORDER BY NEWID();

-- Confirm nothing "hrs/mins"-shaped fell through to NULL unexpectedly
SELECT COUNT(*) AS unexpected_nulls
FROM dbo.stg_ed_time_in_ed
WHERE median_time LIKE '%hrs%mins%' AND median_time_minutes IS NULL;


/* ----------------------------------------------------------------------------
   stg_ed_within_4hrs
   Derive locality + is_suppressed from pct_within_4hrs_flag.
---------------------------------------------------------------------------- */
SELECT *,
    CASE
        WHEN peer_group LIKE '%regional%' THEN 'Regional'
        WHEN peer_group LIKE '%metropolitan%' THEN 'Metropolitan'
        ELSE NULL
    END AS locality,
    CASE WHEN pct_within_4hrs_flag = 'suppressed_small_count' THEN 1 ELSE 0 END AS is_suppressed
INTO dbo.stg_ed_within_4hrs
FROM dbo.ed_within_4hrs;


/* ----------------------------------------------------------------------------
   stg_specialised_services
   No flag column exists on this source table -- no is_suppressed possible.
---------------------------------------------------------------------------- */
SELECT *
INTO dbo.stg_specialised_services
FROM dbo.specialised_services;


/* ============================================================================
   Row count check -- every staging table should exactly match its raw source
   now that there's no dedupe step.
   ============================================================================ */
SELECT 'admissions' AS table_name, (SELECT COUNT(*) FROM dbo.admissions) AS raw_rows, (SELECT COUNT(*) FROM dbo.stg_admissions) AS staged_rows
UNION ALL
SELECT 'average_length_of_stay', (SELECT COUNT(*) FROM dbo.average_length_of_stay), (SELECT COUNT(*) FROM dbo.stg_average_length_of_stay)
UNION ALL
SELECT 'ed_presentations', (SELECT COUNT(*) FROM dbo.ed_presentations), (SELECT COUNT(*) FROM dbo.stg_ed_presentations)
UNION ALL
SELECT 'ed_seen_on_time', (SELECT COUNT(*) FROM dbo.ed_seen_on_time), (SELECT COUNT(*) FROM dbo.stg_ed_seen_on_time)
UNION ALL
SELECT 'ed_time_in_ed', (SELECT COUNT(*) FROM dbo.ed_time_in_ed), (SELECT COUNT(*) FROM dbo.stg_ed_time_in_ed)
UNION ALL
SELECT 'ed_within_4hrs', (SELECT COUNT(*) FROM dbo.ed_within_4hrs), (SELECT COUNT(*) FROM dbo.stg_ed_within_4hrs)
UNION ALL
SELECT 'specialised_services', (SELECT COUNT(*) FROM dbo.specialised_services), (SELECT COUNT(*) FROM dbo.stg_specialised_services);

/* ============================================================================
   END OF 02_transform.sql
   Next: review the sanity checks above, then build 03_load_model.sql
   ============================================================================ */