# Star Schema Design — Rationale

**Project:** Healthcare Operations Dashboard
**Stage:** 6 — Data Modeling
**Script:** `01_schema.sql`
**Database:** `healthcare_operations` (SQL Server)

---

## 1. Overview

The schema is a standard star schema: 3 dimension tables and 5 fact tables. Every design decision below was driven by findings from `00_source_discovery.sql` and the 10 stakeholder requests in `healthcare_business_case_scenarios.md` — nothing here is guessed; each choice traces back to either a confirmed data pattern or a specific business question the model needs to answer.

```
dim_year ──┐
dim_hospital ──┼── fact_admissions
dim_category ──┤   fact_alos
                │   fact_ed_volume
                │   fact_ed_time
                └── fact_specialised_services
```

---

## 2. Dimension Tables

### `dim_year`

| Column | Type | Notes |
|---|---|---|
| year_key | INT IDENTITY | surrogate key |
| financial_year | NVARCHAR(100) NOT NULL, UNIQUE | natural key, e.g. "2022-23" |
| year | SMALLINT NOT NULL | |

**Design logic:** Straightforward conformed dimension shared by every fact table. `financial_year` is kept as `NOT NULL` and `UNIQUE` because discovery confirmed it's never null in any source table, and one row per period is the entire point of the dimension.

---

### `dim_hospital`

| Column | Type | Notes |
|---|---|---|
| hospital_key | INT IDENTITY | surrogate key |
| reporting_unit | NVARCHAR(200) NOT NULL, UNIQUE | natural key |
| reporting_unit_type | NVARCHAR(200) NOT NULL | 'Hospital' / 'Local Hospital Network' |
| state | NVARCHAR(100) NULL | |
| peer_group_alos | NVARCHAR(100) NULL | coarse size classification |
| peer_group_ed | NVARCHAR(100) NULL | finer classification (size + locality) |
| locality | NVARCHAR(50) NULL | derived: 'Regional' / 'Metropolitan' / NULL |

**Design logic — this table went through three revisions, each driven by a validation finding:**

1. **Started as one `peer_group` column.** Rejected after Section 7 discovery testing showed 111 of 762 hospitals (~15%) have two *different* peer group values depending on which source table they came from.

2. **Investigated whether that was conflicting data or two real classification systems.** A side-by-side comparison (`peer_group_alos` vs `peer_group_ed` for the same hospital) showed a clean, 100%-consistent pattern: `peer_group_ed` = `peer_group_alos` + a "regional"/"metropolitan" qualifier (e.g. "Medium hospitals" → "Medium regional hospitals"). This is not a data quality defect — AIHW simply classifies hospitals differently for admitted-patient care (ALOS) versus emergency department care. **Resolved: keep both columns**, since collapsing them into one would discard real information Power BI users may want to slice by either way.

3. **Added `locality` as a derived column** once it was confirmed no source table has a dedicated Regional/Metropolitan flag — `reporting_unit_type` was checked and only contains 'Hospital'/'Local Hospital Network', unrelated to locality. The Regional/Metropolitan distinction only exists buried inside the `peer_group_ed` text string. `locality` will be parsed out of `peer_group_ed` in Transform/Load so it exists as its own clean, filterable Power BI slicer rather than requiring `LIKE '%regional%'` logic in every report.

**Cross-table naming check:** Section 7 discovery confirmed `reporting_unit` spelling is 100% consistent across all 7 source tables (zero mismatches between `ed_presentations` and `ed_within_4hrs` in either direction), so `dim_hospital` is built from a simple `UNION` of distinct `reporting_unit` values with no standardization/fuzzy-matching step required.

---

### `dim_category`

| Column | Type | Notes |
|---|---|---|
| category_key | INT IDENTITY | surrogate key |
| category_type | NVARCHAR(50) NOT NULL | discriminator |
| category_name | NVARCHAR(200) NOT NULL | |
| — | UNIQUE (category_type, category_name) | composite natural key |

**Design logic:** The source data has four genuinely different classification schemes — `category` (admissions), `triage_category` (ED presentations/timeliness), `patient_cohort` (ED time-in-ED/within-4hrs), and `specialised_service`. Two designs were weighed:

- **Option A (chosen): one shared table with a `category_type` discriminator.**
- **Option B (rejected): four separate dimension tables**, which is the more "textbook correct" dimensional modeling choice, since these aren't the same real-world entity (unlike a genuinely conformed dimension such as Date).

Option A was chosen deliberately for simplicity — fewer tables to manage and a single consistent join pattern across all fact tables — with the explicit tradeoff acknowledged: every fact table's `category_key` must be filtered/joined with awareness of `category_type`, since nothing in the schema itself prevents a fact table from accidentally pointing at a category row from the wrong scheme. This is enforced by convention/discipline in `03_load_model.sql`, not by a database constraint.

The `UNIQUE` constraint is composite (`category_type, category_name`), not just on `category_name` alone — this deliberately allows the same text value to exist validly under two different schemes without collision (e.g. if two schemes both happened to use the word "General").

---

## 3. Fact Tables

All five fact tables follow the same core pattern:
- A surrogate PK
- Three FKs (`hospital_key`, `year_key`, `category_key`)
- A `UNIQUE` constraint across the three FKs, which is the literal enforcement of the fact table's **grain** ("one row = one hospital, one year, one category/triage/cohort/service")
- Raw source measures kept at their original SQL Server type
- Where a source `_flag` column exists: the raw flag text is preserved as `..._flag_raw` for audit purposes, and a single derived `is_suppressed BIT` is added next to the table's headline metric for easy filtering in Power BI (`WHERE is_suppressed = 0`) without needing to string-match flag text

### `fact_admissions`
Grain: hospital + year + admission category. One measure (`number_of_admissions`), one flag.

### `fact_alos`
Grain: hospital + year + admission category. Six measures, each with its own raw flag column, but only one derived `is_suppressed` (tied to `avg_los_days`, the headline metric) — deriving a boolean for all six was judged to be over-engineering relative to what's actually needed in Power BI.

### `fact_ed_volume`
Grain: hospital + year + **triage category**. Combines `ed_presentations` + `ed_seen_on_time`.

**This table was redesigned after a validation finding.** The original design used a single shared `number_of_presentations` column, on the assumption that both source tables report the same figure at the same grain. A row-level join test (`ed_presentations` vs `ed_seen_on_time` on `reporting_unit + financial_year + triage_category`) showed **~85% of rows disagree**, consistently in one direction (`ed_presentations` count higher). This points to the two source tables using different inclusion rules — `ed_presentations` likely counts all presentations, while `ed_seen_on_time` likely reports the specific cohort used as the denominator for the timeliness percentage. **Resolved:** split into two explicit columns, `total_presentations` (from `ed_presentations`) and `seen_on_time_presentations` (from `ed_seen_on_time`), rather than risk one silently overwriting the other during load.

*(Note: an initial attempt to compare all four ED source tables at once, by summing `number_of_presentations` per hospital/year across every `patient_cohort` value, produced misleading exact 2x/3x multiples — this was an aggregation bug caused by `patient_cohort` containing overlapping values like "All patients" alongside its own sub-partitions, not a real data issue. Confirmed and corrected before drawing conclusions.)*

### `fact_ed_time`
Grain: hospital + year + **patient cohort**. Combines `ed_time_in_ed` + `ed_within_4hrs`.

Split from `fact_ed_volume` deliberately — `triage_category` and `patient_cohort` are different classification systems, and squashing all four ED tables into one fact table would produce a permanently half-empty table (whichever grain wasn't active for a given row would sit NULL). Splitting by grain, not by "topic," keeps both fact tables fully populated and directly supports Business Case Requests 1–3.

`median_time` and `p90_time` are modeled here as `FLOAT`, even though the *source* `ed_time_in_ed` table has them as `nvarchar` — this table represents the post-Transform target state; `02_transform.sql` is responsible for successfully casting these before load.

### `fact_specialised_services`
Grain: hospital + year + specialised service. Simplest fact table — the source table carries no `_flag` column at all, so there's no suppression pattern to model.

---
