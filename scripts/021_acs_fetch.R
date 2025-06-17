# ───────────────────────────────────────────────────────────
# Script: 021_acs_fetch.R
# Purpose: Spatially attach 2023 ACS block-group metrics to NYC tax lots
# Inputs:  data/raw/MapPLUTO.shp; ACS API key
# Outputs: data/processed/ACS.csv
# Depends: tidycensus, sf, dplyr, readr, stringr
# ───────────────────────────────────────────────────────────

# 1. Load spatial and census libraries (install once if missing)
# install.packages(c("tidycensus","sf","dplyr","readr","stringr"))
library(tidycensus); library(sf); library(dplyr)
library(readr);    library(stringr)

# 2. Ensure Census API key is set
if (Sys.getenv("CENSUS_API_KEY") == "") {
  stop("Set CENSUS_API_KEY in environment before running.")
}
census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)

# 3. Define ACS variables to pull (pop, income, poverty)
vars <- c(
  pop_tot    = "B01003_001",
  med_income = "B19013_001",
  pov_count  = "B17010_002"
)

# 4. Download block-group ACS data with geometry
message("Fetching ACS block-group data…")
acs_bg <- get_acs(
  geography = "block group",
  variables = vars,
  year      = 2023,
  state     = "NY",
  county    = c("Bronx","Kings","New York","Queens","Richmond"),
  output    = "wide", geometry = TRUE
)

# 5. Read NYC parcel shapefile and align CRS for join
message("Reading MapPLUTO shapefile…")
bbl_sf <- st_read("data/raw/MapPLUTO.shp", quiet = TRUE) %>%
  st_transform(crs = st_crs(acs_bg))

# 6. Repair any invalid geometries before spatial operations
if (!all(st_is_valid(bbl_sf))) {
  message("Fixing invalid geometries…")
  bbl_sf <- sf::st_make_valid(bbl_sf)
}

# 7. Generate interior points for each parcel to ensure joins land inside
bbl_pts <- st_point_on_surface(bbl_sf)

# 8. Spatially join each lot to its block group and inherit ACS stats
acs_by_bbl <- st_join(
  bbl_pts,
  acs_bg %>% select(GEOID, ends_with("E")),
  join = st_within, left = FALSE
) %>%
  st_drop_geometry() %>%
  rename_with(~ str_remove(.x, "E$"), ends_with("E")) %>%
  select(BBL, GEOID, pop_tot, med_income, pov_count)

# 9. Write the joined dataset for downstream use
write_csv(acs_by_bbl, "data/processed/ACS.csv")
message("Saved ACS.csv with ", nrow(acs_by_bbl), " rows")
