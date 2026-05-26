# Safe-Start: Child Welfare Analytics (Real NYC ACS + Simulated + NCANDS Project Tracks)

> **Disclaimer.** This is an independent educational and portfolio project. It is not affiliated with, endorsed by, or developed in partnership with ACS, Columbia University, NDACAN, or any government agency. The simulated-data notebooks use synthetically generated data for learning and prototyping. The real-data track uses publicly published NYC ACS pipeline data (NYC Open Data, Local Law 132 of 2022). The NCANDS/NDACAN project track is a research-design and implementation plan and does not imply that restricted NDACAN data has been committed to this repository.

---

## Overview

This repository contains three connected parts:

1. **Real NYC ACS Data Track** — analysis of real, publicly published NYC ACS child-welfare pipeline data ([NYC Open Data dataset `uhvm-6sct`](https://data.cityofnewyork.us/Social-Services/Report-to-City-Council-on-Demographics-of-Children/uhvm-6sct), Local Law 132 of 2022). Citywide funnel rates, race/ethnicity disproportionality, borough variation, and four-year trends. See [`results/real_data/observations.md`](results/real_data/observations.md).
2. **Simulated Data Learning Track** — R / SQL / Shiny notebooks that build an end-to-end child-welfare analytics workflow (intake risk modeling, fairness evaluation, SHAP explainability, causal inference, NLP on case narratives, Shiny dashboard) on **synthetic intake records**. This is the case-level methodology prototype.
3. **NCANDS/NDACAN Project Track** — research-design and implementation plan + code scaffold for extending the methodology to real child welfare research data obtained through NDACAN.

All three tracks are active parts of this repository. The real-data track is the working analysis on aggregate counts; the simulated track is the case-level methodology prototype; the NCANDS track is the research design for the restricted-data implementation.

> **Why three tracks?** NCANDS is restricted-use and requires a formal NDACAN data-use agreement (weeks to months of paperwork). The real-data track uses what's publicly downloadable today; the simulated track lets the case-level methodology be developed in parallel; the NCANDS plan documents the path to the restricted version.

---

## Repository Structure

```
.
├── README.md
├── data/
│   ├── acs_scr_reports.csv         # Simulated intake records (1,000 cases)
│   ├── acs_features.csv            # Engineered risk features
│   ├── nyc_acs_real/               # Real NYC ACS pipeline data (public)
│   │   ├── local_law_132_demographics.csv
│   │   └── README.md
│   ├── raw/                        # Restricted NDACAN data (gitignored, not committed)
│   └── processed/                  # Cleaned/derived files (gitignored)
├── notebooks/                      # Simulated-data learning notebooks (R / SQL)
│   ├── Module_01_R_Fundamentals_ACS.ipynb
│   ├── Module_02_SQL_ACS.sql
│   ├── Module_03_Predictive_Modeling_R.ipynb
│   ├── Module_04_Imbalanced_Data_Threshold.ipynb
│   ├── Module_05_Feature_Engineering.ipynb
│   ├── Module_06_SHAP_Explainability.ipynb
│   ├── Module_07_Causal_Inference.ipynb
│   └── Module_08_NLP_Narratives.ipynb
├── shiny_app/                      # Production-style Shiny dashboard
│   ├── app.R
│   └── README.md
├── ncands_project/                 # NCANDS code scaffold (runs on NDACAN data)
│   ├── README.md
│   ├── _config.R                   # Column dictionary + paths + constants
│   ├── _utils.R                    # Group CV, suppression, guards
│   ├── 01_load_ncands.R            # Read & normalize NCANDS Child File
│   ├── 02_features.R               # Engineer modeling features
│   ├── 03_model.R                  # tidymodels: logistic + xgboost
│   ├── 04_fairness.R               # Subgroup metrics w/ cell suppression
│   ├── 05_explain.R                # SHAP (aggregate only)
│   ├── 06_causal_rdd.R             # Regression discontinuity template
│   └── run_all.R                   # Orchestrator
├── docs/
│   └── NDACAN_NCANDS_Project_Plan.md   # Research design for the real-data track
├── results/                        # Pipeline outputs
│   ├── observations.md             # Findings on SIMULATED data
│   ├── run_analysis.py             # Reproducible simulated-data pipeline (sklearn + SHAP)
│   ├── summary.json
│   ├── figures/                    # Simulated-data PNG charts
│   ├── tables/                     # Simulated-data CSV tables
│   └── real_data/                  # Findings on REAL NYC ACS data
│       ├── observations.md
│       ├── run_real_analysis.py
│       ├── summary.json
│       ├── figures/
│       └── tables/
└── utils/
    └── simulate_data.py            # Regenerate the synthetic dataset
```

---

## Part 0 — Real NYC ACS Data Track

Analysis on **real, publicly published NYC ACS child-welfare pipeline data** — the demographics-at-each-step report ACS files with City Council under Local Law 132 of 2022. Source: [NYC Open Data dataset `uhvm-6sct`](https://data.cityofnewyork.us/Social-Services/Report-to-City-Council-on-Demographics-of-Children/uhvm-6sct).

The full write-up lives in [`results/real_data/observations.md`](results/real_data/observations.md). Headline findings (FY2022 → FY2025, citywide):

| Metric | FY2022 | FY2025 | Δ |
|---|---:|---:|---:|
| SCR intakes | 92,305 | 89,316 | −3.2% |
| Indication rate per intake | **27.6%** | **22.3%** | −5.3 pts |
| CARES rate per intake | 12.1% | **23.4%** | **+11.3 pts** |
| Emergency removal per intake | 1.66% | 1.53% | −0.13 pts |
| Foster-care entry per intake | 2.68% | 2.64% | flat |

**Read.** The headline pattern is a visible **policy shift**: as the indication rate drops 5 points, the CARES (non-investigation) track rate roughly doubles. Cases aren't disappearing — they're being routed out of formal investigation.

**Race disparity finding (pooled FY2022–FY2025).** Black children are 36.7% of intakes but **47.3% of foster-care entries** — a 1.29× over-representation that appears at the foster-care stage, not the indication stage (37.2% — matching their intake share). The disparity grows as cases move further down the pipeline. White children show the highest per-intake emergency-removal rate (3.16%) — a real counter-pattern that aggregate disparity narratives often miss.

**Reproduce:** `python results/real_data/run_real_analysis.py`. Inputs in `data/nyc_acs_real/`; outputs in `results/real_data/`.

This track does what the simulated track can't: produce findings on *real* NYC numbers. What it *can't* do is case-level prediction — the data is aggregate counts by demographic × fiscal year. For the case-level methodology, see Part 1.

---

## Part 1 — Simulated Data Learning Track

This is a personal learning project I use to practice the full child welfare analytics stack on synthetic intake records. Nothing here is connected to real cases or any agency system.

### Modules

| Module | Topic | Key Concepts | R Packages |
|---|---|---|---|
| 01 | R Fundamentals | dplyr, ggplot2, joins, missingness | tidyverse, janitor, skimr |
| 02 | SQL | Window functions, CTEs, feature engineering | DBI, duckdb |
| 03 | Predictive Modeling | Logistic regression, random forest, XGBoost | tidymodels, ranger, xgboost |
| 04 | Imbalanced Data & Thresholding | SMOTE, AUC-PR, F2, fairness audit | themis, probably, yardstick |
| 05 | Feature Engineering | Temporal, severity, reporter, NLP, interactions | tidytext, slider |
| 06 | SHAP Explainability | Waterfall plots, global importance, counterfactuals | shapviz, treeshap |
| 07 | Causal Inference | RDD, PSM, DiD, IV | rdrobust, MatchIt, did, AER |
| 08 | NLP Narratives | TF-IDF, LDA, sentiment, keyword features | tidytext, topicmodels |
| 09 | Production Shiny (`shiny_app/`) | Risk + SHAP + fairness dashboard | shiny, plotly, DT, leaflet |

### Current Data (simulated only)

`acs_scr_reports.csv` — synthetic intake records modeled loosely on the kind of fields a Statewide Central Register-style intake system might contain. `acs_features.csv` — engineered features with realistic missingness patterns. All values are randomly generated; **no real children, families, caseworkers, or cases are represented**. Regenerate with `python utils/simulate_data.py`.

| Column (features) | Description | Missingness |
|---|---|---|
| prior_reports_12mo | Reports in last 12 months | None |
| prior_substantiated_flag | Prior substantiated report (0/1) | None |
| days_since_last_report | Days since previous report | ~63% structural (NA = no prior report) |
| child_age_under_5 | Child under 5 years old (0/1) | None |
| dv_history_flag | Domestic violence history (0/1) | None |
| substance_use_flag | Caregiver substance use concern | ~15% MAR |
| shelter_involvement_flag | Shelter system involvement (0/1) | None |
| days_to_first_contact | Days until first caseworker contact | ~8% data entry gap |
| reporter_accuracy_score | Historical reporter accuracy | None |
| caseworker_caseload | Caseworker caseload size | None |
| needs_investigative_consultation | **TARGET** (0/1) | None |

### Methods Covered

- Group-aware cross-validation to avoid family-level leakage.
- Missing-indicator + multiple-imputation handling for informative missingness.
- Class-imbalance handling (SMOTE, class weights) and threshold tuning under F2/recall constraints.
- Fairness audit disaggregated by borough/race/ethnicity (false positive / false negative rate parity).
- SHAP explanations at the case level and global level, plus simple counterfactuals.
- Causal designs: regression discontinuity at a risk-score threshold, propensity score matching, difference-in-differences, instrumental variables.
- Narrative text mining: tidytext pipelines, TF-IDF, LDA topic modeling, sentiment scoring.

### Results

A pre-computed run of the pipeline on the simulated data lives in [`results/`](results/observations.md) — descriptive stats, group-aware CV metrics for logistic / RF / GBM, threshold sweep (with both F2-max and operational top-K% cutoffs), fairness audit by borough and race/ethnicity, and global SHAP importance, with figures.

### How to Run

```r
# In R / RStudio / Colab with R kernel
install.packages(c(
  "tidyverse", "tidymodels", "ranger", "xgboost",
  "themis", "shapviz", "rdrobust", "MatchIt", "did", "AER",
  "tidytext", "topicmodels",
  "shiny", "shinydashboard", "plotly", "DT", "leaflet"
))
# Open notebooks/ in order, or run the dashboard with:
# shiny::runApp("shiny_app")
```

---

## Part 2 — NCANDS/NDACAN Project Track

This track has two parts: a research-design document (`docs/`) and a runnable code scaffold (`ncands_project/`) that mirrors the simulated pipeline and is ready to execute once real data lands in `data/raw/`. The scripts safely no-op when that directory is empty, which is the current state of the public repo.

The full plan lives in [docs/NDACAN_NCANDS_Project_Plan.md](docs/NDACAN_NCANDS_Project_Plan.md). Highlights:

- **Primary dataset:** [NCANDS Child File](https://www.ndacan.acf.hhs.gov/datasets/datasets-list.cfm) — the case-level federal dataset of child maltreatment reports and dispositions (NDACAN, 2000–2024).
- **Context dataset:** NCANDS Agency File — state-year administrative context.
- **Policy context:** [SCAN Policies Database](https://www.ndacan.acf.hhs.gov/datasets/datasets-list.cfm) — state-year statutory variation used as the identification source for the DiD design.
- **Possible extensions:** AFCARS (Foster Care / Adoption / 6-month), NYTD (transition-age youth outcomes), NSCAW I/II (longitudinal well-being), NIS (incidence), LONGSCAN (longitudinal cohort).
- **Research questions:** rereport / resubstantiation prediction, equity audits across reporter source and race/ethnicity, threshold-based causal effects of investigation disposition on rereferral, and state-level policy event studies.
- **Modeling plan:** mirror Part 1 — group-aware CV at the child/family level, imbalanced-class handling, calibrated thresholds, fairness disaggregation, SHAP explanations, and pre-registered causal designs (RDD / DiD / IV where identifiable).
- **Ethics and governance:** NDACAN Terms of Use compliance, minimum-cell suppression, no individual-level publication, IRB review where applicable, and a documented access workflow before any data is touched.
- **Data handling:** `data/raw/` and `data/processed/` are **gitignored**. Restricted NDACAN files will never be committed to this repository.

This is a project roadmap and research design. It does not assert that NDACAN data has been requested, received, or analyzed yet.

---

## Data Governance

- Synthetic data in `data/*.csv` is safe to commit and share.
- Any real NDACAN-derived data must live under `data/raw/` (immutable) or `data/processed/` (derived) and is **excluded from version control** via `.gitignore`.
- All analyses of real data must comply with the NDACAN Terms of Use, including minimum-cell suppression and no re-identification attempts.
- See [docs/NDACAN_NCANDS_Project_Plan.md](docs/NDACAN_NCANDS_Project_Plan.md) for the full governance plan.

---

## Resources

| Topic | Resource |
|---|---|
| R for Data Science | r4ds.hadley.nz |
| Tidymodels | tidymodels.org |
| Feature Engineering | bookdown.org/max/FES |
| Text Mining with R | tidytextmining.com |
| Causal Inference: The Mixtape | mixtape.scunning.com |
| Mastering Shiny | mastering-shiny.org |
| NDACAN | ndacan.acf.hhs.gov |
