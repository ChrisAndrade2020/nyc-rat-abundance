# ───────────────────────────────────────────────────────────
# Script: 034_spike_inspection.R
# Purpose: Identify the single highest-call day per CD_ID and its hotspot address
# Inputs:  output/rats_enriched.geojson
# Outputs: output/kpi_spike_summary.csv
# Depends: sf, dplyr, lubridate, readr
# ───────────────────────────────────────────────────────────

# 1. Load spatial and data-wrangling libraries
library(sf)
library(dplyr)
library(lubridate)
library(readr)

# 2. Read enriched GeoJSON, drop geometry, and normalize column names
rats <- st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  st_drop_geometry() %>%
  rename_with(~ gsub("\\.", "_", .x), everything())

# 3. Compute daily distinct-ticket counts by CD_ID
daily_cd <- rats %>%
  mutate(report_date = as_date(ymd_hms(created_dt))) %>%
  filter(!is.na(CD_ID)) %>%
  group_by(CD_ID, report_date) %>%
  summarise(calls = n_distinct(Unique_Key), .groups = "drop")

# 4. Find the single CD_ID-day with the highest call count
max_day <- daily_cd %>% slice_max(calls, n = 1)

# 5. Within that CD_ID and date, identify the most-called Address
hotspot <- rats %>%
  mutate(report_date = as_date(ymd_hms(created_dt))) %>%
  filter(
    report_date == max_day$report_date,
    CD_ID       == max_day$CD_ID
  ) %>%
  count(Address) %>%
  slice_max(n, n = 1) %>%
  rename(
    hotspot_address = Address,
    hotspot_calls   = n
  )

# 6. Compile KPI row and write out summary CSV
kpi <- tibble(
  max_calls       = max_day$calls,
  max_date        = as.character(max_day$report_date),
  max_CD_ID       = max_day$CD_ID,
  hotspot_address = hotspot$hotspot_address,
  hotspot_calls   = hotspot$hotspot_calls
)

if (!dir.exists("output")) dir.create("output", recursive = TRUE)
write_csv(kpi, "output/kpi_spike_summary.csv")
message("Wrote KPI spike summary to output/kpi_spike_summary.csv")
