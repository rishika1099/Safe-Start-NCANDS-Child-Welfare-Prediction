# NCANDS / NDACAN Project Plan

> **Disclaimer.** This is an independent educational and portfolio project. This document is a research-design and implementation plan. It does not imply that restricted NDACAN data has been requested, received, analyzed, or committed to this repository at the time of writing. All references to ACS, Columbia University, NDACAN, and federal agencies are for context only; no affiliation or endorsement is implied.

This document describes how the methodology prototyped on synthetic data in `notebooks/` will be applied to real child welfare research data obtained through the **National Data Archive on Child Abuse and Neglect (NDACAN)** at Cornell University.

---

## 1. Motivation

Child welfare administrative data is widely used to develop predictive risk tools, fairness audits, and policy evaluations, but published work often understates: (a) how informative-missingness in front-end administrative data biases models, (b) how class-imbalance and threshold choice interact with subgroup error rates, and (c) how rarely models are validated under a clearly-specified causal estimand. This project track is a personal research exercise to apply the methods practiced in Part 1 (the simulated track) to **real, de-identified, restricted-use research data**, with documented ethics and data governance.

The goal is a portfolio-quality, reproducible study — not a deployed decision-support tool. No outputs from this work are intended to influence real casework.

---

## 2. Datasets

### 2.1 Primary: NCANDS Child File

The **NCANDS Child File** is the case-level federal dataset of child maltreatment reports submitted by state child welfare agencies. Each row represents a child involved in a screened-in report, with fields covering report source, alleged maltreatment types, investigation disposition, services received, and limited demographics. It is the first dataset I plan to request because it directly mirrors the structure of the simulated intake records in Part 1 (one row per report-child), which makes it the cleanest place to validate that the modeling pipeline transfers from simulated to real data.

### 2.2 Context: NCANDS Agency File

The **NCANDS Agency File** provides state-year administrative context (workforce, intake volume, screen-in rates). It will be used as a state-year covariate layer to support fairness comparisons and policy-event causal designs.

### 2.3 Possible Extensions

- **AFCARS Foster Care File** — to study downstream foster-care entry following investigation.
- **NYTD (National Youth in Transition Database)** — transition-age youth outcomes.
- **NSCAW (National Survey of Child and Adolescent Well-Being)** — longitudinal well-being measures; useful for outcome validity checks.
- **NIS (National Incidence Study)** — population-level incidence comparisons; useful for understanding under-reporting bias in NCANDS.

Extensions will only be pursued if they meaningfully strengthen the research questions; each adds its own data-use obligations.

---

## 3. Research Questions

1. **Rereport / resubstantiation prediction.** Given a screened-in report, what is the probability of a subsequent rereport (or substantiated rereport) within 6 / 12 / 24 months? How does predictive performance compare across model families (regularized logistic regression, gradient-boosted trees) and across feature sets (intake-only vs. intake + prior-history)?
2. **Equity audit.** Conditional on risk score, do false positive and false negative rates differ by reporter source, race/ethnicity, and child age band? Where do disparities concentrate?
3. **Threshold-based causal effects.** Where state agencies use a screening or risk-assessment threshold, can a regression-discontinuity design estimate the local causal effect of investigation (vs. screen-out) on subsequent rereferral?
4. **Policy event studies.** Using NCANDS Agency File state-year context, do mandated-reporter expansions or differential-response policy changes shift rereport rates? Difference-in-differences with appropriate parallel-trends diagnostics.

Each research question has a pre-specified estimand, a pre-specified identification strategy, and a pre-specified sensitivity analysis. These will be documented in `docs/` before any modeling on real data.

---

## 4. Modeling Plan

The modeling stack mirrors Part 1 deliberately so the simulated-track code generalizes:

- **Splitting.** Group-aware cross-validation at the child (and where possible, family) level to prevent leakage from repeat involvement.
- **Missingness.** Missing-indicator columns + multiple imputation for fields where missingness is plausibly informative.
- **Class imbalance.** Class weights and resampling (SMOTE / downsampling) compared head-to-head; performance reported on the untouched distribution.
- **Metrics.** AUC-PR (primary), Brier score (calibration), F2 (recall-weighted operating point), and subgroup confusion-matrix metrics.
- **Calibration.** Isotonic / Platt scaling validated on held-out folds before any threshold tuning.
- **Thresholding.** Thresholds chosen against an explicit operational constraint (e.g., maximum positive-class rate); reported separately by subgroup.
- **Explanation.** SHAP values for global feature attribution and case-level explanations on a held-out sample (no individual cases re-identified or published).
- **Causal designs.** RDD (`rdrobust`) at the threshold, PSM (`MatchIt`) for selection-on-observables checks, DiD (`did`) for staggered policy adoption, IV where a credible instrument exists.

---

## 5. Ethics and Data Governance

- **Access.** NDACAN data is obtained under a Restricted Data Use Agreement after IRB review where applicable. Access is requested through the standard NDACAN application process. No analysis begins until the agreement is signed.
- **Storage.** Raw NDACAN files live only in `data/raw/` on an encrypted local volume. `data/processed/` holds cleaned/derived artifacts. **Both directories are `.gitignore`d.** Restricted-use data will never be committed to this repository or any other public location.
- **Aggregation and suppression.** All published outputs follow NDACAN minimum-cell suppression rules (typically n < 11). Subgroup tables are reviewed for residual disclosure risk before being shared.
- **No re-identification.** No attempt will be made to link NCANDS records to external identifiers, public records, or other restricted datasets beyond what is explicitly permitted in the data-use agreement.
- **No deployment.** Outputs from this work are not intended for use in real child welfare decisions. Any model artifacts shared (e.g., feature importances, calibration curves) are aggregate, not row-level.
- **Reproducibility vs. confidentiality.** Code and aggregate outputs are reproducible; raw inputs and individual-level outputs are not shared. Where a figure depends on suppressed cells, the figure is published with the suppression noted.

---

## 6. Access Workflow

1. Draft a research plan summarizing the questions above with sample-size justification.
2. Submit NDACAN application; obtain IRB determination/approval where required.
3. Execute Restricted Data Use Agreement.
4. Receive NCANDS Child File (and Agency File) under the agreement; place under `data/raw/` on an encrypted local volume.
5. Run pipeline mirroring `notebooks/Module_03`–`Module_07` on real data.
6. Produce aggregate-only artifacts (calibration curves, subgroup metrics, RDD plots) under `data/processed/`; suppress cells per NDACAN rules.
7. Publish write-up + code in this repository. Do **not** publish raw data, intermediate row-level files, or any output that could re-identify a record.

---

## 7. Project Roadmap

This roadmap is sequenced, not time-boxed. Each step is gated on the previous one and on the data-access status.

1. **Simulated-track hardening.** Make sure every method in `notebooks/Module_03`–`Module_07` runs end-to-end on synthetic data, including subgroup metrics and at least one causal design with a sensitivity check. (in progress)
2. **Research-plan write-up.** A short standalone document for each research question with estimand, identification, model spec, and sensitivity analyses.
3. **NDACAN application** + IRB determination.
4. **Data intake.** Place restricted files in `data/raw/`; verify gitignore; confirm storage controls.
5. **Pipeline port.** Re-run the simulated-track pipeline on real data with no code changes beyond schema mapping.
6. **Equity audit and causal designs.** Produce aggregate outputs only; apply suppression rules.
7. **Write-up and code release.** Publish methods, aggregate results, and code in this repository.

Status of each step is tracked in the repository (issues / commit history), not in this document, so the plan does not silently go stale.

---

## 8. Out of Scope

- Real-time scoring or any form of deployment.
- Linkage to any identified dataset.
- Any analysis intended to influence specific cases, caseworkers, or jurisdictions.
- Publication of row-level data, individual-case SHAP plots, or any output that risks re-identification.
