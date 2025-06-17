# ───────────────────────────────────────────────────────────
# Script: 033_generate_quarterly_counts.R
# Purpose: Aggregate enriched rat sightings into quarterly counts per community district
# Inputs:  output/rats_enriched.geojson
# Outputs: output/quarterly_rats_by_cd.csv
# Depends: sf, dplyr, lubridate, readr
# ───────────────────────────────────────────────────────────

# 1. Load spatial and data-wrangling libraries
library(sf)
library(dplyr)
library(lubridate)
library(readr)

# 2. Read enriched GeoJSON, drop geometry, filter valid CD_IDs, assign quarter
rats <- st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  st_drop_geometry() %>%
  filter(!is.na(CD_ID)) %>%
  mutate(quarter = floor_date(ymd_hms(created_dt), unit = "quarter"))

# 3. Summarise calls per CD_ID × quarter
quarterly_cd <- rats %>%
  group_by(CD_ID, quarter) %>%
  summarise(calls = n(), .groups = "drop")

# 4. Write out the quarterly counts CSV
write_csv(quarterly_cd, "output/quarterly_rats_by_cd.csv")
message("Wrote quarterly counts to output/quarterly_rats_by_cd.csv")
