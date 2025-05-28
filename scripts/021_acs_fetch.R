
# 0) Install & load needed packages (once; then comment install.packages)
# install.packages(c("tidycensus", "sf", "dplyr", "readr", "stringr"))
library(tidycensus)   # to pull ACS data
library(sf)           # spatial tools for centroids
library(dplyr)        # data wrangling
library(readr)        # CSV I/O
library(stringr)      # string helpers

# 1) Load your Census API key from ~/.Renviron
my_key <- Sys.getenv("CENSUS_API_KEY")
if (my_key == "") stop("🔑 CENSUS_API_KEY not found in ~/.Renviron")
census_api_key(my_key, install = FALSE)

# 2) Define ACS variables (2019 5-year)
vars <- c(
  pop_tot    = "B01003_001",  # total population
  med_income = "B19013_001",  # median household income
  pov_count  = "B17001_002"   # count below poverty
)

# 3) Download ACS block-group data (with geometry)
message("🔄 Downloading ACS block-group data for NYC…")
acs_bg <- get_acs(
  geography = "block group",
  variables = vars,
  year      = 2019,
  state     = "NY",
  county    = c("Bronx", "Kings", "New York", "Queens", "Richmond"),
  output    = "wide",
  geometry  = TRUE
)

# 4) Read & project PLUTO parcels
message("🔄 Reading PLUTO parcels (MapPLUTO.shp)…")
bbl_sf <- st_read("data/raw/MapPLUTO.shp") %>%
  st_transform(crs = st_crs(acs_bg))

# 4b) Repair any invalid geometries so centroids will compute
if (!all(st_is_valid(bbl_sf))) {
  message("🔧 Repairing invalid geometries…")
  bbl_sf <- sf::st_make_valid(bbl_sf)
}

# 5) Compute centroids of each lot
message("🔄 Computing centroids of each lot…")
bbl_centroids <- st_centroid(bbl_sf)

# 6) Spatial‐join each lot to its block‐group, keep GEOID + estimates
message("🔄 Joining lots to block groups…")
acs_by_bbl <- st_join(
  bbl_centroids,
  acs_bg %>% select(GEOID, ends_with("E")),
  join = st_within
) %>%
  st_drop_geometry() %>%
  rename_with(~ str_remove(.x, "E$"), ends_with("E")) %>%
  select(
    BBL,        # tax-lot ID
    GEOID,      # block-group ID
    pop_tot,    # total population
    med_income, # median household income
    pov_count   # count below poverty
  )

# 7) Write out the ACS-by-BBL table
message("🔄 Writing ACS×BBL table to data/raw/ACS.csv…")
write_csv(acs_by_bbl, "data/raw/ACS.csv")

# 8) Sanity check: sum each block-group’s pop_tot exactly once
total_pop <- acs_by_bbl %>%
  distinct(GEOID, pop_tot) %>%
  summarise(total_pop = sum(pop_tot, na.rm = TRUE)) %>%
  pull(total_pop)

message("✅ Done! ACS table has ", nrow(acs_by_bbl), 
        " lots; sum of unique block-group pop_tot = ", total_pop)
