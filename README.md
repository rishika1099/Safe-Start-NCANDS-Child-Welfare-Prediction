# Safe-Start: Child Welfare Predictive Analytics (Simulated + NCANDS Project Tracks)

> **Disclaimer.** This is an independent educational and portfolio project. It is not affiliated with, endorsed by, or developed in partnership with ACS, Columbia University, NDACAN, or any government agency. The simulated-data notebooks use synthetically generated data for learning and prototyping. The NCANDS/NDACAN project track is a research-design and implementation plan and does not imply that restricted NDACAN data has been committed to this repository.

---

## Overview

This repository contains two connected parts:

1. **Simulated Data Learning Track** — a set of R / SQL / Shiny notebooks that build an end-to-end child welfare analytics workflow (intake risk modeling, fairness evaluation, SHAP explainability, causal inference, NLP on case narratives, and a production-style Shiny dashboard) on **synthetic intake records**.
2. **NCANDS/NDACAN Project Track** — a research-design and implementation plan that documents how the same methodology will be applied to real child welfare research data obtained through the **National Data Archive on Child Abuse and Neglect (NDACAN)**, including dataset selection, research questions, modeling approach, causal inference design, ethics review, and data governance.

Both tracks are active parts of this repository. The simulated track is the working prototype; the NCANDS track is the research design and roadmap for the real-data implementation.

---

## Repository Structure

```
.
├── README.md
├── data/
│   ├── acs_scr_reports.csv         # Simulated intake records (1,000 cases)
│   ├── acs_features.csv            # Engineered risk features
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
└── utils/
    └── simulate_data.py            # Regenerate the synthetic dataset
```

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
