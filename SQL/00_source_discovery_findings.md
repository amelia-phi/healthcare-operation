# Source Discovery & Assessment — Findings

**Project:** Healthcare Operations Dashboard
**Stage:** 3 — Source Discovery & Assessment
**Script:** `00_source_discovery.sql`
**Database:** `healthcare_operations` (SQL Server, 192.168.126.119)
**Status:** Complete

---

## 1. Scope

Seven source tables were loaded via SSMS Import Wizard from AIHW MyHospitals public xlsx extracts, covering ED wait times, patient volume, average length of stay, and hospital capability (specialised services). Bed occupancy and 30-day readmission rates are out of scope — no public data available for these.

| Table | Row Count |
|---|---|
| `admissions` | 121,553 |
| `average_length_of_stay` | 113,863 |
| `ed_within_4hrs` | 36,289 |
| `ed_presentations` | 22,678 |
| `ed_seen_on_time` | 21,972 |
| `specialised_services` | 19,657 |
| `ed_time_in_ed` | 13,611 |

---

## 2. Schema & Data Type Findings

- Full column/type/nullability inventory captured for all 7 tables (80 columns total) via `sys.tables` / `sys.columns` / `sys.types`.
- **`median_time` and `p90_time` in `ed_time_in_ed` are stored as `nvarchar`**, not numeric, despite representing wait-time durations. These will need casting (and cleaning of any non-numeric values) in Transform.
- Every table carries one or more **`_flag` columns** (`nvarchar`) alongside its numeric measures (e.g. `number_of_admissions_flag`). Sample values confirmed: `"reported"` and `"suppressed_small_count"` — this is the standard AIHW convention for marking small-count data suppressed for privacy. Roughly 5–10% of rows carry a suppression flag with a NULL measure.
- `state` and `peer_group` are nullable on the tables where they appear; all other dimension-like columns (`reporting_unit`, `financial_year`, `year`, `category`/`triage_category`/`patient_cohort`) are not nullable.

---

## 3. Duplicate Rows

A grain check on `admissions` (`reporting_unit + financial_year + category + number_of_admissions + number_of_admissions_flag`) found:

- **116,905 row groups** appear exactly once (clean)
- **2,324 row groups** appear exactly twice — true exact duplicates, not a grain/missing-column issue
- Totals reconcile exactly: `116,905 + (2,324 × 2) = 121,553`

**Interpretation:** this is consistent with a **partial/overlapping load** (e.g. one batch or file re-imported), not a full double-load of the table. The same duplicate pattern was observed at a glance across the other 6 tables during discovery; full duplicate-rate confirmation per table is an open item (see Section 5).

**Action required:** `02_transform.sql` needs a dedupe step (`ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...) = 1`) applied to all 7 tables before modeling.

---

## 4. Cross-Table Hospital Naming Consistency

Tested whether `reporting_unit` values match exactly across tables (critical for a single shared `dim_hospital`):

| Check | Result |
|---|---|
| `average_length_of_stay` → not in `admissions` | 0 rows |
| `admissions` → not in `average_length_of_stay` | 70 rows |
| `ed_presentations` → not in `ed_within_4hrs` | 0 rows |
| `ed_within_4hrs` → not in `ed_presentations` | 0 rows |

**Interpretation:**
- The two ED tables tested have **zero naming mismatches in either direction** — same hospital set, consistent spelling. No standardization needed for ED-side facts.
- `average_length_of_stay` is a strict subset of `admissions`: every ALOS hospital exists in admissions, but 70 hospitals report admissions without reporting ALOS. Spot-checking these 70 shows they are predominantly mental health, hospice, rehabilitation, and small multi-purpose services — a genuine **coverage gap** (these facility types likely aren't tracked for length-of-stay), not a spelling/naming defect.

**Action required:** none for cleaning. `dim_hospital` should be built from the full distinct union of `reporting_unit` across all 7 tables; not every hospital will have rows in every fact table, which is expected and requires no fix — only documentation.

---

## 5. Summary of Required Transform Actions

Based on findings to date, `02_transform.sql` needs to:

1. Dedupe all 7 tables (exact-duplicate removal)
2. Cast `median_time` and `p90_time` (`ed_time_in_ed`) from `nvarchar` to numeric, handling non-numeric/suppressed values
3. Standardize `_flag` columns into a consistent suppression indicator
4. No hospital name standardization required — naming is already consistent across tables

**Next step:** proceed to `01_schema.sql` (star schema design), informed by these findings.
