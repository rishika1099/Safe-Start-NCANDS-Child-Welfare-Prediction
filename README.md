# Safe-Start: Child Welfare Analytics

> **Disclaimer.** This is an independent educational and portfolio project. It is not affiliated with, endorsed by, or developed in partnership with ACS, Columbia University, or any government agency. Part 1 uses synthetic data for learning. Part 2 uses publicly published NYC ACS data (NYC Open Data, Local Law 132 of 2022).

This repository has **two parts**:

1. **[Learning Notebooks](#part-1--learning-notebooks-simulated-data)** — R / SQL / Shiny notebooks that build a case-level child-welfare analytics workflow (modeling, fairness, SHAP, causal inference, NLP, dashboard) on synthetic intake records.
2. **[Real-Data Project](#part-2--real-data-project-nyc-acs)** — analysis of real NYC ACS pipeline data: citywide funnel rates, race/ethnicity disparities, borough variation, four-year trends.

---

## Repository structure

```
.
├── README.md
│
├── notebooks/                         # PART 1: learning notebooks (simulated)
│   ├── Module_01_R_Fundamentals_ACS.ipynb
│   ├── Module_02_SQL_ACS.sql
│   ├── Module_03_Predictive_Modeling_R.ipynb
│   ├── Module_04_Imbalanced_Data_Threshold.ipynb
│   ├── Module_05_Feature_Engineering.ipynb
│   ├── Module_06_SHAP_Explainability.ipynb
│   ├── Module_07_Causal_Inference.ipynb
│   └── Module_08_NLP_Narratives.ipynb
├── shiny_app/                         # PART 1: production-style Shiny dashboard
│   ├── app.R
│   └── README.md
├── utils/
│   └── simulate_data.py               # PART 1: regenerate the synthetic CSVs
│
├── data/
│   ├── acs_scr_reports.csv            # PART 1: simulated intake records
│   ├── acs_features.csv               # PART 1: engineered features
│   └── nyc_acs_real/                  # PART 2: real NYC ACS data
│       ├── local_law_132_demographics.csv
│       └── README.md
│
└── results/                           # PART 2: real-data analysis output
    ├── observations.md                # findings write-up
    ├── run_real_analysis.py           # reproducible pipeline
    ├── summary.json
    ├── figures/                       # 6 PNGs
    └── tables/                        # 7 CSVs
```

---

## Part 1 — Learning Notebooks (simulated data)

The case-level methodology side. These notebooks let me practice the full child-welfare analytics stack — intake risk modeling, fairness evaluation, SHAP explainability, causal inference, NLP on case narratives, and a production-style Shiny dashboard — on synthetic intake records that mimic the shape of an NYC SCR intake system. Nothing in Part 1 represents real cases.

| Module | Topic | Key concepts | R packages |
|---|---|---|---|
| 01 | R Fundamentals | dplyr, ggplot2, joins, missingness | tidyverse, janitor, skimr |
| 02 | SQL | Window functions, CTEs, feature engineering | DBI, duckdb |
| 03 | Predictive Modeling | Logistic regression, RF, XGBoost | tidymodels, ranger, xgboost |
| 04 | Imbalanced Data & Thresholding | SMOTE, AUC-PR, F2, fairness audit | themis, probably, yardstick |
| 05 | Feature Engineering | Temporal, severity, reporter, NLP, interactions | tidytext, slider |
| 06 | SHAP Explainability | Waterfall plots, global importance | shapviz, treeshap |
| 07 | Causal Inference | RDD, PSM, DiD, IV | rdrobust, MatchIt, did, AER |
| 08 | NLP Narratives | TF-IDF, LDA, sentiment | tidytext, topicmodels |
| — | Shiny Dashboard | Risk + SHAP + fairness in `shiny_app/` | shiny, plotly, DT |

### Run

```r
install.packages(c(
  "tidyverse", "tidymodels", "ranger", "xgboost",
  "themis", "shapviz", "rdrobust", "MatchIt", "did", "AER",
  "tidytext", "topicmodels",
  "shiny", "shinydashboard", "plotly", "DT", "leaflet"
))
# Open notebooks in order. Or run the dashboard with:
shiny::runApp("shiny_app")
```

To regenerate the synthetic CSVs: `python utils/simulate_data.py`.

---

## Part 2 — Real-Data Project (NYC ACS)

Analysis of real, publicly published NYC ACS child-welfare pipeline data — the demographics-at-each-step report ACS files with City Council under **Local Law 132 of 2022**. Source: [NYC Open Data dataset `uhvm-6sct`](https://data.cityofnewyork.us/Social-Services/Report-to-City-Council-on-Demographics-of-Children/uhvm-6sct). Pulled 2026-05-25.

Coverage: **fiscal years FY2022–FY2025**, ~371,000 SCR intakes pooled. Demographic axes: race/ethnicity, gender, language, borough/community district. Outcome columns: SCR intakes, indicated investigations, unsubstantiated investigations, CARES cases, ACS referrals to prevention, emergency removals, Article X filings, remands, foster-care entries.

Full write-up: [`results/observations.md`](results/observations.md).

### Headline findings

**Citywide trend (FY2022 → FY2025).**

| FY | SCR intakes | Indication rate | CARES rate | Emergency removal | Foster-care entry |
|---|---:|---:|---:|---:|---:|
| 2022 | 92,305 | **27.6%** | 12.1% | 1.66% | 2.68% |
| 2025 | 89,316 | **22.3%** | **23.4%** | 1.53% | 2.64% |

Indication rate dropped 5.3 points while the CARES (non-investigation) rate roughly doubled. A visible policy shift: cases are being routed out of formal investigation, not disappearing.

**Race/ethnicity disproportionality (pooled FY2022–FY2025).**

| Group | Share of SCR intakes | Share of foster-care entries | Disparity |
|---|---:|---:|---:|
| Black, non-Hispanic | 36.7% | **47.3%** | **1.29×** at foster-care entry |
| Hispanic/Latinx | 46.3% | 40.8% | 0.88× |
| White, non-Hispanic | 6.5% | 4.9% | 0.75× |

Black children's over-representation appears at the **foster-care entry** stage, not at indication. Aggregate disparity numbers usually hide this stage-by-stage decomposition.

**Counter-pattern: per-intake emergency-removal rate is highest for White children (3.16%)**, versus 1.50% for Black children. Possible explanation is severity selection at intake; aggregate data alone can't disambiguate, but it's worth flagging.

### Run

```bash
python results/run_real_analysis.py
```

Requires `pandas`, `numpy`, `matplotlib`, `seaborn`. Inputs in `data/nyc_acs_real/`; outputs written to `results/`.

---

## Why two parts (and why not NCANDS directly)

The case-level federal NCANDS Child File is what would let me run the Part 1 methodology on real cases — but it is **restricted-use research data** distributed only through NDACAN under a formal Restricted Data Use Agreement that typically requires institutional sponsorship, IRB review, and weeks of paperwork. It is not downloadable.

The repository therefore separates the case-level methodology (Part 1, on synthetic data the project owns) from the real-data findings (Part 2, on publicly downloadable NYC aggregate data). The notebooks teach what would be done with NCANDS; the results in `results/` use the real data that is available today.
