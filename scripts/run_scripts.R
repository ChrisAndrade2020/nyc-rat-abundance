# Master driver that runs the entire rat‑data pipeline **in order** and checks
# that every expected artefact is created. Handy for fresh environments or CI.
#
# Outline
# 0. (Optional) setwd() to the repo root.
# 1. Unzip raw archives.
# 2. Define the ordered vector of R scripts to source.
# 3. Loop through and `source()` each, echoing output.
# 4. Assert that the key CSV / GeoJSON files exist.
# ---------------------------------------------------------------------------

## 0) Working directory -------------------------------------------------------
# Uncomment and edit if you intend to run this outside the project root.
# setwd("C:/path/to/nyc-rat-abundance")

## 1) Uncompress raw archives -----------------------------------------------
raw_dir <- "data/raw"
# Unzip .zip archives
zip_files <- list.files(raw_dir, pattern = "\\.zip$", full.names = TRUE)
for (zf in zip_files) {
  target <- file.path(raw_dir, sub("\\.zip$", "", basename(zf)))
  if (!file.exists(target)) {
    message("⏳ Unzipping ", basename(zf))
    utils::unzip(zf, exdir = raw_dir)
  }
}
# Extract .7z archives (requires 7z CLI in PATH)
sevenz_files <- list.files(raw_dir, pattern = "\\.7z$", full.names = TRUE)
for (sf in sevenz_files) {
  target <- file.path(raw_dir, sub("\\.7z$", "", basename(sf)))
  if (!file.exists(target)) {
    message("⏳ Extracting ", basename(sf))
    system2("7z", args = c("x", paste0("-o", raw_dir), sf))
  }
}

## 2) Scripts to run (ordered) -------------------------------------------------
scripts <- c(
  "scripts/000_setup_cmdstanr.R",
  "scripts/011_data_prep.R",
  "scripts/012_data_prep_derivation.R",  # makes rats_ready + borough_rates
  "scripts/021_acs_fetch.R",             # BBL‑keyed ACS lookup
  "scripts/022_spatial_join.R",          # adds PLUTO & ACS to rat points
  "scripts/023_income_scatter.R",        # tract‑level scatter data
  "scripts/024_bg_acs_join.R"            # BG‑level join & summary
)

## 3) Run each script, stop on error -----------------------------------------
for (s in scripts) {
  message("🔄  Running ", s, " …")
  source(s, echo = TRUE)
}

## 4) Verify outputs exist -----------------------------------------------------
expected <- c(
  "data/processed/rats_ready.csv",
  "data/processed/borough_rates.csv",
  "data/processed/ACS.csv",
  "output/rats_enriched.geojson",
  "output/income_scatter.csv",
  "output/rat_with_bg_ACS_point.csv",
  "output/bg_calls_ACS_summary.csv"
)

missing <- expected[!file.exists(expected)]
if (length(missing) > 0) {
  stop("❌  Missing outputs: ", paste(missing, collapse = ", "))
}

message("🎉  All scripts ran successfully and outputs are in place!")
