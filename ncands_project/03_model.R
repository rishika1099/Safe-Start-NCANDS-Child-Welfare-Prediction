# ============================================================
# 03_model.R
# ------------------------------------------------------------
# Train substantiation models with group-aware CV at the child
# level. Two model families compared: regularized logistic
# regression (glmnet) and XGBoost. Outputs are CV metrics and a
# fitted final workflow saved to data/processed/artifacts/.
# ============================================================

source(here::here("ncands_project", "_utils.R"))

input <- file.path(PATHS$processed, "ncands_features.rds")
if (!file.exists(input)) {
  message("03_model.R: nothing to do (run 02_features.R first).")
  return(invisible(NULL))
}

suppressPackageStartupMessages({
  library(tidymodels); library(glmnet); library(xgboost); library(themis)
})
set.seed(SEED)

features <- readRDS(input)
ensure_dir(PATHS$artifacts)

# ---- Initial split (group-aware) ------------------------------------------
# Hold out 20% of children for a never-seen test set.
child_ids   <- unique(features$child_id)
test_ids    <- sample(child_ids, size = floor(0.2 * length(child_ids)))
train_data  <- features |> dplyr::filter(!child_id %in% test_ids)
test_data   <- features |> dplyr::filter(child_id  %in% test_ids)

cv_folds <- make_group_cv(train_data, group = GROUP_COL, v = CV_FOLDS)

# ---- Recipe ---------------------------------------------------------------
rec <- recipes::recipe(substantiated ~ ., data = train_data) |>
  recipes::update_role(child_id, report_id, new_role = "ID") |>
  recipes::step_mutate(
    days_since_last_report_missing =
      as.integer(is.na(days_since_last_report))
  ) |>
  recipes::step_impute_median(recipes::all_numeric_predictors()) |>
  recipes::step_unknown(recipes::all_nominal_predictors()) |>
  recipes::step_dummy(recipes::all_nominal_predictors(), one_hot = FALSE) |>
  recipes::step_zv(recipes::all_predictors())

# ---- Model specs ----------------------------------------------------------
lr_spec <- parsnip::logistic_reg(penalty = tune::tune(), mixture = 1) |>
  parsnip::set_engine("glmnet") |>
  parsnip::set_mode("classification")

xgb_spec <- parsnip::boost_tree(
    trees       = 1000,
    tree_depth  = tune::tune(),
    learn_rate  = tune::tune(),
    min_n       = tune::tune()
  ) |>
  parsnip::set_engine("xgboost") |>
  parsnip::set_mode("classification")

# ---- Workflows ------------------------------------------------------------
lr_wf  <- workflows::workflow() |> workflows::add_recipe(rec) |>
          workflows::add_model(lr_spec)
xgb_wf <- workflows::workflow() |> workflows::add_recipe(rec) |>
          workflows::add_model(xgb_spec)

# ---- Tune ------------------------------------------------------------------
metric_set_cw <- yardstick::metric_set(yardstick::roc_auc,
                                       yardstick::pr_auc,
                                       yardstick::brier_class)

message("Tuning logistic regression …")
lr_res  <- tune::tune_grid(lr_wf,  resamples = cv_folds, grid = 10,
                           metrics = metric_set_cw)

message("Tuning XGBoost …")
xgb_res <- tune::tune_grid(xgb_wf, resamples = cv_folds, grid = 15,
                           metrics = metric_set_cw)

# ---- Pick best by AUC-PR (rare-event friendly) ----------------------------
lr_best  <- tune::select_best(lr_res,  metric = "pr_auc")
xgb_best <- tune::select_best(xgb_res, metric = "pr_auc")

lr_final  <- tune::finalize_workflow(lr_wf,  lr_best)  |>
             parsnip::fit(data = train_data)
xgb_final <- tune::finalize_workflow(xgb_wf, xgb_best) |>
             parsnip::fit(data = train_data)

# ---- Test-set evaluation --------------------------------------------------
predict_with <- function(wf, data) {
  bind_cols(
    data,
    predict(wf, data, type = "prob"),
    predict(wf, data, type = "class")
  )
}
lr_pred  <- predict_with(lr_final,  test_data)
xgb_pred <- predict_with(xgb_final, test_data)

test_metrics <- dplyr::bind_rows(
  tibble::tibble(model = "logistic_lasso",
                 metrics = list(metric_set_cw(lr_pred,
                                  truth = substantiated,
                                  .pred_yes, estimate = .pred_class,
                                  event_level = "second"))),
  tibble::tibble(model = "xgboost",
                 metrics = list(metric_set_cw(xgb_pred,
                                  truth = substantiated,
                                  .pred_yes, estimate = .pred_class,
                                  event_level = "second")))
) |> tidyr::unnest(metrics)

# ---- Persist --------------------------------------------------------------
saveRDS(lr_final,  file.path(PATHS$artifacts, "model_logistic.rds"))
saveRDS(xgb_final, file.path(PATHS$artifacts, "model_xgboost.rds"))
saveRDS(lr_pred,   file.path(PATHS$artifacts, "preds_logistic.rds"))
saveRDS(xgb_pred,  file.path(PATHS$artifacts, "preds_xgboost.rds"))
readr::write_csv(test_metrics,
                 file.path(PATHS$artifacts, "test_metrics.csv"))

message("Done. Test metrics:")
print(test_metrics)
