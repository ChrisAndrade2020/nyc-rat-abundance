# ───────────────────────────────────────────────────────────
# Script: 024_bg_acs_join.R
# Purpose: Attach ACS block-group stats to each rat sighting and summarize by block group
# Inputs:  output/rats_enriched.geojson
#          Census API key in CENSUS_API_KEY
# Outputs: output/rat_with_bg_ACS_point.csv
#          output/bg_calls_ACS_summary.csv
# Depends: sf, dplyr, readr, stringr, tidycensus
# ───────────────────────────────────────────────────────────

# 1. Load spatial, census, and data libraries
library(sf)
library(dplyr)
library(readr)
library(stringr)
library(tidycensus)

# 2. Fetch 2023 ACS block-group data (with geometry)
census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)
vars <- c(
  pop_tot    = "B01003_001",
  med_income = "B19013_001",
  pov_count  = "B17010_002"
)
acs_bg <- get_acs(
  geography = "block group",
  variables = vars,
  year      = 2023,
  state     = "NY",
  county    = c("Bronx","Kings","New York","Queens","Richmond"),
  output    = "wide",
  geometry  = TRUE
) %>%
  rename_with(~ str_remove(.x, "E$"), ends_with("E")) %>%
  select(GEOID, pop_tot, med_income, pov_count) %>%
  st_transform(crs = 4326)

# 3. Read enriched rat points
rats <- st_read("output/rats_enriched.geojson", quiet = TRUE)

# 4. Spatial-join rat points to block groups (attach ACS fields)
rat_bg_join <- st_join(
  rats,
  acs_bg,
  join = st_intersects,
  left = TRUE
) %>%
  rename_with(~ str_remove(.x, "\\.y$"), ends_with(".y")) %>%
  select(-ends_with(".x"))

# 5. Export point-level rat+ACS CSV
rat_bg_point_df <- st_drop_geometry(rat_bg_join)
write_csv(rat_bg_point_df, "output/rat_with_bg_ACS_point.csv")
message("Wrote point-level rat+ACS data: ", nrow(rat_bg_point_df), " rows")

# 6. Summarize calls and ACS metrics by block group, compute rate per 10k
bg_summary <- rat_bg_point_df %>%
  group_by(GEOID) %>%
  summarise(
    calls      = n(),
    pop_tot    = first(pop_tot),
    med_income = first(med_income),
    pov_count  = first(pov_count)
  ) %>%
  ungroup() %>%
  mutate(rate_per_10k = calls / pop_tot * 10000)

write_csv(bg_summary, "output/bg_calls_ACS_summary.csv")
message("Wrote BG summary data: ", nrow(bg_summary), " block groups")
