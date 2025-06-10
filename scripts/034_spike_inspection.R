# Compute two KPI tiles:
#  • max calls in any CD‐day
#  • top address on that max day
# Writes: output/kpi_spike_summary.csv

library(sf)
library(dplyr)
library(lubridate)
library(readr)

# 1) Read in enriched points and drop geometry
rats <- st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  st_drop_geometry() %>%
  rename_with(~ gsub("\\.", "_", .x), everything())  # Unique.Key → Unique_Key, etc.

# 2) Build daily distinct‐ticket counts by CD
daily_cd <- rats %>%
  mutate(report_date = as_date(ymd_hms(created_dt))) %>%
  filter(!is.na(CD_ID)) %>%
  group_by(CD_ID, report_date) %>%
  summarise(calls = n_distinct(Unique_Key), .groups = "drop")

# 3) Find overall max CD‐day
max_day <- daily_cd %>% slice_max(calls, n = 1)

# 4) On that max day + CD, find the address with the most calls
hotspot <- rats %>%
  mutate(report_date = as_date(ymd_hms(created_dt))) %>%
  filter(report_date == max_day$report_date,
         CD_ID == max_day$CD_ID) %>%
  count(Address) %>%
  slice_max(n, n = 1) %>%
  rename(hotspot_address = Address,
         hotspot_calls   = n)

# 5) Combine into one KPI row
kpi <- tibble(
  max_calls        = max_day$calls,
  max_date         = as.character(max_day$report_date),
  max_CD_ID        = max_day$CD_ID,
  hotspot_address  = hotspot$hotspot_address,
  hotspot_calls    = hotspot$hotspot_calls
)

# 6) Write out
if (!dir.exists("output")) dir.create("output", recursive = TRUE)
write_csv(kpi, "output/kpi_spike_summary.csv")
message("✅ Wrote KPI summary to output/kpi_spike_summary.csv")
print(kpi)
