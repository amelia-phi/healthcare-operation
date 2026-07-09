"""
Extract AIHW MyHospitals xlsx source files into clean, per-table CSVs
ready for SQLite loading and Power BI import.

Source: data/raw/*.xlsx
Output: data/processed/<dataset>.csv

Handles, per the data dictionary / BRD:
  - AIHW's variable-length metadata preamble before the real header row
  - trailing blank "footnote" columns
  - en-dash financial year labels ("2011-12") -> integer start year
  - duration strings ("2 hrs 58 mins") kept as-is, not converted
  - suppression/sentinel codes (<5, NP, NP-dagger, -, Not peered) -> NULL
    plus a companion *_flag column recording *why*, per BRD requirement
    that data gaps be surfaced explicitly rather than hidden.
"""
from pathlib import Path

import pandas as pd

RAW_DIR = Path(__file__).resolve().parent.parent / "data" / "raw"
OUT_DIR = Path(__file__).resolve().parent.parent / "data" / "processed"

SUPPRESSION_CODES = {
    "<5": "suppressed_small_count",
    "NP": "not_published",
    "NP†": "not_published",   # NP with dagger footnote marker
    "-": "not_applicable",
    "Not peered": "not_peered",
}

def find_header_row(path: Path, sheet: str) -> int:
    """AIHW prepends a variable-length notes block before the real header.
    Detect it by locating the row whose first cell is 'Reporting unit'."""
    import openpyxl

    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb[sheet]
    for i, row in enumerate(ws.iter_rows(min_row=1, max_row=60, values_only=True)):
        if row and row[0] == "Reporting unit":
            wb.close()
            return i
    wb.close()
    raise ValueError(f"Could not find header row in {path.name} / {sheet}")


def split_numeric_and_flag(series: pd.Series) -> tuple[pd.Series, pd.Series]:
    """Coerce a metric column to numeric, extracting suppression codes into
    a companion flag column ('reported' when the value is a normal number)."""
    flag = series.map(lambda v: SUPPRESSION_CODES.get(str(v).strip(), "reported") if pd.notna(v) else "reported")
    numeric = pd.to_numeric(series, errors="coerce")
    return numeric, flag


def parse_year(value) -> int:
    label = str(value).replace("–", "-").strip()  # normalise en-dash
    return int(label.split("-")[0])


def clean_text(series: pd.Series) -> pd.Series:
    return series.astype("string").str.strip().replace("", pd.NA)


def load_sheet(path: Path, sheet: str) -> pd.DataFrame:
    header_row = find_header_row(path, sheet)
    df = pd.read_excel(path, sheet_name=sheet, header=header_row, engine="openpyxl")
    df = df.loc[:, ~df.columns.astype(str).str.startswith("Unnamed")]
    return df


def build_ed_seen_on_time() -> pd.DataFrame:
    df = load_sheet(RAW_DIR / "myhosp-emergency-department-data-extract.xlsx", "Patients seen on time")
    out = pd.DataFrame()
    out["reporting_unit"] = clean_text(df["Reporting unit"])
    out["reporting_unit_type"] = clean_text(df["Reporting unit type"])
    out["state"] = clean_text(df["State"])
    out["peer_group"] = clean_text(df["Peer group"])
    out["financial_year"] = df["Year"].astype(str).str.replace("–", "-")
    out["year"] = df["Year"].map(parse_year)
    out["triage_category"] = clean_text(df["Triage category"])
    out["number_of_presentations"], out["number_of_presentations_flag"] = split_numeric_and_flag(df["Number of presentations"])
    out["pct_seen_on_time"], out["pct_seen_on_time_flag"] = split_numeric_and_flag(df["Percentage of patients seen on time"])
    out["peer_group_avg_pct"], out["peer_group_avg_pct_flag"] = split_numeric_and_flag(df["Peer group average"])
    return out


def build_ed_within_4hrs() -> pd.DataFrame:
    df = load_sheet(RAW_DIR / "myhosp-emergency-department-data-extract.xlsx", "Time in ED - within 4 hrs")
    out = pd.DataFrame()
    out["reporting_unit"] = clean_text(df["Reporting unit"])
    out["reporting_unit_type"] = clean_text(df["Reporting unit type"])
    out["state"] = clean_text(df["State"])
    out["peer_group"] = clean_text(df["Peer group"])
    out["financial_year"] = df["Year"].astype(str).str.replace("–", "-")
    out["year"] = df["Year"].map(parse_year)
    out["patient_cohort"] = clean_text(df["Patient cohort"])
    out["number_of_presentations"], out["number_of_presentations_flag"] = split_numeric_and_flag(df["Number of presentations"])
    out["pct_within_4hrs"], out["pct_within_4hrs_flag"] = split_numeric_and_flag(df["Percentage who depart ED within 4 hrs"])
    out["peer_group_avg_pct"], out["peer_group_avg_pct_flag"] = split_numeric_and_flag(df["Peer group average"])
    return out


def build_ed_time_in_ed() -> pd.DataFrame:
    df = load_sheet(RAW_DIR / "myhosp-emergency-department-data-extract.xlsx", "Time in ED")
    out = pd.DataFrame()
    out["reporting_unit"] = clean_text(df["Reporting unit"])
    out["reporting_unit_type"] = clean_text(df["Reporting unit type"])
    out["state"] = clean_text(df["State"])
    out["peer_group"] = clean_text(df["Peer group"])
    out["financial_year"] = df["Year"].astype(str).str.replace("–", "-")
    out["year"] = df["Year"].map(parse_year)
    out["patient_cohort"] = clean_text(df["Patient cohort"])
    out["number_of_presentations"], out["number_of_presentations_flag"] = split_numeric_and_flag(df["Number of presentations"])
    out["median_time"] = clean_text(df["Median time"])
    out["p90_time"] = clean_text(df["Time until most patients (90%) depart ED"])
    out["peer_group_avg_p90_time"] = clean_text(df["Peer group average (90%)"])
    return out


def build_ed_presentations() -> pd.DataFrame:
    df = load_sheet(RAW_DIR / "myhosp-emergency-department-data-extract.xlsx", "Presentations")
    out = pd.DataFrame()
    out["reporting_unit"] = clean_text(df["Reporting unit"])
    out["reporting_unit_type"] = clean_text(df["Reporting unit type"])
    out["state"] = clean_text(df["State"])
    out["financial_year"] = df["Year"].astype(str).str.replace("–", "-")
    out["year"] = df["Year"].map(parse_year)
    out["triage_category"] = clean_text(df["Triage category"])
    out["number_of_presentations"], out["number_of_presentations_flag"] = split_numeric_and_flag(df["Number of presentations"])
    return out


def build_alos() -> pd.DataFrame:
    df = load_sheet(RAW_DIR / "myhosp-average-length-of-stay-data-extract.xlsx", "Average length of stay")
    out = pd.DataFrame()
    out["reporting_unit"] = clean_text(df["Reporting unit"])
    out["reporting_unit_type"] = clean_text(df["Reporting unit type"])
    out["state"] = clean_text(df["State"])
    out["peer_group"] = clean_text(df["Peer group"])
    out["financial_year"] = df["Time period"].astype(str).str.replace("–", "-")
    out["year"] = df["Time period"].map(parse_year)
    out["category"] = clean_text(df["Category"])
    out["total_stays"], out["total_stays_flag"] = split_numeric_and_flag(df["Total number of stays"])
    out["overnight_stays"], out["overnight_stays_flag"] = split_numeric_and_flag(df["Number of overnight stays"])
    out["pct_overnight_stays"], out["pct_overnight_stays_flag"] = split_numeric_and_flag(df["Percentage of overnight stays"])
    out["avg_los_days"], out["avg_los_days_flag"] = split_numeric_and_flag(df["Average length of stay (days)"])
    out["peer_group_avg_los_days"], out["peer_group_avg_los_days_flag"] = split_numeric_and_flag(df["Peer group average (days)"])
    out["overnight_bed_days"], out["overnight_bed_days_flag"] = split_numeric_and_flag(df["Total overnight patient bed days"])
    return out


def build_admissions() -> pd.DataFrame:
    df = load_sheet(RAW_DIR / "myhosp-patient-admission-data-extract.xlsx", "Patient admissions")
    out = pd.DataFrame()
    out["reporting_unit"] = clean_text(df["Reporting unit"])
    out["reporting_unit_type"] = clean_text(df["Reporting unit type"])
    out["state"] = clean_text(df["State"])
    out["financial_year"] = df["Time period"].astype(str).str.replace("–", "-")
    out["year"] = df["Time period"].map(parse_year)
    out["category"] = clean_text(df["Category"])
    out["number_of_admissions"], out["number_of_admissions_flag"] = split_numeric_and_flag(df["Number of patient admissions"])
    return out


def build_specialised_services() -> pd.DataFrame:
    df = load_sheet(RAW_DIR / "myhosp-specialised-services-data-extract.xlsx", "Specialised services")
    out = pd.DataFrame()
    out["reporting_unit"] = clean_text(df["Reporting unit"])
    out["reporting_unit_type"] = clean_text(df["Reporting unit type"])
    out["state"] = clean_text(df["State"])
    out["financial_year"] = df["Time period"].astype(str).str.replace("–", "-")
    out["year"] = df["Time period"].map(parse_year)
    out["specialised_service"] = clean_text(df["Specialised services"])
    out["number_of_units"] = pd.to_numeric(df["Number of units"], errors="coerce")
    return out


BUILDERS = {
    "ed_seen_on_time": build_ed_seen_on_time,
    "ed_within_4hrs": build_ed_within_4hrs,
    "ed_time_in_ed": build_ed_time_in_ed,
    "ed_presentations": build_ed_presentations,
    "alos": build_alos,
    "admissions": build_admissions,
    "specialised_services": build_specialised_services,
}


def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for name, builder in BUILDERS.items():
        df = builder()
        out_path = OUT_DIR / f"{name}.csv"
        df.to_csv(out_path, index=False)
        print(f"{name}: {len(df):,} rows -> {out_path}")


if __name__ == "__main__":
    main()
