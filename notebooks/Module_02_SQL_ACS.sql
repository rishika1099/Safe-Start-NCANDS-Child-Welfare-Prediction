-- ============================================================
-- MODULE 2: SQL FOR ACS CHILD WELFARE DATA
-- Personal Learning Project — Simulated Child Welfare Data
-- ============================================================
-- Run these queries in: DuckDB, SQLite, PostgreSQL, or BigQuery
-- To use in R: library(DBI); library(duckdb)
-- con <- dbConnect(duckdb()); dbWriteTable(con, 'scr', scr_df)

-- ============================================================
-- SECTION 2.1: BASIC QUERIES ON SCR TABLE
-- ============================================================

-- 2.1.1 How many reports per borough?
SELECT
    borough,
    COUNT(*)                                        AS n_reports,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 1) AS pct_total
FROM scr
GROUP BY borough
ORDER BY n_reports DESC;

-- 2.1.2 Substantiation rate by allegation type
-- DOMAIN: Which allegations most often lead to confirmed findings?
SELECT
    allegation_type,
    COUNT(*)                                                    AS n_reports,
    SUM(CASE WHEN outcome = 'Substantiated' THEN 1 ELSE 0 END) AS n_substantiated,
    ROUND(AVG(CASE WHEN outcome = 'Substantiated' THEN 1.0 ELSE 0 END) * 100, 1)
                                                                AS subst_rate_pct
FROM scr
GROUP BY allegation_type
ORDER BY subst_rate_pct DESC;

-- 2.1.3 Reporter accuracy by type (ChildStat core metric)
-- DOMAIN: Anonymous reporters least accurate, medical highest
SELECT
    reporter_type,
    COUNT(*)                                                    AS n_reports,
    ROUND(AVG(CASE WHEN outcome = 'Substantiated' THEN 1.0 ELSE 0 END) * 100, 1)
                                                                AS accuracy_pct,
    ROUND(AVG(reporter_accuracy_score), 3)                      AS avg_accuracy_score
FROM scr
GROUP BY reporter_type
ORDER BY accuracy_pct DESC;

-- ============================================================
-- SECTION 2.2: WINDOW FUNCTIONS (Critical for ACS)
-- ============================================================
-- Window functions operate ACROSS rows without collapsing them
-- Essential for: prior report counts, time between reports,
-- escalation detection, ranking families by risk

-- 2.2.1 Cumulative report count per family over time
-- This is how you build longitudinal history features
SELECT
    report_id,
    family_id,
    report_date,
    allegation_type,
    outcome,
    -- How many reports has this family had UP TO THIS POINT?
    ROW_NUMBER() OVER (
        PARTITION BY family_id
        ORDER BY report_date
    )                                   AS report_number,

    -- Cumulative substantiations so far
    SUM(CASE WHEN outcome = 'Substantiated' THEN 1 ELSE 0 END) OVER (
        PARTITION BY family_id
        ORDER BY report_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
    )                                   AS prior_substantiations,

    -- Days since the PREVIOUS report for this family
    report_date - LAG(report_date) OVER (
        PARTITION BY family_id
        ORDER BY report_date
    )                                   AS days_since_last_report
FROM scr
ORDER BY family_id, report_date;

-- 2.2.2 Is the gap between reports SHRINKING? (Escalation signal)
-- DOMAIN: Accelerating reports = situation deteriorating
WITH report_gaps AS (
    SELECT
        report_id,
        family_id,
        report_date,
        report_date - LAG(report_date) OVER (
            PARTITION BY family_id ORDER BY report_date
        )                               AS days_gap
    FROM scr
),
gap_trends AS (
    SELECT
        report_id,
        family_id,
        report_date,
        days_gap,
        LAG(days_gap) OVER (
            PARTITION BY family_id ORDER BY report_date
        )                               AS prev_days_gap
    FROM report_gaps
    WHERE days_gap IS NOT NULL
)
SELECT
    report_id,
    family_id,
    report_date,
    days_gap,
    prev_days_gap,
    CASE
        WHEN days_gap < prev_days_gap THEN 'ESCALATING'
        WHEN days_gap > prev_days_gap THEN 'IMPROVING'
        ELSE 'STABLE'
    END                                 AS gap_trend
FROM gap_trends
WHERE prev_days_gap IS NOT NULL
ORDER BY family_id, report_date;

-- 2.2.3 Rank families by total reports (ChildStat high-volume families)
SELECT
    family_id,
    COUNT(*)                            AS total_reports,
    SUM(CASE WHEN outcome='Substantiated' THEN 1 ELSE 0 END)
                                        AS total_substantiated,
    COUNT(DISTINCT reporter_type)       AS distinct_reporter_types,
    COUNT(DISTINCT allegation_type)     AS distinct_allegation_types,
    MIN(report_date)                    AS first_report,
    MAX(report_date)                    AS last_report,
    DENSE_RANK() OVER (ORDER BY COUNT(*) DESC)
                                        AS risk_rank
FROM scr
GROUP BY family_id
ORDER BY total_reports DESC
LIMIT 20;

-- 2.2.4 Rolling 12-month report count (most important feature)
-- DOMAIN: ACS risk models use 12-month window as standard
-- This is exactly what prior_reports_12mo in our features table represents
WITH dated AS (
    SELECT
        report_id,
        family_id,
        report_date,
        -- Count reports in 12 months BEFORE this report (not including it)
        COUNT(*) OVER (
            PARTITION BY family_id
            ORDER BY report_date
            RANGE BETWEEN INTERVAL '365 days' PRECEDING AND INTERVAL '1 day' PRECEDING
        )                               AS prior_reports_12mo
    FROM scr
)
SELECT * FROM dated
ORDER BY family_id, report_date;

-- ============================================================
-- SECTION 2.3: CTEs (Common Table Expressions)
-- ============================================================
-- CTEs make complex queries readable and auditable
-- Each step is named and builds on the previous
-- RULE: If a query has more than 2 subqueries, use CTEs

-- 2.3.1 Full family risk profile in one readable query
WITH

-- Step 1: Base report metrics per family
family_reports AS (
    SELECT
        family_id,
        COUNT(*)                                            AS total_reports,
        SUM(CASE WHEN outcome='Substantiated' THEN 1 ELSE 0 END)
                                                            AS total_subst,
        COUNT(DISTINCT reporter_type)                       AS n_reporter_types,
        COUNT(DISTINCT allegation_type)                     AS n_allegation_types,
        MAX(CASE WHEN allegation_type='Physical Abuse' THEN 1 ELSE 0 END)
                                                            AS has_physical_abuse,
        MAX(CASE WHEN allegation_type='Sexual Abuse' THEN 1 ELSE 0 END)
                                                            AS has_sexual_abuse,
        MIN(report_date)                                    AS first_report_date,
        MAX(report_date)                                    AS last_report_date
    FROM scr
    GROUP BY family_id
),

-- Step 2: Days in system (how long has this family been known to ACS?)
family_timeline AS (
    SELECT
        family_id,
        total_reports,
        total_subst,
        n_reporter_types,
        n_allegation_types,
        has_physical_abuse,
        has_sexual_abuse,
        first_report_date,
        last_report_date,
        last_report_date - first_report_date   AS days_in_system,
        CASE
            WHEN total_reports >= 5 AND total_subst >= 2 THEN 'HIGH'
            WHEN total_reports >= 3 OR  total_subst >= 1 THEN 'MEDIUM'
            ELSE 'LOW'
        END                                    AS risk_tier
    FROM family_reports
),

-- Step 3: Most recent reporter type (last contact point)
latest_reporter AS (
    SELECT DISTINCT ON (family_id)
        family_id,
        reporter_type                          AS latest_reporter_type,
        borough                                AS latest_borough
    FROM scr
    ORDER BY family_id, report_date DESC
)

-- Final: Join everything together
SELECT
    ft.family_id,
    ft.total_reports,
    ft.total_subst,
    ROUND(ft.total_subst * 100.0 / NULLIF(ft.total_reports,0), 1)
                                               AS subst_rate_pct,
    ft.n_reporter_types,
    ft.n_allegation_types,
    ft.has_physical_abuse,
    ft.has_sexual_abuse,
    ft.days_in_system,
    ft.risk_tier,
    lr.latest_reporter_type,
    lr.latest_borough
FROM family_timeline ft
LEFT JOIN latest_reporter lr USING (family_id)
ORDER BY ft.total_reports DESC;

-- ============================================================
-- SECTION 2.4: MISSINGNESS HANDLING IN SQL
-- ============================================================

-- 2.4.1 Audit missingness BEFORE it hits R
-- Always do this in SQL — catch problems at the source
SELECT
    COUNT(*)                                        AS total_rows,
    SUM(CASE WHEN days_since_last_report IS NULL THEN 1 ELSE 0 END)
                                                    AS missing_days_last,
    ROUND(AVG(CASE WHEN days_since_last_report IS NULL THEN 1.0 ELSE 0 END)*100,1)
                                                    AS pct_missing_days,
    SUM(CASE WHEN substance_use_flag IS NULL THEN 1 ELSE 0 END)
                                                    AS missing_substance,
    ROUND(AVG(CASE WHEN substance_use_flag IS NULL THEN 1.0 ELSE 0 END)*100,1)
                                                    AS pct_missing_substance,
    SUM(CASE WHEN days_to_first_contact IS NULL THEN 1 ELSE 0 END)
                                                    AS missing_contact,
    ROUND(AVG(CASE WHEN days_to_first_contact IS NULL THEN 1.0 ELSE 0 END)*100,1)
                                                    AS pct_missing_contact
FROM features;

-- 2.4.2 Create missingness indicators IN SQL (before hitting R)
-- RULE: Create indicators BEFORE imputing
SELECT
    report_id,
    family_id,
    prior_reports_12mo,
    prior_reports_12mo > 0                          AS has_prior_report,
    COALESCE(days_since_last_report, -1)            AS days_since_last_report,
    CASE WHEN days_since_last_report IS NULL THEN 1 ELSE 0 END
                                                    AS days_last_missing,
    CASE WHEN substance_use_flag IS NULL THEN 1 ELSE 0 END
                                                    AS substance_flag_missing,
    COALESCE(substance_use_flag, 0)                 AS substance_use_flag,
    CASE WHEN days_to_first_contact IS NULL THEN 1 ELSE 0 END
                                                    AS contact_missing,
    COALESCE(days_to_first_contact,
        AVG(days_to_first_contact) OVER ()
    )                                               AS days_to_first_contact,
    needs_investigative_consultation
FROM features;

-- ============================================================
-- SECTION 2.5: CROSS-AGENCY DATA LINKAGE
-- ============================================================
-- In real ACS work you join SCR to DHS shelter data,
-- DOE school data, NYPD domestic incident reports
-- This simulates that pattern

-- 2.5.1 Join SCR to features (the core join for modeling)
-- Always LEFT JOIN to preserve all SCR reports
SELECT
    s.report_id,
    s.family_id,
    s.borough,
    s.child_age,
    s.allegation_type,
    s.reporter_type,
    s.outcome,
    f.prior_reports_12mo,
    f.prior_substantiated_flag,
    f.dv_history_flag,
    f.shelter_involvement_flag,
    f.child_age_under_5,
    f.needs_investigative_consultation
FROM scr s
LEFT JOIN features f ON s.report_id = f.report_id
ORDER BY s.family_id, s.report_date;

-- 2.5.2 Flag cases where features are missing (data quality check)
SELECT
    s.report_id,
    s.family_id,
    s.report_date,
    CASE WHEN f.report_id IS NULL THEN 'MISSING' ELSE 'PRESENT' END
                                            AS features_status
FROM scr s
LEFT JOIN features f ON s.report_id = f.report_id
WHERE f.report_id IS NULL;
-- Should return 0 rows if data pipeline is clean

-- ============================================================
-- SECTION 2.6: THE FULL FEATURE ENGINEERING QUERY
-- ============================================================
-- This is what you'd run in production to generate
-- the complete feature set for the risk model
-- One query, all features, no manual R preprocessing

WITH

ordered AS (
    SELECT
        s.report_id, s.family_id, s.report_date, s.borough,
        s.child_age, s.allegation_type, s.reporter_type, s.outcome,
        f.prior_reports_12mo, f.prior_substantiated_flag,
        f.dv_history_flag, f.shelter_involvement_flag,
        f.substance_use_flag, f.caseworker_caseload,
        f.days_since_last_report, f.days_to_first_contact,
        f.reporter_accuracy_score,
        f.needs_investigative_consultation
    FROM scr s
    LEFT JOIN features f ON s.report_id = f.report_id
),

with_flags AS (
    SELECT *,
        prior_reports_12mo > 0                  AS has_prior_report,
        COALESCE(days_since_last_report, -1)     AS days_last_clean,
        CASE WHEN days_since_last_report IS NULL THEN 1 ELSE 0 END
                                                 AS days_last_missing,
        CASE WHEN substance_use_flag IS NULL THEN 1 ELSE 0 END
                                                 AS substance_missing,
        COALESCE(substance_use_flag, 0)          AS substance_clean,
        CASE WHEN days_to_first_contact IS NULL THEN 1 ELSE 0 END
                                                 AS contact_missing,
        COALESCE(days_to_first_contact, 3)       AS contact_clean,
        child_age < 5                            AS child_age_under_5,
        caseworker_caseload > 60                 AS high_caseload,
        CASE allegation_type
            WHEN 'Sexual Abuse'                      THEN 5
            WHEN 'Physical Abuse'                    THEN 4
            WHEN 'Domestic Violence Exposure'        THEN 3
            WHEN 'Neglect - Inadequate Supervision'  THEN 2
            WHEN 'Neglect - Medical'                 THEN 2
            ELSE 1
        END                                      AS allegation_severity
    FROM ordered
)

SELECT
    report_id, family_id, borough,
    -- Target
    needs_investigative_consultation,
    -- Features
    prior_reports_12mo, prior_substantiated_flag,
    has_prior_report, days_last_clean, days_last_missing,
    dv_history_flag, shelter_involvement_flag,
    substance_clean, substance_missing,
    contact_clean, contact_missing,
    child_age_under_5, high_caseload,
    allegation_severity, reporter_accuracy_score,
    caseworker_caseload,
    -- Interaction features
    dv_history_flag + shelter_involvement_flag + prior_substantiated_flag
                                                 AS compounded_risk,
    CASE WHEN allegation_severity >= 4 AND child_age_under_5 THEN 1 ELSE 0 END
                                                 AS severe_allegation_young_child
FROM with_flags;

-- EXERCISE 2.1
-- Write a query that finds the top 10 highest-volume reporting institutions
-- (reporter_type + borough combinations) with their substantiation rates
-- and flags any with substantiation_rate < 20% as potential over-reporters

-- EXERCISE 2.2
-- Write a CTE that:
-- 1. Calculates average days between reports per family
-- 2. Flags families where the most recent gap is shorter than their average
-- 3. These are "escalating" families - highest priority for intervention

