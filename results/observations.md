# Results — Real NYC ACS Pipeline Data (Local Law 132)

> Real, publicly published data from NYC ACS, mandated by **Local Law 132 of 2022**. Pulled from [NYC Open Data dataset `uhvm-6sct`](https://data.cityofnewyork.us/Social-Services/Report-to-City-Council-on-Demographics-of-Children/uhvm-6sct) on 2026-05-25. See [`../data/nyc_acs_real/README.md`](../data/nyc_acs_real/README.md) for provenance.

This is **Part 2** of the repository: the actual-data project. Unit of analysis is aggregate counts by demographic group × fiscal year, so the analysis is rate-level disparity, pipeline-stage decomposition, and four-year trend — not case-level prediction. For the case-level methodology, see Part 1 ([`../notebooks/`](../notebooks/)).

## Headline numbers (citywide, children — [tables/01_citywide_funnel_rates.csv](tables/01_citywide_funnel_rates.csv))

| FY | SCR intakes | Indication rate | CARES rate | Prevention referral | Emergency removal | Foster entry |
|---|---:|---:|---:|---:|---:|---:|
| 2022 | 92,305 | **27.6%** | 12.1% | 20.1% | 1.66% | 2.68% |
| 2023 | 95,590 | 23.1% | 18.0% | 17.5% | 1.44% | 2.38% |
| 2024 | 94,121 | 22.5% | 24.2% | 15.9% | 1.52% | 2.57% |
| 2025 | 89,316 | **22.3%** | **23.4%** | 16.2% | 1.53% | 2.64% |

**Read.** Two clear shifts FY2022 → FY2025:

1. **Indication rate dropped from 27.6% to 22.3%** — a 5-point decline (~19% relative). Could be a real change in case severity, but more plausibly reflects:
2. **CARES rate nearly doubled from 12.1% to 23.4%** — cases are being diverted out of formal investigation into the CARES (Collaborative Assessment Response Engagement and Support) non-investigative track. This isn't a fairness audit finding; it's a visible **policy shift in the actual NYC data**: a growing fraction of intakes are being handled outside the indication pipeline.

Emergency removal and foster-entry rates are roughly flat (1.4–1.7%, 2.4–2.7%), so the downstream stages of the system don't appear to have absorbed the indication-rate shift one-to-one.

## Race/ethnicity disparities (pooled FY2022–FY2025)

[tables/05_race_disproportionality.csv](tables/05_race_disproportionality.csv) · [figures/fig05_race_disproportionality.png](figures/fig05_race_disproportionality.png)

| Group | SCR intakes (share) | Indicated (share) | Foster-care entries (share) | Indication per intake | Emergency removal per intake | Foster entry per intake |
|---|---:|---:|---:|---:|---:|---:|
| Hispanic/Latinx | **46.3%** | 48.8% | 40.8% | 25.2% | 1.44% | 2.26% |
| Black, non-Hispanic | **36.7%** | 37.2% | **47.3%** | 24.3% | 1.50% | **3.31%** |
| White, non-Hispanic | 6.5% | 5.4% | 4.9% | 19.6% | **3.16%** | 1.93% |
| Asian/Pacific Islander | 4.5% | 3.9% | 2.2% | 20.4% | 0.90% | 1.27% |
| Multiple Race | 3.2% | 3.3% | 4.2% | 24.5% | 1.80% | 3.40% |
| Other/Unknown | 2.8% | 1.5% | 0.6% | 12.8% | 0.48% | 0.56% |

**Read — three findings that show up at different stages of the pipeline:**

1. **Foster-care-entry disproportionality is concentrated at the Black-non-Hispanic group.** Black children account for **36.7% of intakes but 47.3% of foster-care entries** — a 1.29× over-representation at the foster-entry stage that doesn't show up at the indication stage (37.2% — roughly matching their intake share). The disparity grows as cases move further down the pipeline.
2. **Per-intake emergency-removal rate is HIGHEST for White children (3.16%).** This is initially surprising. A plausible structural explanation: White children's intakes may be less common but more severe on average (e.g., concentrated in cases serious enough to enter the system at all). I can't disambiguate from aggregate data alone, but it's worth flagging — the simple narrative of "Black/Hispanic children are flagged more aggressively at every stage" doesn't hold for the emergency-removal stage specifically.
3. **Foster-entry-per-intake rate is highest for Black children (3.31%)** even though White children have higher per-intake emergency-removal rates. So Black children's pathway from intake → foster care is shorter on a per-intake basis, but the emergency-removal step (often court-driven) tilts the other way. This is the kind of stage-by-stage decomposition that aggregate disparity numbers usually hide.

## Indication rate over time by race — [figures/fig03_indication_rate_by_race.png](figures/fig03_indication_rate_by_race.png)

| Group | FY2022 | FY2023 | FY2024 | FY2025 | Change |
|---|---:|---:|---:|---:|---:|
| African American/Black | 28.3% | 23.4% | 22.4% | 22.7% | **−5.6 pts** |
| Hispanic/Latinx | 28.8% | 24.4% | 23.9% | 23.8% | −5.0 pts |
| Multiple Race | 29.3% | 24.4% | 22.2% | 22.2% | −7.1 pts |
| Asian/Pacific Islander | 22.7% | 19.2% | 20.4% | 18.6% | −4.1 pts |
| White, non-Hispanic | 22.1% | 19.5% | 18.4% | 18.3% | −3.8 pts |

The indication-rate decline shows up across every race/ethnicity group, which is consistent with the CARES-diversion explanation above (the policy shift moves cases out of the indication pipeline uniformly) rather than a group-targeted change.

## Borough variation — [tables/06_borough_rates_by_fy.csv](tables/06_borough_rates_by_fy.csv) · [figures/fig06_indication_rate_by_borough.png](figures/fig06_indication_rate_by_borough.png)

Indication rate per SCR intake by borough:

| Borough | FY2022 | FY2023 | FY2024 | FY2025 |
|---|---:|---:|---:|---:|
| Brooklyn | **30.8%** | 23.3% | 23.4% | **24.6%** |
| Bronx | 27.9% | 25.4% | 24.6% | **16.7%** |
| Manhattan | 27.1% | 21.7% | 20.4% | 21.9% |
| Queens | 25.6% | 23.1% | 22.0% | 19.9% |
| Staten Island | 20.4% | 14.4% | 14.2% | 12.1% |

**Read.**
- Brooklyn has the highest indication rate across most years.
- The Bronx underwent a notable single-year shift: FY2024 → FY2025 indication rate dropped from 24.6% to **16.7%**, even as Bronx SCR intakes spiked from 13,818 to 18,570 (+34%). One plausible read: a large increase in intakes diluted the indication rate (more low-severity intakes); another is a borough-specific operational change. Aggregate data alone can't tell us which, but the magnitude is large enough to flag.
- Staten Island had the lowest indication rate every year and dropped sharply over the period (20.4% → 12.1%).

## How this differs from Part 1 (notebooks)

The [notebooks](../notebooks/) teach case-level methodology — group-aware CV, threshold tuning, SHAP, fairness audit — on synthetic data structured one-row-per-case. This file uses real NYC ACS data, which is published only as aggregate counts. So:

| Aspect | Part 1 — Notebooks (simulated) | Part 2 — Real data (this file) |
|---|---|---|
| Data | 1,000 fabricated case-level rows | NYC ACS counts, FY2022–FY2025 (~371k SCR intakes pooled) |
| Unit | One row per case | Counts by demographic × FY |
| Task | Binary classification | Rate, share, disparity, trend |
| Output | ROC-AUC, SHAP, fairness audit | Per-intake rates, disproportionality, time series |

## Caveats

- **Aggregate, not case-level.** No individual-level model can be trained on this data. Sub-group comparisons are limited to the four axes published (race/ethnicity, gender, language, borough/CD).
- **`^` cells.** A few cells in the source CSV are marked `^` (suppressed). Read as missing; affected subgroups have fewer years available.
- **No demographic denominator.** Per-intake rates compare populations *given* they entered the system. A per-capita "rate of system involvement" would require joining NYC Census child-population estimates — a natural extension, not done here.
- **Pipeline definitions evolve.** The CARES program in particular has changed over the period covered, contributing to the indication-rate trend.
- **No causal claim.** The CARES-diversion explanation is the most parsimonious story given the simultaneous indication-rate drop and CARES-rate rise, but this is a correlational observation in administrative reporting data.

## Reproduce

```bash
python results/run_real_analysis.py
```

Inputs: [`../data/nyc_acs_real/local_law_132_demographics.csv`](../data/nyc_acs_real/local_law_132_demographics.csv).
Outputs: [`tables/`](tables/), [`figures/`](figures/), [`summary.json`](summary.json).

## Artifacts

```
results/
├── observations.md            ← this file
├── run_real_analysis.py
├── summary.json
├── figures/                   ← 6 PNGs (funnel, race share, indication & removal by race over time, disproportionality, borough)
└── tables/                    ← 7 CSVs
```
