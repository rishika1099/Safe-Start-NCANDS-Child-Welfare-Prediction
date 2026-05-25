# Shiny App — Child Welfare Analytics (Simulated)

A production-style R Shiny dashboard built on the synthetic intake records in `../data/`. It demonstrates a five-tab analyst workflow (overview, reporter analysis, risk model, SHAP explainability, fairness audit) on simulated data.

**This dashboard runs on synthetic data only.** It is part of an independent learning project and is not affiliated with ACS, Columbia, or any agency. Do not interpret any output as reflecting real cases.

## Run

From the repository root:

```r
shiny::runApp("shiny_app")
```

## Dependencies

```r
install.packages(c(
  "shiny", "shinydashboard", "tidyverse", "tidymodels",
  "ranger", "shapviz", "leaflet", "DT", "plotly"
))
```

## Data

The app reads:

- `../data/acs_scr_reports.csv` — simulated intake records
- `../data/acs_features.csv` — engineered features

Regenerate with `python ../utils/simulate_data.py`.

## Tabs

| Tab | Content |
|---|---|
| Overview | Volume, substantiation rate, high-risk count, borough/allegation breakdowns |
| Reporter Analysis | Substantiation rate by reporter type |
| Risk Model | Score distribution, threshold sweep, top-risk table |
| SHAP | Global importance + per-case waterfall plots |
| Fairness Audit | FPR / recall disaggregated by borough |
