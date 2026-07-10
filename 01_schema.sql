USE healthcare_operations;


CREATE TABLE dbo.dim_year (
    year_key        INT IDENTITY(1,1) PRIMARY KEY,
    financial_year  NVARCHAR(100) NOT NULL,
    year            SMALLINT NOT NULL,
    CONSTRAINT UQ_dim_year_financial_year UNIQUE (financial_year)
);

CREATE TABLE dbo.dim_hospital (
    hospital_key        INT IDENTITY(1,1) PRIMARY KEY,
    reporting_unit       NVARCHAR(200) NOT NULL,
    reporting_unit_type  NVARCHAR(200) NOT NULL,
    state                NVARCHAR(100) NULL,
    peer_group           NVARCHAR(100) NULL,
    CONSTRAINT UQ_dim_hospital_reporting_unit UNIQUE (reporting_unit)
);

select * from sys.tables where name = 'dim_hospital';