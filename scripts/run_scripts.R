# ───────────────────────────────────────────────────────────
# Script: master_run_all.R
# Purpose: Run the entire NYC rat-data pipeline in order and verify all expected artefacts exist
# Inputs:  R scripts under scripts/ (000_setup_cmdstanr.R, 011_data_prep.R, …, 043_funnel.R)
# Outputs: data/processed/*.csv, output/*.csv & rats_enriched.geojson
# Depends: base R, dplyr, readr, tidyr
# ───────────────────────────────────────────────────────────

## 0) (Optional) Set working directory to repo root ----------------------------
# setwd("C:/path/to/nyc-rat-abundance")

## 1) Ordered vector of scripts to source ---------------------------------------
scripts <- c(
  # Batch 0 · Environment setup
  "scripts/000_setup_cmdstanr.R",
  
  # Batch 1 · Data ingest & cleaning
  "scripts/011_data_prep.R",
  "scripts/012_data_prep_derivation.R",
  "scripts/021_acs_fetch.R",
  "scripts/022_spatial_join.R",
  "scripts/024_bg_acs_join.R",
  
  # Batch 2 · Analysis & modelling outputs
  "scripts/023_income_scatter.R",
  "scripts/031_qhcr_model.R",
  "scripts/032_generate_daily_counts.R",
  "scripts/033_generate_quarterly_counts.R",
  "scripts/034_spike_inspection.R",
  "scripts/035_winsorize_daily_counts.R",
  "scripts/036_deciles.R",
  "scripts/041_rat_pop_est.R",
  "scripts/042_rat_pop_boro.R",
  "scripts/043_funnel.R"
)

## 2) Source each script, echoing code and stopping on error -------------------
for (s in scripts) {
  message("🔄  Running ", s, " …")
  source(s, echo = TRUE, max.deparse.length = 200)
}

## 3) Verify all expected artefacts exist --------------------------------------
expected <- c(
  # processed data
  "data/processed/rats_clean.csv",
  "data/processed/rats_ready.csv",
  "data/processed/borough_rates.csv",
  "data/processed/ACS.csv",
  
  # enriched and spatial outputs
  "output/rats_enriched.geojson",
  "output/rat_with_bg_ACS_point.csv",
  "output/bg_calls_ACS_summary.csv",
  
  # analysis tables
  "output/income_scatter.csv",
  "output/daily_rats_by_cd_win.csv",
  "output/quarterly_rats_by_cd.csv",
  "output/kpi_spike_summary.csv",
  "output/decile_call_rates_vfinal.csv",
  "output/citywide_call_rate_qtr.csv",
  
  # modelling & population estimates
  "output/qhcr_draws.rds",
  "output/district_qhcr_v2.csv",
  "output/yearly_rat_population.csv",
  "output/boro_yearly_rat_population.csv",
  
  # funnel analysis
  "output/rat_funnel.csv"
)

missing <- expected[!file.exists(expected)]
if (length(missing) > 0) {
  stop("❌ Missing outputs: ", paste(missing, collapse = ", "))
}

message("🎉 All scripts ran successfully and all expected artefacts are in place!")
