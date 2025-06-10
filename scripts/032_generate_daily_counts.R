# Aggregate enriched 311 rat sightings to daily counts
#
# Reads output/rats_enriched.geojson, groups by date, and writes
# output/daily_rats.csv for the seasonality heat-map.

library(dplyr)
library(lubridate)
library(sf)
library(readr)

# 1) Read enriched points (with CD_ID)
rats <- sf::st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  sf::st_drop_geometry()

# 2) Build daily counts by CD_ID
daily_cd <- rats %>%
  mutate(date = as_date(ymd_hms(created_dt))) %>%
  filter(!is.na(CD_ID)) %>%
  group_by(CD_ID, date) %>%
  summarise(calls = n(), .groups = "drop")

# 3) Write out
write_csv(daily_cd, "output/daily_rats_by_cd.csv")
message("✅ Wrote per-CD daily counts to output/daily_rats_by_cd.csv")