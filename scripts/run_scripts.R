# Master script to source all pipeline scripts in order and verify outputs

# 0) (Optional) Set working directory to project root if not already set
# setwd("C:/path/to/nyc-rat-abundance")

# 1) List of scripts to run
scripts <- c(
  "scripts/000_setup_cmdstanr.R",
  "scripts/011_data_prep.R",
  "scripts/012_data_prep_derivation.R",
  "scripts/021_acs_fetch.R",
  "scripts/022_spatial_join.R",
  "scripts/023_income_scatter.R",
  "scripts/024_bg_acs_join.R"
)

# 2) Source each script in turn
for (s in scripts) {
  message("🔄 Running ", s, " …")
  source(s, echo = TRUE)
}

# 3) Verify that all expected output files exist
outs <- c(
  "data/processed/rats_ready.csv",
  "data/processed/borough_rates.csv",
  "data/raw/ACS.csv",
  "outputs/rat_clean.geojson",
  "outputs/income_scatter.csv",
  "outputs/rat_with_bg_ACS_point.csv",
  "outputs/bg_calls_ACS_summary.csv"
)
missing <- outs[!file.exists(outs)]
if (length(missing) > 0) stop("❌ Missing outputs: ", paste(missing, collapse = ", "))
message("🎉 All scripts ran successfully and outputs are in place!")
