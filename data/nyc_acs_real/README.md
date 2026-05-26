# NYC ACS Child Welfare Demographics — Local Law 132 of 2022

## What this is

Real, publicly published New York City Administration for Children's Services (ACS) child welfare data, mandated by **Local Law 132 of 2022**. It reports demographic counts at each step of the NYC child welfare system pipeline:

```
SCR intake → CARES case → Investigation → Indication → Emergency removal → Article X filing → Remand → Foster care entry
```

## Source

- **Dataset:** "Report to City Council on Demographics of Children and Parents at Steps in the Child Welfare System"
- **NYC Open Data ID:** `uhvm-6sct`
- **Portal page:** https://data.cityofnewyork.us/Social-Services/Report-to-City-Council-on-Demographics-of-Children/uhvm-6sct
- **Direct CSV:** https://data.cityofnewyork.us/api/views/uhvm-6sct/rows.csv?accessType=DOWNLOAD
- **Publisher:** NYC ACS, via NYC Open Data
- **Pulled:** 2026-05-25

## Coverage

- Fiscal years FY2022–FY2025 (NYC FY runs July–June).
- Children and parents reported separately.
- Demographics: Race/Ethnicity, Gender, Language, Borough & Community District of the Family.
- 9 outcome counts per row: SCR intakes, Indicated Investigations, Unsubstantiated Investigations, CARES Cases, ACS Referral to Prevention, Emergency Removals, Article X Filings, Remands at Initial Hearings, Article X Foster Care Entries.

## Schema (raw)

| Column | Type | Notes |
|---|---|---|
| `Report Period` | text | e.g. `FY2022`, `FY2023`, ... |
| `Child/Parent` | text | `Children` or `Parents` |
| `Category` | text | `Race/Ethnicity`, `Gender`, `Language`, `Borough and Community District of the Family` |
| `Sub-category` | text | e.g. `Hispanic/Latinx`, `BX01 Mott Haven/ Melrose` |
| `SCR intakes` ... `Article X Foster Care Entries` | numeric (with `^` for suppressed cells) | 9 outcome columns |

## Notes

- Cells marked `^` indicate **suppressed counts** (small-cell suppression — typically n ≤ 5). They are read as missing in the analysis.
- Counts are at the demographic-group level, not case-level. This dataset supports rate comparisons, trend analysis, and disparity audits — not case-level prediction.
- This file is safe to commit (public dataset, no PII). It does **not** live in `data/raw/` because that path is reserved for restricted NDACAN files; this is public NYC open data.

## Why this is in the repo

The simulated dataset in `data/acs_*.csv` was modeled on this kind of NYC ACS pipeline. Now that this real dataset is here, results computed on it live in [`results/real_data/`](../../results/real_data/).
