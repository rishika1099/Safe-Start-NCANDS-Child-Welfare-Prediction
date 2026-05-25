# ============================================================
# 06_causal_rdd.R
# ------------------------------------------------------------
# Regression-discontinuity design at a risk-score threshold.
# Identifies the local causal effect of crossing the threshold
# (e.g. screen-in vs. screen-out) on a downstream outcome such
# as rereport within 12 months.
#
# This script is a TEMPLATE — the running variable, threshold,
# and outcome must be adapted to whichever state-year admin
# convention is observable in the NCANDS data you receive.
# Pre-register choices in docs/ before running on real data.
# ============================================================

source(here::here("ncands_project", "_utils.R"))

pred_path <- file.path(PATHS$artifacts, "preds_xgboost.rds")
if (!file.exists(pred_path)) {
  message("06_causal_rdd.R: nothing to do (run 03_model.R first).")
  return(invisible(NULL))
}

suppressPackageStartupMessages({
  library(dplyr); library(rdrobust)
})

preds <- readRDS(pred_path)

# ---- Construct outcome: 12-month rereport per child ----------------------
# Requires the cleaned NCANDS file with all reports per child_id.
ncands <- readRDS(file.path(PATHS$processed, "ncands_child_clean.rds"))

rereport <- ncands |>
  dplyr::arrange(child_id, report_date) |>
  dplyr::group_by(child_id) |>
  dplyr::mutate(
    next_report_date  = dplyr::lead(report_date),
    rereport_12mo     = !is.na(next_report_date) &
                        next_report_date - report_date <= 365
  ) |>
  dplyr::ungroup() |>
  dplyr::select(report_id, rereport_12mo)

rdd_df <- preds |>
  dplyr::inner_join(rereport, by = "report_id") |>
  dplyr::filter(!is.na(.pred_yes), !is.na(rereport_12mo))

# ---- Running variable: model risk score; cutoff at 0.5 (placeholder) -----
# In a real run, the cutoff should be either:
#   (a) a state-published screening threshold, or
#   (b) a calibrated operating threshold from 04_fairness.R.
cutoff <- 0.5
message(sprintf("RDD with running var = .pred_yes, cutoff = %.2f, n = %d.",
                cutoff, nrow(rdd_df)))

rdd_fit <- rdrobust::rdrobust(
  y = as.numeric(rdd_df$rereport_12mo),
  x = rdd_df$.pred_yes,
  c = cutoff
)
print(summary(rdd_fit))

# ---- Persist (aggregate-only) --------------------------------------------
ensure_dir(PATHS$artifacts)
saveRDS(rdd_fit, file.path(PATHS$artifacts, "rdd_fit.rds"))

readr::write_csv(
  tibble::tibble(
    estimator   = c("conventional", "bias_corrected", "robust"),
    coef        = rdd_fit$Estimate[1, ],
    se          = rdd_fit$Estimate[2, ],
    p_value     = 2 * (1 - pnorm(abs(rdd_fit$Estimate[1, ] /
                                     rdd_fit$Estimate[2, ])))
  ),
  file.path(PATHS$artifacts, "rdd_estimates.csv")
)
message("Wrote rdd_estimates.csv")
