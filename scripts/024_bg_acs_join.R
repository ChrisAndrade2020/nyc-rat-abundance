# Purpose: Attach ACS block-group pop/income/poverty to every rat point
#          by doing an sp::st_join with ACS BG geometry (st_intersects).

# 0) Load packages
library(sf)
library(dplyr)
library(readr)
library(stringr)
library(tidycensus)

# 1) (Re)load your Census key & fetch ACS BG again with geometry
#    If you want to avoid re-fetching, modify 021 to also write out ACS_bg.geojson.
census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)
vars <- c(
  pop_tot    = "B01003_001",
  med_income = "B19013_001",
  pov_count  = "B17010_002"
)
acs_bg <- get_acs(
  geography = "block group",
  variables = vars,
  year      = 2019,
  state     = "NY",
  county    = c("Bronx", "Kings", "New York", "Queens", "Richmond"),
  output    = "wide",
  geometry  = TRUE
) %>% 
  st_transform(4326) %>% 
  rename_with(~ str_remove(.x, "E$"), ends_with("E"))

# 2) Read in your rat points
rats <- st_read("output/rat_clean.geojson")

