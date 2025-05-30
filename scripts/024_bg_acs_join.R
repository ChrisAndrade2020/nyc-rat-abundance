# 024_bg_acs_join.R
# Purpose: Attach ACS block-group pop/income/poverty to each rat point (point-level CSV),
#          plus summarize calls & compute call-rate per 10k by block group (summary CSV).

# 0) Load packages
# install.packages(c("sf", "dplyr", "readr", "stringr", "tidycensus"))
library(sf)
library(dplyr)
library(readr)
library(stringr)
library(tidycensus)

# 1) Fetch ACS block-group data with geometry (2019–2023 5-year)
census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)
vars <- c(
  pop_tot    = "B01003_001",  # total population
  med_income = "B19013_001",  # median household income
  pov_count  = "B17010_002"   # population below poverty
)
message("🔄 Downloading ACS block-group geometry (2019–2023)…")
acs_bg <- get_acs(
  geography = "block group",
  variables = vars,
  year      = 2023,
  state     = "NY",
  county    = c("Bronx", "Kings", "New York", "Queens", "Richmond"),
  output    = "wide",
  geometry  = TRUE
) %>%
  rename_with(~ str_remove(.x, "E$"), ends_with("E")) %>%
  select(GEOID, pop_tot, med_income, pov_count) %>%
  st_transform(crs = 4326)  # ensure WGS84

# 2) Read enriched rat points (from 022)
message("🔄 Reading enriched rat GeoJSON…")
rats <- st_read("output/rat_clean.geojson")

# 3) Spatial-join to block-groups (intersects to catch boundary points)
message("🔄 Spatial-joining rats → BG…")
rat_bg_join <- st_join(
  rats,
  acs_bg,
  join = st_intersects,
  left = TRUE
) %>%
  # Rename newly joined ACS fields (suffix .y) and drop old .x fields
  rename_with(~ str_remove(.x, "\\.y$"), ends_with(".y")) %>%
  select(-ends_with(".x"))

# 4a) Write point-level CSV for Tableau
message("🔄 Writing point-level ACS join CSV…")
rat_bg_point_df <- rat_bg_join %>% st_drop_geometry()
write_csv(rat_bg_point_df, "output/rat_with_bg_ACS_point.csv")
message("✅ output/rat_with_bg_ACS_point.csv written with ",
        nrow(rat_bg_point_df), " rows and ACS fields attached.")

# 4b) Summarize by block-group and compute rate per 10k
message("🔄 Computing BG-level summary…")
bg_summary <- rat_bg_point_df %>%
  group_by(GEOID) %>%
  summarise(
    calls      = n(),
    pop_tot    = first(pop_tot),
    med_income = first(med_income),
    pov_count  = first(pov_count)
  ) %>%
  mutate(rate_per_10k = calls / pop_tot * 10000)

write_csv(bg_summary, "output/bg_calls_ACS_summary.csv")
message("✅ output/bg_calls_ACS_summary.csv written with ",
        nrow(bg_summary), " block-groups & rate_per_10k.")
