# ───────────────────────────────────────────────────────────
# Script: 032_generate_daily_counts.R
# Purpose: Aggregate enriched rat sightings into daily counts per community district
# Inputs:  output/rats_enriched.geojson
# Outputs: output/daily_rats_by_cd.csv
# Depends: sf, dplyr, lubridate, readr
# ───────────────────────────────────────────────────────────

# 1. Load spatial and data-wrangling libraries
library(sf)
library(dplyr)
library(lubridate)
library(readr)

# 2. Read enriched GeoJSON and drop spatial geometry
rats <- st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  st_drop_geometry()

# 3. Compute daily distinct-ticket counts by CD_ID
daily_cd <- rats %>%
  mutate(report_date = as_date(ymd_hms(created_dt))) %>%
  filter(!is.na(CD_ID)) %>%
  group_by(CD_ID, report_date) %>%
  summarise(calls = n_distinct(Unique.Key), .groups = "drop")

# 4. Write out the daily counts CSV
write_csv(daily_cd, "output/daily_rats_by_cd.csv")
message("Wrote daily counts to output/daily_rats_by_cd.csv")
