/* ============================================================================
   03_load_model.sql
   Healthcare Operations Dashboard - Load Model
   Purpose: Populate the star schema (dim_year, dim_hospital, dim_category,
   and 5 fact tables) from the cleaned staging tables (stg_*).

   Business rule applied throughout: where a reporting_unit has both a
   'Hospital' row and a 'Local Hospital Network' row for the same grain,
   prefer 'Hospital'. Fall back to 'Local Hospital Network' only when no
   'Hospital' row exists for that combination (e.g. Kilmore and District
   Hospital, which only reports at LHN level in the source data). This
   guarantees one row per hospital per grain with zero double-counting and
   zero silently dropped hospitals. See 00_source_discovery_findings.md for
   the investigation that led to this rule.
   ============================================================================ */

USE healthcare_operations;

-- Clear existing model data (safe to re-run this script repeatedly)
DELETE FROM dbo.fact_specialised_services;
DELETE FROM dbo.fact_ed_time;
DELETE FROM dbo.fact_ed_volume;
DELETE FROM dbo.fact_alos;
DELETE FROM dbo.fact_admissions;
DELETE FROM dbo.dim_category;
DELETE FROM dbo.dim_hospital;
DELETE FROM dbo.dim_year;


/* ============================================================================
   DIM_YEAR
   ============================================================================ */
INSERT INTO dbo.dim_year (financial_year, year)
SELECT DISTINCT financial_year, year
FROM (
    SELECT financial_year, year FROM dbo.stg_admissions
    UNION
    SELECT financial_year, year FROM dbo.stg_average_length_of_stay
    UNION
    SELECT financial_year, year FROM dbo.stg_ed_presentations
    UNION
    SELECT financial_year, year FROM dbo.stg_ed_seen_on_time
    UNION
    SELECT financial_year, year FROM dbo.stg_ed_time_in_ed
    UNION
    SELECT financial_year, year FROM dbo.stg_ed_within_4hrs
    UNION
    SELECT financial_year, year FROM dbo.stg_specialised_services
) all_years;


/* ============================================================================
   DIM_HOSPITAL
   One row per reporting_unit. reporting_unit_type/state taken from whichever
   source row is 'Hospital' type when available, else 'Local Hospital Network'.
   peer_group_alos sourced from stg_average_length_of_stay.
   peer_group_ed / locality sourced from stg_ed_seen_on_time (confirmed
   consistent with ed_time_in_ed / ed_within_4hrs in discovery).
   ============================================================================ */
WITH all_units AS (
    SELECT reporting_unit, reporting_unit_type, state FROM dbo.stg_admissions
    UNION ALL SELECT reporting_unit, reporting_unit_type, state FROM dbo.stg_average_length_of_stay
    UNION ALL SELECT reporting_unit, reporting_unit_type, state FROM dbo.stg_ed_presentations
    UNION ALL SELECT reporting_unit, reporting_unit_type, state FROM dbo.stg_ed_seen_on_time
    UNION ALL SELECT reporting_unit, reporting_unit_type, state FROM dbo.stg_ed_time_in_ed
    UNION ALL SELECT reporting_unit, reporting_unit_type, state FROM dbo.stg_ed_within_4hrs
    UNION ALL SELECT reporting_unit, reporting_unit_type, state FROM dbo.stg_specialised_services
),
preferred_unit AS (
    SELECT reporting_unit, reporting_unit_type, state,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM all_units
),
alos_peer_group AS (
    SELECT reporting_unit, MAX(peer_group) AS peer_group_alos
    FROM dbo.stg_average_length_of_stay
    GROUP BY reporting_unit
),
ed_peer_group AS (
    SELECT reporting_unit, MAX(peer_group) AS peer_group_ed, MAX(locality) AS locality
    FROM dbo.stg_ed_seen_on_time
    GROUP BY reporting_unit
)
INSERT INTO dbo.dim_hospital (reporting_unit, reporting_unit_type, state, peer_group_alos, peer_group_ed, locality)
SELECT u.reporting_unit, u.reporting_unit_type, u.state, a.peer_group_alos, e.peer_group_ed, e.locality
FROM preferred_unit u
LEFT JOIN alos_peer_group a ON a.reporting_unit = u.reporting_unit
LEFT JOIN ed_peer_group e ON e.reporting_unit = u.reporting_unit
WHERE u.rn = 1;


/* ============================================================================
   DIM_CATEGORY
   Four classification schemes, one category_type each.
   ============================================================================ */
INSERT INTO dbo.dim_category (category_type, category_name)
SELECT 'admission_category', category FROM dbo.stg_admissions GROUP BY category
UNION
SELECT 'triage', triage_category FROM (
    SELECT triage_category FROM dbo.stg_ed_presentations
    UNION
    SELECT triage_category FROM dbo.stg_ed_seen_on_time
) t GROUP BY triage_category
UNION
SELECT 'patient_cohort', patient_cohort FROM (
    SELECT patient_cohort FROM dbo.stg_ed_time_in_ed
    UNION
    SELECT patient_cohort FROM dbo.stg_ed_within_4hrs
) c GROUP BY patient_cohort
UNION
SELECT 'specialised_service', specialised_service FROM dbo.stg_specialised_services GROUP BY specialised_service;


/* ============================================================================
   FACT_ADMISSIONS
   ============================================================================ */
WITH preferred AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit, financial_year, category
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM dbo.stg_admissions
)
INSERT INTO dbo.fact_admissions (hospital_key, year_key, category_key, number_of_admissions, is_suppressed, admission_flag_raw)
SELECT h.hospital_key, y.year_key, c.category_key, p.number_of_admissions, p.is_suppressed, p.number_of_admissions_flag
FROM preferred p
JOIN dbo.dim_hospital h ON h.reporting_unit = p.reporting_unit
JOIN dbo.dim_year y ON y.financial_year = p.financial_year
JOIN dbo.dim_category c ON c.category_name = p.category AND c.category_type = 'admission_category'
WHERE p.rn = 1;


/* ============================================================================
   FACT_ALOS
   ============================================================================ */
WITH preferred AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit, financial_year, category
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM dbo.stg_average_length_of_stay
)
INSERT INTO dbo.fact_alos (
    hospital_key, year_key, category_key,
    total_stays, total_stays_flag_raw,
    overnight_stays, overnight_stays_flag_raw,
    pct_overnight_stays, pct_overnight_stays_flag_raw,
    avg_los_days, avg_los_days_flag_raw, is_suppressed,
    peer_group_avg_los_days, peer_group_avg_los_days_flag_raw,
    overnight_bed_days, overnight_bed_days_flag_raw
)
SELECT
    h.hospital_key, y.year_key, c.category_key,
    p.total_stays, p.total_stays_flag,
    p.overnight_stays, p.overnight_stays_flag,
    p.pct_overnight_stays, p.pct_overnight_stays_flag,
    p.avg_los_days, p.avg_los_days_flag, p.is_suppressed,
    p.peer_group_avg_los_days, p.peer_group_avg_los_days_flag,
    p.overnight_bed_days, p.overnight_bed_days_flag
FROM preferred p
JOIN dbo.dim_hospital h ON h.reporting_unit = p.reporting_unit
JOIN dbo.dim_year y ON y.financial_year = p.financial_year
JOIN dbo.dim_category c ON c.category_name = p.category AND c.category_type = 'admission_category'
WHERE p.rn = 1;


/* ============================================================================
   FACT_ED_VOLUME
   Combines stg_ed_presentations (total_presentations) and stg_ed_seen_on_time
   (seen_on_time_presentations, pct_seen_on_time). Each source deduped by the
   Hospital/LHN preference independently, then joined on hospital/year/triage.
   ============================================================================ */
WITH preferred_pres AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit, financial_year, triage_category
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM dbo.stg_ed_presentations
),
preferred_sot AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit, financial_year, triage_category
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM dbo.stg_ed_seen_on_time
)
INSERT INTO dbo.fact_ed_volume (
    hospital_key, year_key, category_key,
    total_presentations, total_presentations_flag_raw,
    seen_on_time_presentations, seen_on_time_presentations_flag_raw,
    pct_seen_on_time, pct_seen_on_time_flag_raw, is_suppressed,
    peer_group_avg_pct, peer_group_avg_pct_flag_raw
)
SELECT
    h.hospital_key, y.year_key, c.category_key,
    p.number_of_presentations, p.number_of_presentations_flag,
    s.number_of_presentations, s.number_of_presentations_flag,
    s.pct_seen_on_time, s.pct_seen_on_time_flag, s.is_suppressed,
    s.peer_group_avg_pct, s.peer_group_avg_pct_flag
FROM (SELECT * FROM preferred_pres WHERE rn = 1) p
FULL JOIN (SELECT * FROM preferred_sot WHERE rn = 1) s
    ON p.reporting_unit = s.reporting_unit
    AND p.financial_year = s.financial_year
    AND p.triage_category = s.triage_category
JOIN dbo.dim_hospital h ON h.reporting_unit = COALESCE(p.reporting_unit, s.reporting_unit)
JOIN dbo.dim_year y ON y.financial_year = COALESCE(p.financial_year, s.financial_year)
JOIN dbo.dim_category c ON c.category_name = COALESCE(p.triage_category, s.triage_category) AND c.category_type = 'triage';


/* ============================================================================
   FACT_ED_TIME
   Combines stg_ed_time_in_ed (median/p90 minutes) and stg_ed_within_4hrs
   (pct_within_4hrs). Joined on hospital/year/patient_cohort.
   ============================================================================ */
WITH preferred_time AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit, financial_year, patient_cohort
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM dbo.stg_ed_time_in_ed
),
preferred_4hrs AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit, financial_year, patient_cohort
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM dbo.stg_ed_within_4hrs
)
INSERT INTO dbo.fact_ed_time (
    hospital_key, year_key, category_key,
    number_of_presentations, number_of_presentations_flag_raw,
    median_time, p90_time, peer_group_avg_p90_time,
    pct_within_4hrs, pct_within_4hrs_flag_raw, is_suppressed,
    peer_group_avg_pct, peer_group_avg_pct_flag_raw
)
SELECT
    h.hospital_key, y.year_key, c.category_key,
    t.number_of_presentations, t.number_of_presentations_flag,
    t.median_time_minutes, t.p90_time_minutes, t.peer_group_avg_p90_time,
    w.pct_within_4hrs, w.pct_within_4hrs_flag, w.is_suppressed,
    w.peer_group_avg_pct, w.peer_group_avg_pct_flag
FROM (SELECT * FROM preferred_time WHERE rn = 1) t
FULL JOIN (SELECT * FROM preferred_4hrs WHERE rn = 1) w
    ON t.reporting_unit = w.reporting_unit
    AND t.financial_year = w.financial_year
    AND t.patient_cohort = w.patient_cohort
JOIN dbo.dim_hospital h ON h.reporting_unit = COALESCE(t.reporting_unit, w.reporting_unit)
JOIN dbo.dim_year y ON y.financial_year = COALESCE(t.financial_year, w.financial_year)
JOIN dbo.dim_category c ON c.category_name = COALESCE(t.patient_cohort, w.patient_cohort) AND c.category_type = 'patient_cohort';


/* ============================================================================
   FACT_SPECIALISED_SERVICES
   ============================================================================ */
WITH preferred AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY reporting_unit, financial_year, specialised_service
            ORDER BY CASE WHEN reporting_unit_type = 'Hospital' THEN 0 ELSE 1 END
        ) AS rn
    FROM dbo.stg_specialised_services
)
INSERT INTO dbo.fact_specialised_services (hospital_key, year_key, category_key, number_of_units)
SELECT h.hospital_key, y.year_key, c.category_key, p.number_of_units
FROM preferred p
JOIN dbo.dim_hospital h ON h.reporting_unit = p.reporting_unit
JOIN dbo.dim_year y ON y.financial_year = p.financial_year
JOIN dbo.dim_category c ON c.category_name = p.specialised_service AND c.category_type = 'specialised_service'
WHERE p.rn = 1;


/* ============================================================================
   Row count check
   ============================================================================ */
SELECT 'dim_year' AS table_name, COUNT(*) AS row_count FROM dbo.dim_year
UNION ALL SELECT 'dim_hospital', COUNT(*) FROM dbo.dim_hospital
UNION ALL SELECT 'dim_category', COUNT(*) FROM dbo.dim_category
UNION ALL SELECT 'fact_admissions', COUNT(*) FROM dbo.fact_admissions
UNION ALL SELECT 'fact_alos', COUNT(*) FROM dbo.fact_alos
UNION ALL SELECT 'fact_ed_volume', COUNT(*) FROM dbo.fact_ed_volume
UNION ALL SELECT 'fact_ed_time', COUNT(*) FROM dbo.fact_ed_time
UNION ALL SELECT 'fact_specialised_services', COUNT(*) FROM dbo.fact_specialised_services;

/* ============================================================================
   END OF 03_load_model.sql
   Next: review row counts above, then build 04_marts.sql
   ============================================================================ */