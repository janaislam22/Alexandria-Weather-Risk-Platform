/* ============================================================
   Alex_weather - warehouse setup (run ONCE on a fresh server)
   Creates: database, bronze/silver/gold schemas, all tables,
            date-dimension procedure + population, location dimension.
   Fact tables are loaded by notebooks/03_gold.ipynb.
   ============================================================ */

CREATE DATABASE Alex_weather;
GO
USE Alex_weather;
GO

CREATE SCHEMA bronze;
GO
CREATE SCHEMA silver;
GO
CREATE SCHEMA gold;
GO

/* ---------- Bronze: raw data, everything stored as text ---------- */
CREATE TABLE bronze.weather (
    time            varchar(20),
    temperature_2m  varchar(20),
    precipitation   varchar(20),
    wind_gusts_10m  varchar(20),
    pressure_msl    varchar(20),
    location        varchar(20)
);
GO

/* ---------- Silver: typed and de-duplicated ---------- */
CREATE TABLE silver.weather (
    time            datetime,
    temperature_2m  float,
    precipitation   float,
    wind_gusts_10m  float,
    pressure_msl    float,
    location        varchar(20)
);
GO

/* ---------- Gold: star schema ---------- */
CREATE TABLE gold.Dim_Date (
    Date_SK       int PRIMARY KEY,      -- yyyymmdd
    Full_Date     date NOT NULL,
    Year          int,
    Quarter       int,
    Month_Number  int,
    Month_Name    nvarchar(50),
    Day_of_Week   int,
    Day_Name      nvarchar(50),
    Day_of_Month  int,
    Week_of_Year  int,
    Is_Weekend    bit                   -- NOTE: Sunday/Saturday (US default). Egypt's weekend is Friday/Saturday.
);
GO

CREATE PROCEDURE sp_PopulateDateDimension
    @StartDate DATE,
    @EndDate   DATE
AS
BEGIN
    DECLARE @CurrentDate DATE = @StartDate;

    WHILE @CurrentDate <= @EndDate
    BEGIN
        INSERT INTO gold.Dim_Date (
            Date_SK, Full_Date, Year, Quarter, Month_Number, Month_Name,
            Day_of_Week, Day_Name, Day_of_Month, Week_of_Year, Is_Weekend
        )
        VALUES (
            CONVERT(INT, FORMAT(@CurrentDate, 'yyyyMMdd')),
            @CurrentDate,
            YEAR(@CurrentDate),
            DATEPART(QUARTER, @CurrentDate),
            MONTH(@CurrentDate),
            DATENAME(MONTH, @CurrentDate),
            DATEPART(WEEKDAY, @CurrentDate),
            DATENAME(WEEKDAY, @CurrentDate),
            DAY(@CurrentDate),
            DATEPART(WEEK, @CurrentDate),
            CASE WHEN DATEPART(WEEKDAY, @CurrentDate) IN (1, 7) THEN 1 ELSE 0 END
        );

        SET @CurrentDate = DATEADD(DAY, 1, @CurrentDate);
    END
END;
GO

EXEC sp_PopulateDateDimension '2025-01-01', '2030-12-31';   -- 2191 rows
GO

CREATE TABLE gold.dim_location1 (
    Location_SK    int PRIMARY KEY,
    Location_Name  varchar(20),
    Latitude       decimal(9,6),   -- explicit precision: plain DECIMAL rounds to whole degrees
    Longitude      decimal(9,6)
);
GO

-- Approximate coordinates taken from Google Maps
INSERT INTO gold.dim_location1 VALUES
    (1, 'Stanley',      31.24, 29.95),
    (2, 'Borg_El_Arab', 30.85, 29.60),
    (3, 'Abu_Qir',      31.32, 30.07);
GO

CREATE TABLE gold.Fact_Weather_Hourly (
    Date_SK         int NOT NULL,
    Hour_of_Day     int NOT NULL,
    Location_SK     int NOT NULL,
    Temperature_2m  float,
    Precipitation   float,
    Wind_Gusts_10m  float,
    Pressure_msl    float,
    PRIMARY KEY (Location_SK, Date_SK, Hour_of_Day)
);
GO

-- gold.Fact_Risk is (re)built by notebooks/03_gold.ipynb using SELECT ... INTO
