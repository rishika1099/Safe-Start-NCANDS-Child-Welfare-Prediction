# ============================================================
# 01_load_ncands.R
# ------------------------------------------------------------
# Read the raw NCANDS Child File, project to the modeling
# schema in _config.R, and write a normalized parquet/RDS to
# data/processed/. No-op when data/raw/ is empty.
# ============================================================

source(here::here("ncands_project", "_utils.R"))

raw_files <- require_raw_data()
if (is.null(raw_files)) {
  message("01_load_ncands.R: nothing to do (no raw data present).")
  return(invisible(NULL))
}

suppressPackageStartupMessages({
  library(dplyr); library(readr); library(stringr); library(lubridate)
  library(haven)
})

ensure_dir(PATHS$processed)

# ---- Locate the NCANDS Child File ----------------------------------------
child_path <- raw_files[stringr::str_detect(basename(raw_files),
                                            "ncands.*child")]
if (length(child_path) == 0) {
  stop("01_load_ncands.R: no file matching 'ncands*child*' under ", PATHS$raw)
}
child_path <- child_path[[1]]
message("Reading NCANDS Child File: ", child_path)

# ---- Read by extension ----------------------------------------------------
read_any <- function(p) {
  ext <- tools::file_ext(p) |> tolower()
  switch(ext,
    "sas7bdat" = haven::read_sas(p),
    "sav"      = haven::read_sav(p),
    "dta"      = haven::read_dta(p),
    "csv"      = readr::read_csv(p, show_col_types = FALSE),
    "tsv"      = readr::read_tsv(p, show_col_types = FALSE),
    stop("Unsupported NCANDS extension: ", ext)
  )
}

ncands_raw <- read_any(child_path)
message("Rows: ", nrow(ncands_raw), "  Cols: ", ncol(ncands_raw))

# ---- Project to modeling schema ------------------------------------------
# Pull only the columns named in NCANDS_COLS; rename to friendly names.
present <- intersect(unlist(NCANDS_COLS), names(ncands_raw))
missing <- setdiff(unlist(NCANDS_COLS), names(ncands_raw))
if (length(missing)) {
  warning("Columns from _config.R not in file (year/version drift?): ",
          paste(missing, collapse = ", "))
}

rename_map <- setNames(present,
                       names(NCANDS_COLS)[match(present, NCANDS_COLS)])

ncands <- ncands_raw |>
  dplyr::select(dplyr::all_of(present)) |>
  dplyr::rename(!!!rename_map)

# ---- Light cleaning -------------------------------------------------------
parse_ncands_date <- function(x) {
  # NCANDS dates ship as character "YYYY-MM-DD" or numeric SAS dates.
  if (inherits(x, "Date"))                  return(x)
  if (is.numeric(x))                        return(as.Date(x, origin = "1960-01-01"))
  suppressWarnings(lubridate::ymd(as.character(x)))
}

date_cols <- intersect(
  c("report_date", "investigation_dt", "disposition_dt",
    "services_date", "fc_date"),
  names(ncands)
)
for (col in date_cols) ncands[[col]] <- parse_ncands_date(ncands[[col]])

# ---- Modeling target ------------------------------------------------------
ncands <- ncands |>
  dplyr::mutate(
    substantiated = dplyr::case_when(
      disposition %in% DISP_SUBSTANTIATED ~ "yes",
      disposition %in% DISP_NEGATIVE      ~ "no",
      TRUE                                ~ NA_character_
    ),
    substantiated = factor(substantiated, levels = c("no", "yes"))
  ) |>
  dplyr::filter(!is.na(substantiated))

message("After target filtering: ", nrow(ncands), " rows.")

# ---- Persist --------------------------------------------------------------
out_path <- file.path(PATHS$processed, "ncands_child_clean.rds")
saveRDS(ncands, out_path)
message("Wrote ", out_path)

invisible(ncands)
