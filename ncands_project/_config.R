# ============================================================
# _config.R — paths, packages, NCANDS column dictionary
# ============================================================
# Sourced by every script in ncands_project/.
# Verify the NCANDS column mappings against the NDACAN codebook
# for your specific data year before publishing any results.
# ============================================================

# ---- Paths (relative to repo root; scripts call here::here()) ----
suppressPackageStartupMessages({
  if (!requireNamespace("here", quietly = TRUE)) install.packages("here")
  library(here)
})

PATHS <- list(
  raw       = here("data", "raw"),
  processed = here("data", "processed"),
  artifacts = here("data", "processed", "artifacts")
)

# Expected raw-file naming pattern (verify against your delivery).
# NDACAN typically ships NCANDS in SAS (.sas7bdat), SPSS, Stata, and ASCII.
RAW_FILES <- list(
  ncands_child   = "ncands_child_*.sas7bdat",    # NCANDS Child File
  ncands_agency  = "ncands_agency_*.sas7bdat",   # NCANDS Agency File
  scan_policies  = "scan_policies_*.csv"         # SCAN Policies Database
)

# ---- Required packages ----
REQUIRED_PKGS <- c(
  "tidyverse", "tidymodels", "ranger", "xgboost",
  "themis", "probably", "yardstick",
  "shapviz", "rdrobust", "MatchIt",
  "haven",   # for SAS .sas7bdat NCANDS files
  "readr", "lubridate"
)

# ---- NCANDS Child File column dictionary (starting point) ----
# NOTE: NCANDS variable names and codes change across release years.
# This dictionary covers the most stable core variables. Re-verify
# every entry against the codebook PDF that ships with your data.
NCANDS_COLS <- list(

  # Identifiers
  child_id          = "ChID",        # encrypted child identifier
  report_id         = "RptID",       # report identifier
  state             = "StaTerr",     # 2-char state/territory code

  # Dates
  report_date       = "RptDt",       # date report was received
  investigation_dt  = "InvDate",     # investigation start
  disposition_dt    = "RpDispDt",    # disposition reached

  # Disposition (the modeling target lives here)
  disposition       = "RptDisp",     # 1=substantiated, 2=indicated,
                                     # 3=unsubstantiated, 4=closed-no-finding,
                                     # 5=intentionally-false, ...

  # Child demographics
  age               = "ChAge",
  sex               = "ChSex",
  race_ai           = "ChRacAI",     # American Indian / Alaska Native
  race_as           = "ChRacAs",     # Asian
  race_bl           = "ChRacBl",     # Black / African American
  race_nh           = "ChRacNH",     # Native Hawaiian / Pacific Islander
  race_wh           = "ChRacWh",     # White
  ethnicity         = "ChEthn",      # 1=Hispanic, 2=non-Hispanic

  # Maltreatment
  mal_type_1        = "ChMal1",
  mal_type_2        = "ChMal2",
  mal_type_3        = "ChMal3",
  mal_type_4        = "ChMal4",

  # History
  prior_victim      = "ChPrior",     # prior victim indicator

  # Report context
  report_source     = "RpSrc",       # numeric source code

  # Services / placement (for downstream outcome work)
  services_date     = "ServDate",
  fc_date           = "FCDate"
)

# ---- Disposition recodes ----
DISP_SUBSTANTIATED  <- c(1, 2)   # substantiated + indicated treated as positive
DISP_NEGATIVE       <- c(3, 4)
DISP_DROP           <- c(5, 6, 7, 8, 9)  # excluded from training (varies by year — verify)

# ---- Modeling constants ----
SEED            <- 20260525
TARGET_NAME     <- "substantiated"
GROUP_COL       <- "child_id"     # group-aware CV at the child level
CV_FOLDS        <- 5
THRESHOLD_GRID  <- seq(0.05, 0.80, by = 0.05)

# ---- Minimum cell size for any published aggregate ----
MIN_CELL_N <- 11   # NDACAN suppression rule of thumb — verify with current TOU
