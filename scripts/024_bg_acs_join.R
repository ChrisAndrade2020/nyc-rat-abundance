# 024_bg_acs_join.R ------------------------------------------------------------
#
# Goal
# ----
# 1. Attach ACS block‑group socioeconomic columns (population, median income,
#    poverty count) to **each** rat sighting (point‑level).
# 2. Summarise at the block‑group level to get calls + call‑rate per 10 000.
# 3. Save both products for Tableau: a point CSV and a BG summary CSV.
#
# Prereqs
# • You ran 022_spatial_join.R → `output/rats_enriched.geojson` exists.
# • You have a Census API key in the env‑var `CENSUS_API_KEY`.
# -----------------------------------------------------------------------------

## 0) Libraries ---------------------------------------------------------------
# install.packages(c("sf", "dplyr", "readr", "stringr", "tidycensus"))
library(sf)
library(dplyr)
library(readr)
library(stringr)
library(tidycensus)

## 1) Download 2023 ACS block‑group stats --------------------------------------
census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)

vars <- c(
  pop_tot    = "B01003_001",  # total population
  med_income = "B19013_001",  # median household income (USD)
  pov_count  = "B17010_002"   # persons below poverty
)

message("📥  Pulling 2023 ACS block‑group data …")
acs_bg <- get_acs(
  geography = "block group",
  variables = vars,
  year      = 2023,
  state     = "NY",
  county    = c("Bronx", "Kings", "New York", "Queens", "Richmond"),
  output    = "wide",
  geometry  = TRUE
) %>%
  rename_with(~ str_remove(.x, "E$"), ends_with("E")) %>%  # drop trailing E
  select(GEOID, pop_tot, med_income, pov_count) %>%
  st_transform(crs = 4326)  # match rat points (WGS84)

## 2) Load enriched rat points --------------------------------------------------
message("📥  Reading rats_enriched.geojson …")
rats <- st_read("output/rats_enriched.geojson", quiet = TRUE)

## 3) Spatial join rats → block groups -----------------------------------------
message("🔗  Joining rat points to BGs …")
rat_bg_join <- st_join(
  rats,
  acs_bg,
  join = st_intersects,  # includes boundary‑touching points
  left = TRUE
) %>%
  rename_with(~ str_remove(.x, "\\.y$"), ends_with(".y")) %>%  # keep clean names
  select(-ends_with(".x"))

## 4) Write point‑level CSV -----------------------------------------------------
rat_bg_point_df <- st_drop_geometry(rat_bg_join)
write_csv(rat_bg_point_df, "output/rat_with_bg_ACS_point.csv")
message("✅  Saved point‑level rat+ACS → output/rat_with_bg_ACS_point.csv (",
        scales::comma(nrow(rat_bg_point_df)), " rows)")

## 5) Summarise by block group --------------------------------------------------
message("📊  Building BG‑level summary …")
bg_summary <- rat_bg_point_df %>%
  group_by(GEOID) %>%
  summarise(
    calls      = n(),
    pop_tot    = first(pop_tot),    # identical within BG
    med_income = first(med_income),
    pov_count  = first(pov_count)
  ) %>%
  ungroup() %>%
  mutate(rate_per_10k = calls / pop_tot * 10000)

write_csv(bg_summary, "output/bg_calls_ACS_summary.csv")
message("✅  Saved BG summary → output/bg_calls_ACS_summary.csv (",
        scales::comma(nrow(bg_summary)), " rows)")
