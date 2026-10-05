##Checking Database
SELECT current_database();

##Checking Source Table
SELECT *
FROM crime_records
LIMIT 10;

##Checking Total Records
SELECT COUNT(*) AS total_records
FROM crime_records;

##Checking Years
SELECT
    MIN(year) AS start_year,
    MAX(year) AS end_year,
    COUNT(DISTINCT year) AS total_years
FROM crime_records;

##Checking States and Districts
SELECT
    COUNT(DISTINCT state_name) AS total_states,
    COUNT(DISTINCT district_name) AS total_districts
FROM crime_records;

##Checking Null Values
SELECT
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE year IS NULL) AS null_year,
    COUNT(*) FILTER (WHERE state_name IS NULL) AS null_state,
    COUNT(*) FILTER (WHERE district_name IS NULL) AS null_district,
    COUNT(*) FILTER (WHERE murder_homicide IS NULL) AS null_murder,
    COUNT(*) FILTER (WHERE cybercrime IS NULL) AS null_cybercrime
FROM crime_records;

##Checking Duplicate Records
SELECT
    year,
    state_name,
    district_name,
    district_code,
    registration_circles,
    COUNT(*) AS record_count
FROM crime_records
GROUP BY
    year,
    state_name,
    district_name,
    district_code,
    registration_circles
HAVING COUNT(*) > 1
ORDER BY record_count DESC;

##Creating The Main Analytical View
DROP VIEW IF EXISTS vw_crime_long;

CREATE VIEW vw_crime_long AS
SELECT
    year,
    state_name,
    state_code,
    district_name,
    district_code,
    registration_circles,
    crime_category,
    crime_count
FROM crime_records
CROSS JOIN LATERAL (
    VALUES
        ('murder_homicide', murder_homicide),
        ('rape_sexual_violence', rape_sexual_violence),
        ('attempted_rape', attempted_rape),
        ('assault_modesty', assault_modesty),
        ('kidnapping_abduction', kidnapping_abduction),
        ('kidnapping_ransom', kidnapping_ransom),
        ('human_trafficking', human_trafficking),
        ('crimes_against_children', crimes_against_children),
        ('pocso_crimes', pocso_crimes),
        ('cruelty_domestic_violence', cruelty_domestic_violence),
        ('dowry_crimes', dowry_crimes),
        ('acid_attack', acid_attack),
        ('suicide_abetment', suicide_abetment),
        ('hurt_grievous_hurt', hurt_grievous_hurt),
        ('juvenile_crimes', juvenile_crimes),
        ('cybercrime', cybercrime),
        ('cyber_fraud', cyber_fraud),
        ('identity_privacy_crimes', identity_privacy_crimes),
        ('cyber_harassment_threats', cyber_harassment_threats),
        ('online_sexual_obscene_crimes', online_sexual_obscene_crimes),
        ('cheating_fraud', cheating_fraud),
        ('theft_property_crimes', theft_property_crimes),
        ('forgery_counterfeiting', forgery_counterfeiting),
        ('immoral_traffic_prostitution', immoral_traffic_prostitution),
        ('other_ipc_special_laws', other_ipc_special_laws)
) AS c(crime_category, crime_count);

##Testing
SELECT *
FROM vw_crime_long
LIMIT 20;

##Overall Crime Categories
SELECT
    crime_category,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
GROUP BY crime_category
ORDER BY total_cases DESC;

##Yearly Analysis
SELECT
    year,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
GROUP BY year
ORDER BY year;

##State Analysis
SELECT
    state_name,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
GROUP BY state_name
ORDER BY total_cases DESC;

##Top 20 Districts 
SELECT
    state_name,
    district_name,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
GROUP BY
    state_name,
    district_name
ORDER BY total_cases DESC
LIMIT 20;

##State Ranking Using RANK()
WITH state_totals AS (
    SELECT
        state_name,
        SUM(crime_count) AS total_cases
    FROM vw_crime_long
    GROUP BY state_name
)
SELECT
    state_name,
    total_cases,
    RANK() OVER (
        ORDER BY total_cases DESC
    ) AS state_rank
FROM state_totals
ORDER BY state_rank;

##District Ranking Within each state
WITH district_totals AS (
    SELECT
        state_name,
        district_name,
        SUM(crime_count) AS total_cases
    FROM vw_crime_long
    GROUP BY
        state_name,
        district_name
)
SELECT
    state_name,
    district_name,
    total_cases,
    RANK() OVER (
        PARTITION BY state_name
        ORDER BY total_cases DESC
    ) AS district_rank
FROM district_totals
ORDER BY
    state_name,
    district_rank;

##Year-Over-Year Analysis
WITH yearly_totals AS (
    SELECT
        year,
        SUM(crime_count) AS total_cases
    FROM vw_crime_long
    GROUP BY year
),
comparison AS (
    SELECT
        year,
        total_cases,
        LAG(total_cases) OVER (
            ORDER BY year
        ) AS previous_year_cases
    FROM yearly_totals
)
SELECT
    year,
    total_cases,
    previous_year_cases,
    total_cases - previous_year_cases AS change_in_cases,
    ROUND(
        (
            (total_cases - previous_year_cases)
            * 100.0
            / NULLIF(previous_year_cases, 0)
        )::numeric,
        2
    ) AS yoy_growth_percentage
FROM comparison
ORDER BY year;

##Category-Wise Year-Over-Year
WITH yearly_category AS (
    SELECT
        year,
        crime_category,
        SUM(crime_count) AS total_cases
    FROM vw_crime_long
    GROUP BY
        year,
        crime_category
),
comparison AS (
    SELECT
        year,
        crime_category,
        total_cases,
        LAG(total_cases) OVER (
            PARTITION BY crime_category
            ORDER BY year
        ) AS previous_year_cases
    FROM yearly_category
)
SELECT
    year,
    crime_category,
    total_cases,
    previous_year_cases,
    total_cases - previous_year_cases AS change_in_cases,
    ROUND(
        (
            (total_cases - previous_year_cases)
            * 100.0
            / NULLIF(previous_year_cases, 0)
        )::numeric,
        2
    ) AS yoy_growth_percentage
FROM comparison
ORDER BY
    crime_category,
    year;

##Cybercrime Analysis
SELECT
    year,
    crime_category,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
WHERE crime_category IN (
    'cybercrime',
    'cyber_fraud',
    'identity_privacy_crimes',
    'cyber_harassment_threats',
    'online_sexual_obscene_crimes'
)
GROUP BY
    year,
    crime_category
ORDER BY
    year,
    total_cases DESC;

##Creating Power Bi views
CREATE VIEW vw_pbi_yearly AS
SELECT
    year,
    crime_category,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
GROUP BY
    year,
    crime_category;

##State
CREATE VIEW vw_pbi_state AS
SELECT
    state_name,
    crime_category,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
GROUP BY
    state_name,
    crime_category;

##District
CREATE VIEW vw_pbi_district AS
SELECT
    state_name,
    district_name,
    crime_category,
    SUM(crime_count) AS total_cases
FROM vw_crime_long
GROUP BY
    state_name,
    district_name,
    crime_category;

##Year-Over-Year
CREATE VIEW vw_pbi_yoy AS
WITH yearly_category AS (
    SELECT
        year,
        crime_category,
        SUM(crime_count) AS total_cases
    FROM vw_crime_long
    GROUP BY
        year,
        crime_category
)
SELECT
    year,
    crime_category,
    total_cases,
    LAG(total_cases) OVER (
        PARTITION BY crime_category
        ORDER BY year
    ) AS previous_year_cases,
    ROUND(
        (
            (
                total_cases
                - LAG(total_cases) OVER (
                    PARTITION BY crime_category
                    ORDER BY year
                )
            )
            * 100.0
            /
            NULLIF(
                LAG(total_cases) OVER (
                    PARTITION BY crime_category
                    ORDER BY year
                ),
                0
            )
        )::numeric,
        2
    ) AS yoy_growth_percentage
FROM yearly_category;

##FINAL VERIFICATION##
SELECT * FROM vw_pbi_yearly LIMIT 10;
SELECT * FROM vw_pbi_state LIMIT 10;
SELECT * FROM vw_pbi_district LIMIT 10;
SELECT * FROM vw_pbi_yoy LIMIT 10;