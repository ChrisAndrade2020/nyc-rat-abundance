scripts <- c(
  "scripts/000_setup_cmdstanr.R",
  "scripts/011_data_prep.R",          # your cleaned->rats_ready + borough_rates
  "scripts/012_data_prep_derivation.R", # if you kept both steps separate
  "scripts/021_acs_fetch.R",
  "scripts/022_spatial_join.R",
  "scripts/023_income_scatter.R",
  "scripts/024_bg_acs_join.R"
)

for (s in scripts) {
  message("🔄 Running ", s, "…")
  source(s, echo = TRUE, max.deparse.length = Inf)
}
message("🎉 All scripts ran successfully!")
