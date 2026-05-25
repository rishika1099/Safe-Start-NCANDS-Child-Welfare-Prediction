# ============================================================
# 04_fairness.R
# ------------------------------------------------------------
# Disaggregate model performance and operational error rates by
#   - race_group
#   - report_source
#   - state
# at a calibrated operating threshold. Applies NDACAN minimum-
# cell suppression (n < MIN_CELL_N) before writing artifacts.
# ============================================================

source(here::here("ncands_project", "_utils.R"))

pred_path <- file.path(PATHS$artifacts, "preds_xgboost.rds")
if (!file.exists(pred_path)) {
  message("04_fairness.R: nothing to do (run 03_model.R first).")
  return(invisible(NULL))
}

suppressPackageStartupMessages({
  library(dplyr); library(yardstick); library(probably)
})

preds <- readRDS(pred_path)

# ---- Pick operating threshold by maximizing F2 (recall-weighted) ---------
f2_at <- function(t, df) {
  yhat <- factor(ifelse(df$.pred_yes >= t, "yes", "no"),
                 levels = c("no", "yes"))
  yardstick::f_meas_vec(df$substantiated, yhat,
                        beta = 2, event_level = "second")
}
grid <- tibble::tibble(threshold = THRESHOLD_GRID,
                       f2 = vapply(THRESHOLD_GRID, f2_at, numeric(1),
                                   df = preds))
best_t <- grid$threshold[which.max(grid$f2)]
message(sprintf("Operating threshold: %.2f (F2=%.3f)",
                best_t, max(grid$f2)))

preds <- preds |>
  dplyr::mutate(flagged = factor(ifelse(.pred_yes >= best_t,
                                        "yes", "no"),
                                 levels = c("no", "yes")))

# ---- Subgroup metrics ----------------------------------------------------
group_metrics <- function(df, group) {
  df |>
    dplyr::group_by(.data[[group]]) |>
    dplyr::summarise(
      n            = dplyr::n(),
      positive_rate = mean(substantiated == "yes"),
      flag_rate     = mean(flagged       == "yes"),
      precision     = yardstick::precision_vec(substantiated, flagged,
                                               event_level = "second"),
      recall        = yardstick::recall_vec(substantiated, flagged,
                                            event_level = "second"),
      fpr           = mean(flagged == "yes" & substantiated == "no") /
                      mean(substantiated == "no"),
      roc_auc       = yardstick::roc_auc_vec(substantiated, .pred_yes,
                                             event_level = "second"),
      .groups = "drop"
    ) |>
    dplyr::rename(subgroup = !!group) |>
    dplyr::mutate(grouping = group, .before = subgroup) |>
    suppress_small_cells(n_col = "n",
                         value_cols = c("positive_rate", "flag_rate",
                                        "precision", "recall",
                                        "fpr", "roc_auc"))
}

ensure_dir(PATHS$artifacts)
fairness <- dplyr::bind_rows(
  if ("race_group"    %in% names(preds)) group_metrics(preds, "race_group"),
  if ("report_source" %in% names(preds)) group_metrics(preds, "report_source"),
  if ("state"         %in% names(preds)) group_metrics(preds, "state")
)

readr::write_csv(fairness,
                 file.path(PATHS$artifacts, "fairness_metrics.csv"))
saveRDS(list(threshold = best_t, table = fairness),
        file.path(PATHS$artifacts, "fairness.rds"))
message("Wrote fairness_metrics.csv (", nrow(fairness), " rows).")
