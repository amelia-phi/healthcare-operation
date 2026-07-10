USE healthcare_operations;

-- admissions
SELECT n, COUNT(*) AS how_many_groups FROM (
    SELECT reporting_unit, reporting_unit_type, state, financial_year, year, category,
           number_of_admissions, number_of_admissions_flag, COUNT(*) AS n
    FROM dbo.admissions
    GROUP BY reporting_unit, reporting_unit_type, state, financial_year, year, category,
             number_of_admissions, number_of_admissions_flag
) x GROUP BY n;

-- average_length_of_stay
SELECT n, COUNT(*) AS how_many_groups FROM (
    SELECT reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, category,
           total_stays, total_stays_flag, overnight_stays, overnight_stays_flag,
           pct_overnight_stays, pct_overnight_stays_flag, avg_los_days, avg_los_days_flag,
           peer_group_avg_los_days, peer_group_avg_los_days_flag, overnight_bed_days,
           overnight_bed_days_flag, COUNT(*) AS n
    FROM dbo.average_length_of_stay
    GROUP BY reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, category,
             total_stays, total_stays_flag, overnight_stays, overnight_stays_flag,
             pct_overnight_stays, pct_overnight_stays_flag, avg_los_days, avg_los_days_flag,
             peer_group_avg_los_days, peer_group_avg_los_days_flag, overnight_bed_days,
             overnight_bed_days_flag
) x GROUP BY n;

-- ed_presentations
SELECT n, COUNT(*) AS how_many_groups FROM (
    SELECT reporting_unit, reporting_unit_type, state, financial_year, year, triage_category,
           number_of_presentations, number_of_presentations_flag, COUNT(*) AS n
    FROM dbo.ed_presentations
    GROUP BY reporting_unit, reporting_unit_type, state, financial_year, year, triage_category,
             number_of_presentations, number_of_presentations_flag
) x GROUP BY n;

-- ed_seen_on_time
SELECT n, COUNT(*) AS how_many_groups FROM (
    SELECT reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, triage_category,
           number_of_presentations, number_of_presentations_flag, pct_seen_on_time,
           pct_seen_on_time_flag, peer_group_avg_pct, peer_group_avg_pct_flag, COUNT(*) AS n
    FROM dbo.ed_seen_on_time
    GROUP BY reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, triage_category,
             number_of_presentations, number_of_presentations_flag, pct_seen_on_time,
             pct_seen_on_time_flag, peer_group_avg_pct, peer_group_avg_pct_flag
) x GROUP BY n;

-- ed_time_in_ed
SELECT n, COUNT(*) AS how_many_groups FROM (
    SELECT reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, patient_cohort,
           number_of_presentations, number_of_presentations_flag, median_time, p90_time,
           peer_group_avg_p90_time, COUNT(*) AS n
    FROM dbo.ed_time_in_ed
    GROUP BY reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, patient_cohort,
             number_of_presentations, number_of_presentations_flag, median_time, p90_time,
             peer_group_avg_p90_time
) x GROUP BY n;

-- ed_within_4hrs
SELECT n, COUNT(*) AS how_many_groups FROM (
    SELECT reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, patient_cohort,
           number_of_presentations, number_of_presentations_flag, pct_within_4hrs,
           pct_within_4hrs_flag, peer_group_avg_pct, peer_group_avg_pct_flag, COUNT(*) AS n
    FROM dbo.ed_within_4hrs
    GROUP BY reporting_unit, reporting_unit_type, state, peer_group, financial_year, year, patient_cohort,
             number_of_presentations, number_of_presentations_flag, pct_within_4hrs,
             pct_within_4hrs_flag, peer_group_avg_pct, peer_group_avg_pct_flag
) x GROUP BY n;

-- specialised_services
SELECT n, COUNT(*) AS how_many_groups FROM (
    SELECT reporting_unit, reporting_unit_type, state, financial_year, year, specialised_service,
           number_of_units, COUNT(*) AS n
    FROM dbo.specialised_services
    GROUP BY reporting_unit, reporting_unit_type, state, financial_year, year, specialised_service,
             number_of_units
) x GROUP BY n;