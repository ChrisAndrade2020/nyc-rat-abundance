# Aggregate enriched 311 rat sightings to daily distinct-ticket counts

library(dplyr)
library(lubridate)
library(sf)
library(readr)

# 1) Read enriched points + drop geometry
rats <- st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  st_drop_geometry()

# 2) Build daily counts (distinct tickets)
daily_cd <- rats %>%
  mutate(report_date = as_date(ymd_hms(created_dt))) %>%
  filter(!is.na(CD_ID)) %>%
  group_by(CD_ID, report_date) %>%
  summarise(
    calls = n_distinct(Unique.Key),
    .groups = "drop"
  )

# 3) Write out
write_csv(daily_cd, "output/daily_rats_by_cd.csv")
message("✅ Wrote per-CD daily counts to output/daily_rats_by_cd.csv")

daily_cd %>%
  filter(report_date == as.Date("2015-07-15")) %>%
  arrange(desc(calls))

# wow actually 230 calls from Bronx CD 07 in 07-15-2015 week 29