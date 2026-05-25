# NCANDS Project — Code Scaffold

> **No restricted data lives here.** This directory contains R scripts designed to run on the NCANDS Child File once it has been obtained from NDACAN under a Restricted Data Use Agreement. The scripts safely exit with an informative message when `../data/raw/` is empty, which it is in this repository.

The scaffold mirrors the simulated-track pipeline in `notebooks/` so the methodology transfers with only a schema-mapping layer.

## Layout

```
ncands_project/
├── README.md
├── _config.R              # NCANDS column dictionary + paths + constants
├── _utils.R               # Shared helpers (grouped CV, fairness metrics, guards)
├── 01_load_ncands.R       # Read raw NCANDS file, normalize schema, write processed/
├── 02_features.R          # Engineer modeling features (prior involvement, etc.)
├── 03_model.R             # tidymodels: logistic + xgboost with group-aware CV
├── 04_fairness.R          # Subgroup metrics, calibrated thresholds
├── 05_explain.R           # SHAP global importance + sampled case-level
├── 06_causal_rdd.R        # Regression discontinuity at risk-score threshold
└── run_all.R              # Orchestrator (calls scripts 01–06 in order)
```

## How it relates to the simulated track

| Simulated notebook | NCANDS script | What carries over |
|---|---|---|
| Module_03 | `03_model.R` | Group-aware CV, LR + XGB, AUC-PR/Brier |
| Module_04 | `04_fairness.R` | Imbalance handling, F2 thresholding, subgroup metrics |
| Module_05 | `02_features.R` | Prior-involvement, temporal, severity features |
| Module_06 | `05_explain.R` | SHAP (aggregate only — no row-level publication) |
| Module_07 | `06_causal_rdd.R` | RDD at the screening/risk threshold |

## Prerequisites before running

1. Executed NDACAN Restricted Data Use Agreement.
2. NCANDS Child File placed in `../data/raw/` (e.g., `../data/raw/ncands_child_<YEAR>.{csv,sas7bdat,dat}`).
3. Local R environment with the packages listed in `_config.R`.

## Schema caveat

The NCANDS codebook changes year to year (variable names, code values, recoding rules). `_config.R` ships with a documented starting-point dictionary; **verify every mapping against the NDACAN codebook for your specific data year before publishing any results.**

## What this scaffold deliberately does NOT do

- Distribute, link to, or auto-download NDACAN data.
- Produce row-level outputs intended for publication.
- Bypass NDACAN minimum-cell suppression (helpers in `_utils.R` enforce `n >= 11`).
- Persist any identifiable artifacts under version control.

See [../docs/NDACAN_NCANDS_Project_Plan.md](../docs/NDACAN_NCANDS_Project_Plan.md) for the full research design.
