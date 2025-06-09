# Aggregate enriched 311 rat sightings to daily counts
#
# Reads output/rats_enriched.geojson, groups by date, and writes
# output/daily_rats.csv for the seasonality heat-map.

library(dplyr)
library(lubridate)
library(sf)
library(readr)

# 1) Read enriched points
rats <- sf::st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  sf::st_drop_geometry()

# 2) Aggregate to one row per date
daily_counts <- rats %>%
  mutate(date = as_date(ymd_hms(created_dt))) %>%
  group_by(date) %>%
  summarise(calls = n(), .groups = "drop")

# 3) Write CSV for Tableau
write_csv(daily_counts, "output/daily_rats.csv")
message("✅ Wrote daily counts to output/daily_rats.csv")
