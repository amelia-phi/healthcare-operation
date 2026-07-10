# Healthcare Operation

A data project analysing Australian hospital operational performance using
public AIHW MyHospitals data — covering emergency department wait times,
patient admissions, average length of stay, and specialised services.

Raw data extracts are cleaned into tidy CSVs, then loaded into SQLite for
analysis and visualised in a Power BI dashboard.

## Data source

[AIHW MyHospitals](https://www.aihw.gov.au/reports-data/myhospitals) — a
public reporting tool from the Australian Institute of Health and Welfare
with hospital-level operational data. Raw extracts (`data/raw/`):

- `myhosp-emergency-department-data-extract.xlsx`
- `myhosp-average-length-of-stay-data-extract.xlsx`
- `myhosp-patient-admission-data-extract.xlsx`
- `myhosp-specialised-services-data-extract.xlsx`
