USE healthcare_operations;
--------------------------
DROP TABLE IF EXISTS dbo.fact_ed_volume;
DROP TABLE IF EXISTS dbo.fact_ed_time;
DROP TABLE IF EXISTS dbo.fact_specialised_services;
DROP TABLE IF EXISTS dbo.fact_admissions;
DROP TABLE IF EXISTS dbo.fact_alos;          
DROP TABLE IF EXISTS dbo.dim_year;
DROP TABLE IF EXISTS dbo.dim_hospital;
DROP TABLE IF EXISTS dbo.dim_category;

--------------------------
CREATE TABLE dbo.dim_year (
    year_key        INT IDENTITY(1,1) PRIMARY KEY,
    financial_year  NVARCHAR(100) NOT NULL,
    year            SMALLINT NOT NULL,
    CONSTRAINT UQ_dim_year_financial_year UNIQUE (financial_year)
);

CREATE TABLE dbo.dim_hospital (
    hospital_key         INT IDENTITY(1,1) PRIMARY KEY,
    reporting_unit        NVARCHAR(200) NOT NULL,
    reporting_unit_type   NVARCHAR(200) NOT NULL,
    state                 NVARCHAR(100) NULL,
    peer_group_alos       NVARCHAR(100) NULL,
    peer_group_ed         NVARCHAR(100) NULL,
    locality              NVARCHAR(50) NULL,   -- derived: 'Regional' / 'Metropolitan' / NULL
    CONSTRAINT UQ_dim_hospital_reporting_unit UNIQUE (reporting_unit)
);

CREATE TABLE dbo.dim_category (
    category_key   INT IDENTITY(1,1) PRIMARY KEY,
    category_type  NVARCHAR(50) NOT NULL,
    category_name  NVARCHAR(200) NOT NULL,
    CONSTRAINT UQ_dim_category_type_name UNIQUE (category_type, category_name)
);

CREATE TABLE dbo.fact_admissions (
    admission_fact_key  INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key         INT NOT NULL,
    year_key              INT NOT NULL,
    category_key          INT NOT NULL,
    number_of_admissions  FLOAT NULL,
    is_suppressed          BIT NOT NULL DEFAULT 0,
    CONSTRAINT FK_fact_admissions_hospital FOREIGN KEY (hospital_key) REFERENCES dbo.dim_hospital(hospital_key),
    CONSTRAINT FK_fact_admissions_year FOREIGN KEY (year_key) REFERENCES dbo.dim_year(year_key),
    CONSTRAINT FK_fact_admissions_category FOREIGN KEY (category_key) REFERENCES dbo.dim_category(category_key),
    CONSTRAINT UQ_fact_admissions_grain UNIQUE (hospital_key, year_key, category_key)
);

CREATE TABLE dbo.fact_alos (
    alos_fact_key                    INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key                      INT NOT NULL,
    year_key                           INT NOT NULL,
    category_key                       INT NOT NULL,
    total_stays                        FLOAT NULL,
    total_stays_flag_raw                NVARCHAR(100) NULL,
    overnight_stays                    FLOAT NULL,
    overnight_stays_flag_raw            NVARCHAR(100) NULL,
    pct_overnight_stays                FLOAT NULL,
    pct_overnight_stays_flag_raw        NVARCHAR(100) NULL,
    avg_los_days                       FLOAT NULL,
    avg_los_days_flag_raw               NVARCHAR(100) NULL,
    is_suppressed                       BIT NOT NULL DEFAULT 0,
    peer_group_avg_los_days            FLOAT NULL,
    peer_group_avg_los_days_flag_raw    NVARCHAR(100) NULL,
    overnight_bed_days                 FLOAT NULL,
    overnight_bed_days_flag_raw         NVARCHAR(100) NULL,
    CONSTRAINT FK_fact_alos_hospital FOREIGN KEY (hospital_key) REFERENCES dbo.dim_hospital(hospital_key),
    CONSTRAINT FK_fact_alos_year FOREIGN KEY (year_key) REFERENCES dbo.dim_year(year_key),
    CONSTRAINT FK_fact_alos_category FOREIGN KEY (category_key) REFERENCES dbo.dim_category(category_key),
    CONSTRAINT UQ_fact_alos_grain UNIQUE (hospital_key, year_key, category_key)
);

CREATE TABLE dbo.fact_ed_volume (
    ed_volume_fact_key                  INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key                         INT NOT NULL,
    year_key                              INT NOT NULL,
    category_key                          INT NOT NULL,
    total_presentations                  FLOAT NULL,   -- from ed_presentations
    total_presentations_flag_raw          NVARCHAR(100) NULL,
    seen_on_time_presentations           FLOAT NULL,   -- from ed_seen_on_time (timeliness denominator)
    seen_on_time_presentations_flag_raw   NVARCHAR(100) NULL,
    pct_seen_on_time                     FLOAT NULL,
    pct_seen_on_time_flag_raw             NVARCHAR(100) NULL,
    is_suppressed                         BIT NOT NULL DEFAULT 0,
    peer_group_avg_pct                   FLOAT NULL,
    peer_group_avg_pct_flag_raw           NVARCHAR(100) NULL,
    CONSTRAINT FK_fact_ed_volume_hospital FOREIGN KEY (hospital_key) REFERENCES dbo.dim_hospital(hospital_key),
    CONSTRAINT FK_fact_ed_volume_year FOREIGN KEY (year_key) REFERENCES dbo.dim_year(year_key),
    CONSTRAINT FK_fact_ed_volume_category FOREIGN KEY (category_key) REFERENCES dbo.dim_category(category_key),
    CONSTRAINT UQ_fact_ed_volume_grain UNIQUE (hospital_key, year_key, category_key)
);


CREATE TABLE dbo.fact_ed_time (
    ed_time_fact_key                  INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key                       INT NOT NULL,
    year_key                            INT NOT NULL,
    category_key                        INT NOT NULL,
    number_of_presentations            FLOAT NULL,
    number_of_presentations_flag_raw    NVARCHAR(100) NULL,
    median_time                        FLOAT NULL,
    p90_time                           FLOAT NULL,
    peer_group_avg_p90_time            FLOAT NULL,
    pct_within_4hrs                    FLOAT NULL,
    pct_within_4hrs_flag_raw            NVARCHAR(100) NULL,
    is_suppressed                       BIT NOT NULL DEFAULT 0,
    peer_group_avg_pct                 FLOAT NULL,
    peer_group_avg_pct_flag_raw         NVARCHAR(100) NULL,
    CONSTRAINT FK_fact_ed_time_hospital FOREIGN KEY (hospital_key) REFERENCES dbo.dim_hospital(hospital_key),
    CONSTRAINT FK_fact_ed_time_year FOREIGN KEY (year_key) REFERENCES dbo.dim_year(year_key),
    CONSTRAINT FK_fact_ed_time_category FOREIGN KEY (category_key) REFERENCES dbo.dim_category(category_key),
    CONSTRAINT UQ_fact_ed_time_grain UNIQUE (hospital_key, year_key, category_key)
);

CREATE TABLE dbo.fact_specialised_services (
    specialised_service_fact_key  INT IDENTITY(1,1) PRIMARY KEY,
    hospital_key                   INT NOT NULL,
    year_key                        INT NOT NULL,
    category_key                    INT NOT NULL,
    number_of_units                 TINYINT NULL,
    CONSTRAINT FK_fact_specialised_services_hospital FOREIGN KEY (hospital_key) REFERENCES dbo.dim_hospital(hospital_key),
    CONSTRAINT FK_fact_specialised_services_year FOREIGN KEY (year_key) REFERENCES dbo.dim_year(year_key),
    CONSTRAINT FK_fact_specialised_services_category FOREIGN KEY (category_key) REFERENCES dbo.dim_category(category_key),
    CONSTRAINT UQ_fact_specialised_services_grain UNIQUE (hospital_key, year_key, category_key)
);