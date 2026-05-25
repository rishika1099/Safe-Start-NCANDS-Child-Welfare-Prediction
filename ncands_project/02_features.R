# ============================================================
# 02_features.R
# ------------------------------------------------------------
# Engineer modeling features from the cleaned NCANDS Child File:
#   - prior-involvement counts at the child level
#   - temporal features (year, month, weekday, season)
#   - collapsed race/ethnicity for fairness disaggregation
#   - maltreatment-type indicators
# Output: data/processed/ncands_features.rds
# ============================================================

source(here::here("ncands_project", "_utils.R"))

input <- file.path(PATHS$processed, "ncands_child_clean.rds")
if (!file.exists(input)) {
  message("02_features.R: nothing to do (run 01_load_ncands.R first).")
  return(invisible(NULL))
}

suppressPackageStartupMessages({
  library(dplyr); library(lubridate); library(tidyr)
})

ncands <- readRDS(input)

# ---- Prior-involvement (within child) -------------------------------------
# Sort by report date within child, then compute rolling history features.
ncands <- ncands |>
  dplyr::arrange(child_id, report_date) |>
  dplyr::group_by(child_id) |>
  dplyr::mutate(
    report_seq               = dplyr::row_number(),
    prior_reports_total      = report_seq - 1L,
    prior_substantiated_total = cumsum(dplyr::lag(substantiated == "yes",
                                                  default = FALSE)),
    days_since_last_report   = as.numeric(report_date -
                                          dplyr::lag(report_date)),
    prior_report_12mo        = purrr::map_int(report_date, function(d) {
      sum(report_date >= (d - 365) & report_date < d, na.rm = TRUE)
    })
  ) |>
  dplyr::ungroup()

# ---- Temporal features ----------------------------------------------------
ncands <- ncands |>
  dplyr::mutate(
    report_year   = lubridate::year(report_date),
    report_month  = lubridate::month(report_date),
    report_wday   = lubridate::wday(report_date, label = FALSE),
    is_weekend    = report_wday %in% c(1, 7)
  )

# ---- Race / ethnicity collapse for fairness disaggregation ---------------
# NCANDS uses multiple binary indicators per race. We collapse to a single
# string label for subgroup reporting. Hispanic ethnicity (ChEthn==1)
# overrides race when present, following common analytic conventions.
race_cols <- intersect(
  c("race_ai", "race_as", "race_bl", "race_nh", "race_wh"),
  names(ncands)
)

if (length(race_cols)) {
  ncands <- ncands |>
    dplyr::rowwise() |>
    dplyr::mutate(
      n_races = sum(dplyr::c_across(dplyr::all_of(race_cols)) == 1,
                    na.rm = TRUE),
      race_group = dplyr::case_when(
        !is.na(ethnicity) & ethnicity == 1            ~ "Hispanic",
        n_races > 1                                   ~ "Multiracial",
        !is.na(race_bl) & race_bl == 1                ~ "Black",
        !is.na(race_wh) & race_wh == 1                ~ "White",
        !is.na(race_as) & race_as == 1                ~ "Asian",
        !is.na(race_ai) & race_ai == 1                ~ "AIAN",
        !is.na(race_nh) & race_nh == 1                ~ "NHPI",
        TRUE                                          ~ "Unknown"
      )
    ) |>
    dplyr::ungroup() |>
    dplyr::select(-n_races)
}

# ---- Maltreatment type indicators ----------------------------------------
mal_cols <- intersect(
  c("mal_type_1", "mal_type_2", "mal_type_3", "mal_type_4"),
  names(ncands)
)
if (length(mal_cols)) {
  ncands <- ncands |>
    dplyr::mutate(
      has_neglect    = rowSums(dplyr::across(dplyr::all_of(mal_cols),
                                             ~ .x == 2), na.rm = TRUE) > 0,
      has_physical   = rowSums(dplyr::across(dplyr::all_of(mal_cols),
                                             ~ .x == 1), na.rm = TRUE) > 0,
      has_sexual     = rowSums(dplyr::across(dplyr::all_of(mal_cols),
                                             ~ .x == 3), na.rm = TRUE) > 0,
      has_emotional  = rowSums(dplyr::across(dplyr::all_of(mal_cols),
                                             ~ .x == 4), na.rm = TRUE) > 0,
      n_mal_types    = rowSums(!is.na(dplyr::across(dplyr::all_of(mal_cols))))
    )
}

# ---- Final feature frame for modeling -------------------------------------
modeling <- ncands |>
  dplyr::transmute(
    child_id, report_id, state, report_year,
    substantiated,
    age, sex,
    prior_reports_total, prior_substantiated_total,
    prior_report_12mo,
    days_since_last_report,
    report_month, report_wday, is_weekend,
    race_group = dplyr::coalesce(race_group, "Unknown"),
    has_neglect, has_physical, has_sexual, has_emotional, n_mal_types,
    report_source
  )

out <- file.path(PATHS$processed, "ncands_features.rds")
saveRDS(modeling, out)
message("Wrote ", out, "  (", nrow(modeling), " rows, ",
        ncol(modeling), " cols)")
