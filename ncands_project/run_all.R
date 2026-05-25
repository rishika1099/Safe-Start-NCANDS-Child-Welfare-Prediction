# ============================================================
# run_all.R — orchestrator
# ------------------------------------------------------------
# Runs scripts 01–06 in order. Each script is responsible for
# its own no-op when prerequisites are missing.
# ============================================================

source(here::here("ncands_project", "_utils.R"))

scripts <- c(
  "01_load_ncands.R",
  "02_features.R",
  "03_model.R",
  "04_fairness.R",
  "05_explain.R",
  "06_causal_rdd.R"
)

for (s in scripts) {
  message("\n========== ", s, " ==========")
  source(here::here("ncands_project", s), local = new.env())
}

message("\nDone. Artifacts in ", PATHS$artifacts)
