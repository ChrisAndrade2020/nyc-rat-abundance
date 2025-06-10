# Aggregate enriched 311 rat sightings to daily counts
#
# Reads output/rats_enriched.geojson, groups by date, and writes
# output/daily_rats.csv for the seasonality heat-map.

library(dplyr)
library(lubridate)
library(sf)
library(readr)

rats <- sf::st_read("output/rats_enriched.geojson", quiet=TRUE) %>%
  st_drop_geometry() %>%
  filter(!is.na(CD_ID)) %>%
  mutate(quarter = floor_date(ymd_hms(created_dt), unit="quarter"))

quarterly_cd <- rats %>%
  group_by(CD_ID, quarter) %>%
  summarise(calls = n(), .groups="drop")

write_csv(quarterly_cd, "output/quarterly_rats_by_cd.csv")
message("✅ Wrote per-CD quarterly counts to output/quarterly_rats_by_cd.csv")