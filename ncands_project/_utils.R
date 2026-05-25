# ============================================================
# _utils.R — shared helpers
# ============================================================

source(here::here("ncands_project", "_config.R"))

# ---- Data presence guard --------------------------------------------------
# Scripts call require_raw_data() at the top. When data/raw/ is empty
# (the public-repo state) the script exits cleanly with a message.
require_raw_data <- function() {
  files <- list.files(PATHS$raw, pattern = "\\.(csv|sas7bdat|dat|tsv)$",
                      ignore.case = TRUE, full.names = TRUE)
  files <- files[!grepl("/\\.gitkeep$", files)]
  if (length(files) == 0) {
    message("[ncands_project] No NCANDS files found under ",
            PATHS$raw, ". Skipping — place restricted data there ",
            "and re-run. (See ../docs/NDACAN_NCANDS_Project_Plan.md.)")
    return(invisible(NULL))
  }
  files
}

require_processed <- function(name) {
  f <- file.path(PATHS$processed, name)
  if (!file.exists(f)) {
    stop("[ncands_project] Missing processed file: ", f,
         "\nRun the earlier numbered scripts first.")
  }
  f
}

ensure_dir <- function(p) {
  if (!dir.exists(p)) dir.create(p, recursive = TRUE)
  p
}

# ---- NDACAN suppression for aggregate tables ------------------------------
# Replaces counts/rates whose underlying n < MIN_CELL_N with NA so that
# no row of any published table reveals a small-cell value.
suppress_small_cells <- function(df, n_col = "n", value_cols = NULL,
                                 min_n = MIN_CELL_N) {
  stopifnot(n_col %in% names(df))
  cols <- value_cols %||% setdiff(names(df), n_col)
  mask <- df[[n_col]] < min_n
  if (any(mask)) {
    df[mask, cols] <- NA
    df[mask, n_col] <- NA
    message(sprintf("[suppress] %d row(s) suppressed (n < %d).",
                    sum(mask), min_n))
  }
  df
}

`%||%` <- function(a, b) if (is.null(a)) b else a

# ---- Group-aware CV split -------------------------------------------------
make_group_cv <- function(data, group = GROUP_COL, v = CV_FOLDS) {
  if (!group %in% names(data)) {
    stop("[ncands_project] Group column '", group, "' not in data.")
  }
  rsample::group_vfold_cv(data, group = !!rlang::sym(group), v = v)
}

# ---- Subgroup confusion-matrix metrics ------------------------------------
subgroup_metrics <- function(df, group, truth, pred_class, pred_prob) {
  df %>%
    dplyr::group_by(.data[[group]]) %>%
    dplyr::summarise(
      n            = dplyr::n(),
      positive_rate = mean(.data[[truth]] == "yes"),
      precision     = yardstick::precision_vec(
                        truth = factor(.data[[truth]]),
                        estimate = factor(.data[[pred_class]]),
                        event_level = "second"),
      recall        = yardstick::recall_vec(
                        truth = factor(.data[[truth]]),
                        estimate = factor(.data[[pred_class]]),
                        event_level = "second"),
      fpr           = mean(.data[[pred_class]] == "yes" & .data[[truth]] == "no"),
      roc_auc       = yardstick::roc_auc_vec(
                        truth = factor(.data[[truth]]),
                        estimate = .data[[pred_prob]],
                        event_level = "second"),
      .groups = "drop"
    )
}
