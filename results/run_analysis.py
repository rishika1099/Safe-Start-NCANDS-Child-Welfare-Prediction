"""
Run end-to-end simulated-data analysis and write artifacts to results/.

This script intentionally mirrors the workflow in notebooks/Module_03 - Module_06:
  1. Load + describe the simulated SCR data
  2. Engineer features + handle missingness
  3. Train regularized logistic regression + random forest + gradient boosting
     with group-aware CV at the family level
  4. Sweep operating thresholds, pick by F2
  5. Fairness audit: subgroup metrics by borough and race/ethnicity
  6. SHAP global importance on the gradient-boosting model
  7. Save tables (CSV) + figures (PNG) under results/
"""
from __future__ import annotations
import json
import warnings
from pathlib import Path

import numpy as np
import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns
import shap
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.impute import SimpleImputer
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (
    average_precision_score,
    brier_score_loss,
    confusion_matrix,
    fbeta_score,
    precision_score,
    recall_score,
    roc_auc_score,
)
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder

warnings.filterwarnings("ignore", category=UserWarning)

# ---------- Paths ----------
ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "data"
OUT = ROOT / "results"
FIG = OUT / "figures"
TAB = OUT / "tables"
for p in (OUT, FIG, TAB):
    p.mkdir(parents=True, exist_ok=True)

SEED = 20260525
rng = np.random.default_rng(SEED)

# ---------- Load ----------
scr = pd.read_csv(DATA / "acs_scr_reports.csv", parse_dates=["report_date"])
feat = pd.read_csv(DATA / "acs_features.csv")

# Merge intake context onto features (avoid duplicate suffixed cols).
scr_cols = ["report_id", "family_id", "borough", "child_race_ethnicity",
            "reporter_type", "allegation_type", "report_date", "outcome"]
df = feat.merge(scr[scr_cols], on=["report_id", "family_id"], how="inner")
print(f"[load] rows={len(df)}  cols={df.shape[1]}")

# ---------- 1. Descriptive ----------
descriptive = {
    "n_reports": int(len(df)),
    "n_families": int(df["family_id"].nunique()),
    "date_min": str(df["report_date"].min().date()),
    "date_max": str(df["report_date"].max().date()),
    "positive_rate": float(df["needs_investigative_consultation"].mean()),
    "substantiated_rate": float((df["outcome"] == "Substantiated").mean()),
}
print(f"[descriptive] {descriptive}")

# Missingness profile
miss = (df.isna().mean().sort_values(ascending=False) * 100).round(2)
miss = miss[miss > 0].to_frame("missing_pct")
miss.index.name = "feature"
miss.to_csv(TAB / "01_missingness.csv")
print(f"[missingness] {len(miss)} cols with NA")

# Volume by borough
df.groupby("borough").size().rename("n_reports").to_csv(TAB / "02_volume_by_borough.csv")

# Substantiation by reporter type
rep_stats = (
    df.assign(is_sub=(df["outcome"] == "Substantiated").astype(int))
    .groupby("reporter_type")
    .agg(n=("is_sub", "size"), substantiation_rate=("is_sub", "mean"))
    .sort_values("n", ascending=False)
    .round(3)
)
rep_stats.to_csv(TAB / "03_reporter_substantiation.csv")

# ---------- 2. Feature engineering / encoding ----------
NUMERIC = [
    "prior_reports_12mo", "prior_substantiated_flag", "days_since_last_report",
    "child_age_under_5", "dv_history_flag", "substance_use_flag",
    "shelter_involvement_flag", "days_to_first_contact",
    "reporter_accuracy_score", "caseworker_caseload",
]
CATEGORICAL = ["borough", "child_race_ethnicity", "reporter_type", "allegation_type"]
TARGET = "needs_investigative_consultation"
GROUP = "family_id"

# Missing-indicator columns for features with informative missingness
for col in ["days_since_last_report", "substance_use_flag", "days_to_first_contact"]:
    df[f"{col}_missing"] = df[col].isna().astype(int)
NUMERIC_PLUS = NUMERIC + [
    "days_since_last_report_missing",
    "substance_use_flag_missing",
    "days_to_first_contact_missing",
]

X = df[NUMERIC_PLUS + CATEGORICAL].copy()
y = df[TARGET].astype(int).values
groups = df[GROUP].values

pre = ColumnTransformer(
    [
        ("num", SimpleImputer(strategy="median"), NUMERIC_PLUS),
        ("cat", Pipeline([
            ("imp", SimpleImputer(strategy="most_frequent")),
            ("oh",  OneHotEncoder(handle_unknown="ignore", sparse_output=False)),
        ]), CATEGORICAL),
    ],
    remainder="drop",
)

# ---------- 3. Models + group-aware CV ----------
MODELS = {
    "logistic_l2": LogisticRegression(
        max_iter=2000, C=1.0, class_weight="balanced", random_state=SEED),
    "random_forest": RandomForestClassifier(
        n_estimators=400, min_samples_leaf=3, n_jobs=-1,
        class_weight="balanced_subsample", random_state=SEED),
    "gradient_boosting": GradientBoostingClassifier(
        n_estimators=300, max_depth=3, learning_rate=0.05, random_state=SEED),
}

gkf = GroupKFold(n_splits=5)
oof_proba = {name: np.zeros(len(y), dtype=float) for name in MODELS}
fold_metrics = []

for fold, (tr, va) in enumerate(gkf.split(X, y, groups=groups)):
    for name, clf in MODELS.items():
        pipe = Pipeline([("pre", pre), ("clf", clf)])
        pipe.fit(X.iloc[tr], y[tr])
        p = pipe.predict_proba(X.iloc[va])[:, 1]
        oof_proba[name][va] = p
        fold_metrics.append({
            "fold": fold,
            "model": name,
            "roc_auc": roc_auc_score(y[va], p),
            "pr_auc":  average_precision_score(y[va], p),
            "brier":   brier_score_loss(y[va], p),
        })

fold_df = pd.DataFrame(fold_metrics)
fold_df.to_csv(TAB / "04_cv_fold_metrics.csv", index=False)

cv_summary = (fold_df.groupby("model")
              .agg(["mean", "std"])
              .round(4))
cv_summary.to_csv(TAB / "05_cv_summary.csv")
print("[cv]\n", cv_summary)

# ---------- 4. Threshold sweep on the OOF probs of the best model ----------
best_model = cv_summary[("pr_auc", "mean")].idxmax()
print(f"[best] {best_model}")
p_best = oof_proba[best_model]

thr_grid = np.arange(0.05, 0.91, 0.025)
rows = []
for t in thr_grid:
    yhat = (p_best >= t).astype(int)
    rows.append({
        "threshold": round(float(t), 3),
        "flag_rate":  float(yhat.mean()),
        "precision":  precision_score(y, yhat, zero_division=0),
        "recall":     recall_score(y, yhat, zero_division=0),
        "f2":         fbeta_score(y, yhat, beta=2, zero_division=0),
    })
thr_df = pd.DataFrame(rows)
thr_df.to_csv(TAB / "06_threshold_sweep.csv", index=False)
best_t_f2 = float(thr_df.loc[thr_df["f2"].idxmax(), "threshold"])
print(f"[threshold] unconstrained F2-max at t={best_t_f2} "
      f"(flag_rate={thr_df.loc[thr_df['f2'].idxmax(),'flag_rate']:.2f})")

# Operational threshold: flag the top-K% of cases that matches base rate.
# This is the realistic constraint -- caseworkers can only investigate so many.
TARGET_FLAG_RATE = float(np.mean(y))  # match prevalence (~25%)
best_t = float(np.quantile(p_best, 1 - TARGET_FLAG_RATE))
op_row = {
    "threshold":   best_t,
    "flag_rate":   float((p_best >= best_t).mean()),
    "precision":   precision_score(y, (p_best >= best_t).astype(int), zero_division=0),
    "recall":      recall_score(y, (p_best >= best_t).astype(int), zero_division=0),
    "f2":          fbeta_score(y, (p_best >= best_t).astype(int), beta=2, zero_division=0),
}
print(f"[threshold] operational top-{TARGET_FLAG_RATE:.0%} cutoff at t={best_t:.3f} "
      f"-> precision={op_row['precision']:.3f}, recall={op_row['recall']:.3f}")
pd.DataFrame([op_row]).to_csv(TAB / "06b_operational_threshold.csv", index=False)

# ---------- 5. Fairness ----------
yhat_best = (p_best >= best_t).astype(int)

def subgroup_metrics(group_col: str) -> pd.DataFrame:
    tmp = pd.DataFrame({
        "y": y, "p": p_best, "yhat": yhat_best, "g": df[group_col].values,
    })
    out = []
    for g, sub in tmp.groupby("g"):
        if len(sub) < 10:
            continue
        cm = confusion_matrix(sub["y"], sub["yhat"], labels=[0, 1])
        tn, fp, fn, tp = cm.ravel()
        out.append({
            group_col: g,
            "n": int(len(sub)),
            "positive_rate": float(sub["y"].mean()),
            "flag_rate":     float(sub["yhat"].mean()),
            "precision":     tp / (tp + fp) if (tp + fp) else np.nan,
            "recall":        tp / (tp + fn) if (tp + fn) else np.nan,
            "fpr":           fp / (fp + tn) if (fp + tn) else np.nan,
            "roc_auc":       roc_auc_score(sub["y"], sub["p"])
                              if sub["y"].nunique() > 1 else np.nan,
        })
    return pd.DataFrame(out).sort_values(group_col)

fair_borough = subgroup_metrics("borough")
fair_race    = subgroup_metrics("child_race_ethnicity")
fair_borough.to_csv(TAB / "07_fairness_borough.csv", index=False)
fair_race.to_csv(   TAB / "08_fairness_race.csv",    index=False)

# ---------- 6. SHAP (on gradient boosting) ----------
gb_pipe = Pipeline([("pre", pre), ("clf", MODELS["gradient_boosting"])])
gb_pipe.fit(X, y)
X_enc = gb_pipe.named_steps["pre"].transform(X)
feat_names = gb_pipe.named_steps["pre"].get_feature_names_out()
explainer = shap.TreeExplainer(gb_pipe.named_steps["clf"])
# Sample for speed
sample_idx = rng.choice(len(X_enc), size=min(500, len(X_enc)), replace=False)
shap_values = explainer.shap_values(X_enc[sample_idx])

mean_abs = np.abs(shap_values).mean(axis=0)
shap_imp = (pd.DataFrame({"feature": feat_names, "mean_abs_shap": mean_abs})
            .sort_values("mean_abs_shap", ascending=False))
shap_imp.to_csv(TAB / "09_shap_importance.csv", index=False)

# ---------- 7. Plots ----------
sns.set_style("whitegrid")

# A. Monthly trend
fig, ax = plt.subplots(figsize=(7, 3.5))
(df.assign(ym=df["report_date"].dt.to_period("M").dt.to_timestamp())
   .groupby("ym").size().plot(ax=ax))
ax.set(xlabel=None, ylabel="Reports / month",
       title="Simulated SCR volume — monthly")
plt.tight_layout(); plt.savefig(FIG / "fig01_volume_trend.png", dpi=140); plt.close()

# B. Borough × allegation heatmap
piv = (df.assign(is_sub=(df["outcome"] == "Substantiated").astype(int))
         .pivot_table(index="allegation_type", columns="borough",
                      values="is_sub", aggfunc="mean"))
fig, ax = plt.subplots(figsize=(7, 3.5))
sns.heatmap(piv * 100, annot=True, fmt=".0f", cmap="Blues",
            cbar_kws={"label": "Substantiation %"}, ax=ax)
ax.set_title("Substantiation rate (%) — borough × allegation")
plt.tight_layout(); plt.savefig(FIG / "fig02_borough_allegation_heatmap.png",
                                dpi=140); plt.close()

# C. Threshold sweep
fig, ax = plt.subplots(figsize=(7, 3.5))
ax.plot(thr_df["threshold"], thr_df["recall"],    label="recall")
ax.plot(thr_df["threshold"], thr_df["precision"], label="precision")
ax.plot(thr_df["threshold"], thr_df["f2"],        label="F2", linestyle="--")
ax.axvline(best_t_f2, color="red",  linestyle=":",
           label=f"F2-max (unconstrained) t={best_t_f2}")
ax.axvline(best_t,    color="black", linestyle="--",
           label=f"operational top-25% t={best_t:.3f}")
ax.set(xlabel="Threshold", ylabel="Score",
       title=f"Threshold sweep — {best_model}")
ax.legend()
plt.tight_layout(); plt.savefig(FIG / "fig03_threshold_sweep.png",
                                dpi=140); plt.close()

# D. ROC / PR
from sklearn.metrics import roc_curve, precision_recall_curve
fig, axes = plt.subplots(1, 2, figsize=(10, 3.8))
for name, p in oof_proba.items():
    fpr, tpr, _ = roc_curve(y, p)
    axes[0].plot(fpr, tpr,
                 label=f"{name} (AUC={roc_auc_score(y,p):.3f})")
    pr, rc, _ = precision_recall_curve(y, p)
    axes[1].plot(rc, pr,
                 label=f"{name} (AP={average_precision_score(y,p):.3f})")
axes[0].plot([0,1],[0,1], "--", color="gray")
axes[0].set(title="ROC", xlabel="FPR", ylabel="TPR")
axes[1].set(title="Precision–Recall", xlabel="Recall", ylabel="Precision")
for a in axes: a.legend(fontsize=8)
plt.tight_layout(); plt.savefig(FIG / "fig04_roc_pr.png",
                                dpi=140); plt.close()

# E. Fairness — FPR / Recall by borough
fig, axes = plt.subplots(1, 2, figsize=(10, 3.5))
sns.barplot(data=fair_borough, x="borough", y="fpr",    ax=axes[0])
axes[0].set_title("FPR by borough (at chosen threshold)")
sns.barplot(data=fair_borough, x="borough", y="recall", ax=axes[1])
axes[1].set_title("Recall by borough (at chosen threshold)")
for a in axes: a.tick_params(axis="x", rotation=30)
plt.tight_layout(); plt.savefig(FIG / "fig05_fairness_borough.png",
                                dpi=140); plt.close()

# F. SHAP top-15
top = shap_imp.head(15)[::-1]
fig, ax = plt.subplots(figsize=(7, 4.5))
ax.barh(top["feature"], top["mean_abs_shap"], color="#4472C4")
ax.set(xlabel="mean(|SHAP|)", title="Top-15 global feature importance (SHAP)")
plt.tight_layout(); plt.savefig(FIG / "fig06_shap_top15.png",
                                dpi=140); plt.close()

# ---------- 8. Manifest ----------
summary = {
    "descriptive": descriptive,
    "best_model": best_model,
    "f2_max_threshold_unconstrained": best_t_f2,
    "operational_threshold_top25pct": best_t,
    "operational_precision": op_row["precision"],
    "operational_recall": op_row["recall"],
    "operational_flag_rate": op_row["flag_rate"],
    "cv_pr_auc_mean": float(cv_summary.loc[best_model, ("pr_auc", "mean")]),
    "cv_roc_auc_mean": float(cv_summary.loc[best_model, ("roc_auc", "mean")]),
    "n_features_after_encoding": int(len(feat_names)),
    "n_subgroups_borough": int(len(fair_borough)),
    "n_subgroups_race": int(len(fair_race)),
}
(OUT / "summary.json").write_text(json.dumps(summary, indent=2))
print("[done] wrote", OUT)
