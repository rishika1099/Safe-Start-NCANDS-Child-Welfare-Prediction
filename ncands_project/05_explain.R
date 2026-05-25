# ============================================================
# 05_explain.R
# ------------------------------------------------------------
# Aggregate-only SHAP analysis on the fitted XGBoost model:
#   - global SHAP importance (mean |value| per feature)
#   - SHAP-by-feature summary distributions
# Per-case waterfalls are intentionally NOT exported to disk.
# Any case-level explanation must remain in-memory.
# ============================================================

source(here::here("ncands_project", "_utils.R"))

model_path <- file.path(PATHS$artifacts, "model_xgboost.rds")
if (!file.exists(model_path)) {
  message("05_explain.R: nothing to do (run 03_model.R first).")
  return(invisible(NULL))
}

suppressPackageStartupMessages({
  library(dplyr); library(shapviz); library(xgboost)
})

xgb_wf  <- readRDS(model_path)
features <- readRDS(file.path(PATHS$processed, "ncands_features.rds"))

xgb_fit <- workflows::extract_fit_engine(xgb_wf)
rec     <- workflows::extract_recipe(xgb_wf)

# Prepare design matrix in the same way the model was trained.
baked <- recipes::bake(rec, new_data = features, composition = "matrix")
# Drop the outcome column from the matrix if recipe leaves it in.
y_col <- which(colnames(baked) %in% c("substantiated", "..y"))
if (length(y_col)) baked <- baked[, -y_col]

# Subsample for speed; SHAP scales linearly in rows.
n_sample <- min(20000, nrow(baked))
idx      <- sample.int(nrow(baked), n_sample)
shp      <- shapviz::shapviz(xgb_fit, X_pred = baked[idx, ],
                             X = baked[idx, ])

# ---- Global importance (mean |SHAP|) -------------------------------------
imp <- tibble::tibble(
  feature = colnames(shp$S),
  mean_abs_shap = colMeans(abs(shp$S))
) |>
  dplyr::arrange(dplyr::desc(mean_abs_shap))

ensure_dir(PATHS$artifacts)
readr::write_csv(imp,
                 file.path(PATHS$artifacts, "shap_importance.csv"))
saveRDS(shp, file.path(PATHS$artifacts, "shap_object.rds"))
message("Wrote shap_importance.csv (", nrow(imp), " features).")
