"""
Real-data analysis on NYC ACS Local Law 132 demographics
(data/nyc_acs_real/local_law_132_demographics.csv).

This is real, publicly reported NYC ACS pipeline data, not simulated.
It is aggregate (counts by demographic group x fiscal year), so the
analysis is descriptive + comparative, not case-level classification.

Outputs:
  results/real_data/tables/      - CSV tables
  results/real_data/figures/     - PNG plots
  results/real_data/summary.json - headline numbers
"""
from __future__ import annotations
import json
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

ROOT = Path(__file__).resolve().parents[1]
SRC  = ROOT / "data" / "nyc_acs_real" / "local_law_132_demographics.csv"
OUT  = ROOT / "results"
TAB  = OUT / "tables"
FIG  = OUT / "figures"
for p in (OUT, TAB, FIG): p.mkdir(parents=True, exist_ok=True)

# ---------- 1. Load + clean ----------
raw = pd.read_csv(SRC)
# Normalize column names
raw.columns = [c.strip() for c in raw.columns]
# Outcome columns
OUTCOMES = [
    "SCR intakes", "Indicated Investigations", "Unsubstantiated Investigations",
    "CARES Cases", "ACS Referral to Prevention", "Emergency Removals",
    "Article X Filings", "Remands at Initial Hearings",
    "Article X Foster Care Entries",
]
# '^' marks suppressed cells; convert to NaN, coerce numeric.
for c in OUTCOMES:
    raw[c] = pd.to_numeric(raw[c].astype(str).str.replace(",", "")
                                              .replace("^", np.nan), errors="coerce")
# Tidy demographic columns
raw["report_period"] = raw["Report Period"].str.strip()
raw["who"]           = raw["Child/Parent"].str.strip()
raw["category"]      = raw["Category"].str.strip()
raw["subcategory"]   = raw["Sub-category"].str.strip()
raw["fy"]            = raw["report_period"].str.extract(r"FY(\d{4})").astype(int)

print(f"[load] {len(raw)} rows | FYs: {sorted(raw['fy'].unique())} "
      f"| who: {raw['who'].unique().tolist()}")

# ---------- 2. City-wide pipeline funnel ----------
city = (raw.query("category == 'Race/Ethnicity' and who == 'Children'")
           .groupby("fy")[OUTCOMES].sum())
# Funnel rates per SCR intake
funnel = pd.DataFrame({
    "scr_intakes":              city["SCR intakes"],
    "indication_rate":          city["Indicated Investigations"]   / city["SCR intakes"],
    "unsubstantiated_rate":     city["Unsubstantiated Investigations"] / city["SCR intakes"],
    "cares_rate":               city["CARES Cases"]                / city["SCR intakes"],
    "prevention_referral_rate": city["ACS Referral to Prevention"] / city["SCR intakes"],
    "emergency_removal_rate":   city["Emergency Removals"]         / city["SCR intakes"],
    "foster_entry_rate":        city["Article X Foster Care Entries"] / city["SCR intakes"],
})
funnel = funnel.round(4)
funnel.to_csv(TAB / "01_citywide_funnel_rates.csv")
print("[funnel city]\n", funnel)

# ---------- 3. Race/ethnicity disparities (children) ----------
race = (raw.query("category == 'Race/Ethnicity' and who == 'Children'")
           .copy())
race["indication_rate"]  = race["Indicated Investigations"]   / race["SCR intakes"]
race["removal_rate"]     = race["Emergency Removals"]         / race["SCR intakes"]
race["foster_entry_rate"] = race["Article X Foster Care Entries"] / race["SCR intakes"]

race_share = (race.groupby(["fy", "subcategory"])["SCR intakes"].sum()
                 .unstack("subcategory"))
race_share_pct = race_share.div(race_share.sum(axis=1), axis=0).round(3)
race_share_pct.to_csv(TAB / "02_race_share_of_scr_intakes.csv")

race_rates = (race.pivot_table(index="subcategory", columns="fy",
                               values="indication_rate", aggfunc="mean")
                  .round(3))
race_rates.to_csv(TAB / "03_race_indication_rate_by_fy.csv")
print("[race indication rate]\n", race_rates)

race_removal = (race.pivot_table(index="subcategory", columns="fy",
                                 values="removal_rate", aggfunc="mean")
                    .round(4))
race_removal.to_csv(TAB / "04_race_removal_rate_by_fy.csv")

# Disproportionality index: group's share of intakes / share of system outcomes
# Compared against share of NYC child population would need an external denominator;
# here we report intake share vs share of indicated investigations -- if the system
# is unbiased *after* an intake, those should be equal.
disp = (race.groupby("subcategory")
              .agg(scr=("SCR intakes","sum"),
                   ind=("Indicated Investigations","sum"),
                   rem=("Emergency Removals","sum"),
                   fce=("Article X Foster Care Entries","sum")))
disp["scr_share"] = disp["scr"] / disp["scr"].sum()
disp["ind_share"] = disp["ind"] / disp["ind"].sum()
disp["rem_share"] = disp["rem"] / disp["rem"].sum()
disp["fce_share"] = disp["fce"] / disp["fce"].sum()
disp["ind_per_intake_pct"] = (disp["ind"] / disp["scr"] * 100).round(1)
disp["rem_per_intake_pct"] = (disp["rem"] / disp["scr"] * 100).round(2)
disp["fce_per_intake_pct"] = (disp["fce"] / disp["scr"] * 100).round(2)
disp.round(4).to_csv(TAB / "05_race_disproportionality.csv")

# ---------- 4. Borough variation ----------
# Borough rows are tagged "Family" (counts are at family level for geographic
# breakdowns), not Children/Parents.
boro = raw.query("category == 'Borough and Community District of the Family' "
                 "and who == 'Family'").copy()
def borough_from_sub(s: str) -> str:
    if s.startswith("BX"): return "Bronx"
    if s.startswith("BK"): return "Brooklyn"
    if s.startswith("MN"): return "Manhattan"
    if s.startswith("QN"): return "Queens"
    if s.startswith("SI"): return "Staten Island"
    if s.startswith("Bronx"): return "Bronx"
    if s.startswith("Brooklyn"): return "Brooklyn"
    if s.startswith("Manhattan"): return "Manhattan"
    if s.startswith("Queens"): return "Queens"
    if s.startswith("Staten Island"): return "Staten Island"
    return "Outside NYC / Unknown"

boro["borough_name"] = boro["subcategory"].map(borough_from_sub)

boro_agg = (boro.groupby(["fy","borough_name"])[OUTCOMES].sum().reset_index())
boro_agg["indication_rate"]   = boro_agg["Indicated Investigations"]   / boro_agg["SCR intakes"]
boro_agg["foster_entry_rate"] = boro_agg["Article X Foster Care Entries"] / boro_agg["SCR intakes"]
boro_agg["removal_rate"]      = boro_agg["Emergency Removals"]         / boro_agg["SCR intakes"]
boro_agg.round(4).to_csv(TAB / "06_borough_rates_by_fy.csv", index=False)

# ---------- 5. Children vs Parents ----------
cp = (raw.query("category == 'Race/Ethnicity'")
         .groupby(["fy","who"])[OUTCOMES].sum())
cp_ratios = cp.copy()
for col in OUTCOMES:
    cp_ratios[col] = cp[col]
cp_ratios.round(0).to_csv(TAB / "07_children_vs_parents_totals.csv")

# ---------- 6. Plots ----------
sns.set_style("whitegrid")

# A. Citywide funnel
fig, ax = plt.subplots(figsize=(8, 4))
funnel_plot = funnel.drop(columns=["scr_intakes"]).T * 100
funnel_plot.plot(kind="bar", ax=ax, width=0.8)
ax.set(ylabel="% of SCR intakes", xlabel=None,
       title="NYC ACS child-welfare pipeline rates by fiscal year")
ax.legend(title="FY", fontsize=8)
plt.xticks(rotation=30, ha="right")
plt.tight_layout(); plt.savefig(FIG / "fig01_citywide_funnel.png", dpi=140); plt.close()

# B. Race intake share over time
fig, ax = plt.subplots(figsize=(8, 4))
race_share_pct.mul(100).plot(kind="bar", stacked=True, ax=ax,
                              colormap="tab20", edgecolor="white")
ax.set(ylabel="% of total SCR intakes", xlabel="Fiscal year",
       title="Race/ethnicity share of NYC SCR intakes (children)")
ax.legend(fontsize=7, bbox_to_anchor=(1.02, 1), loc="upper left")
plt.xticks(rotation=0); plt.tight_layout()
plt.savefig(FIG / "fig02_race_share_of_intakes.png", dpi=140); plt.close()

# C. Indication rate by race over time
fig, ax = plt.subplots(figsize=(8, 4))
for g in race_rates.index:
    ax.plot(race_rates.columns.astype(int), race_rates.loc[g] * 100,
            marker="o", label=g)
ax.set(ylabel="Indication rate (%)", xlabel="Fiscal year",
       title="Indication rate per SCR intake — children, by race/ethnicity")
ax.legend(fontsize=8, bbox_to_anchor=(1.02, 1), loc="upper left")
ax.set_xticks(race_rates.columns.astype(int))
plt.tight_layout(); plt.savefig(FIG / "fig03_indication_rate_by_race.png",
                                dpi=140); plt.close()

# D. Removal rate by race over time
fig, ax = plt.subplots(figsize=(8, 4))
for g in race_removal.index:
    ax.plot(race_removal.columns.astype(int), race_removal.loc[g] * 100,
            marker="o", label=g)
ax.set(ylabel="Emergency removal rate per intake (%)", xlabel="Fiscal year",
       title="Emergency removal rate — children, by race/ethnicity")
ax.legend(fontsize=8, bbox_to_anchor=(1.02, 1), loc="upper left")
ax.set_xticks(race_removal.columns.astype(int))
plt.tight_layout(); plt.savefig(FIG / "fig04_removal_rate_by_race.png",
                                dpi=140); plt.close()

# E. Disproportionality bar chart
fig, ax = plt.subplots(figsize=(8, 4))
d2 = disp.sort_values("scr_share", ascending=True)
xpos = np.arange(len(d2)); w = 0.28
ax.barh(xpos - w, d2["scr_share"]*100,    height=w, label="SCR intakes")
ax.barh(xpos,     d2["ind_share"]*100,    height=w, label="Indicated")
ax.barh(xpos + w, d2["fce_share"]*100,    height=w, label="Foster care entries")
ax.set_yticks(xpos); ax.set_yticklabels(d2.index)
ax.set(xlabel="% of citywide totals (FY2022–FY2025 pooled)",
       title="Share of NYC child welfare system by race/ethnicity")
ax.legend(fontsize=8)
plt.tight_layout(); plt.savefig(FIG / "fig05_race_disproportionality.png",
                                dpi=140); plt.close()

# F. Borough rates
fig, ax = plt.subplots(figsize=(8, 4))
piv = boro_agg.pivot(index="borough_name", columns="fy",
                     values="indication_rate") * 100
piv = piv.loc[[b for b in
               ["Bronx","Brooklyn","Manhattan","Queens","Staten Island","Other/Unknown"]
               if b in piv.index]]
piv.plot(kind="bar", ax=ax)
ax.set(ylabel="Indication rate (%)", xlabel=None,
       title="Indication rate per SCR intake by borough")
ax.legend(title="FY", fontsize=8)
plt.xticks(rotation=20)
plt.tight_layout(); plt.savefig(FIG / "fig06_indication_rate_by_borough.png",
                                dpi=140); plt.close()

# ---------- 7. Headline summary ----------
latest_fy = int(max(race_rates.columns))
summary = {
    "source": "NYC Open Data uhvm-6sct (Local Law 132 of 2022)",
    "fiscal_years": [int(x) for x in sorted(raw["fy"].unique())],
    "citywide_scr_intakes_by_fy": {
        int(fy): int(v) for fy, v in city["SCR intakes"].items()
    },
    "citywide_indication_rate_by_fy": {
        int(fy): round(float(v), 4)
        for fy, v in funnel["indication_rate"].items()
    },
    "citywide_emergency_removal_rate_by_fy": {
        int(fy): round(float(v), 4)
        for fy, v in funnel["emergency_removal_rate"].items()
    },
    "race_indication_rate_latest": {
        g: round(float(race_rates.loc[g, latest_fy]), 4)
        for g in race_rates.index
        if pd.notna(race_rates.loc[g, latest_fy])
    },
    "race_disproportionality_share_scr_vs_indicated": {
        g: {"scr_share":  round(float(disp.loc[g, "scr_share"]), 3),
            "ind_share":  round(float(disp.loc[g, "ind_share"]), 3),
            "fce_share":  round(float(disp.loc[g, "fce_share"]), 3)}
        for g in disp.index
    },
}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2))
print("[done] wrote", OUT)
