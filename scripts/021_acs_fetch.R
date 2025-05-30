# Build a lookup table that attaches 2023 ACS block‑group metrics (population,
# median income, poverty count) to every NYC tax lot (BBL) using spatial joins.
# The end product – **ACS.csv** – will drive the income‑vs‑call‑rate scatter and
# any future socioeconomic overlays.
#
# Steps in plain words
#   0. Load the packages you need (tidycensus, sf, …).
#   1. Confirm you actually have a Census API key.
#   2. (Optional) Peek at the B17010 variable family – just a sanity check.
#   3. Download the *block‑group* ACS table, geometry included.
#   4. Read NYC’s parcel layer (MapPLUTO) and ensure it shares the same CRS.
#   5. Compute a centroid for every lot (rough proxy for its location).
#   6. Spatial‑join each centroid to its parent block‑group → inherit ACS stats.
#   7. Write a tidy CSV with BBL + ACS columns.
#   8. Quick smoke test: total NYC population matches expectations.
#
# Run time: ~3–5 min on a laptop(Ryzen 5700U); memory ~2-3GB when both layers in RAM.
# -----------------------------------------------------------------------------

## 0) Install + load libs -------------------------------------------------------
# install.packages(c("tidycensus", "sf", "dplyr", "readr", "stringr"))
library(tidycensus)   # get_acs(), load_variables()
library(sf)           # vector data wrangling
library(dplyr)        # pipes & verbs
library(readr)        # write_csv()
library(stringr)      # str_detect(), str_remove()

## 1) API key handshake ---------------------------------------------------------
my_key <- Sys.getenv("CENSUS_API_KEY")
if (my_key == "") {
  stop("🔑  CENSUS_API_KEY not found – run Sys.setenv(CENSUS_API_KEY = 'YOUR_KEY') first.")
}
census_api_key(my_key, install = FALSE)

## 1.5) Optional: list B17010 variables ----------------------------------------
#    B17010_002 == people below poverty line.
#    Keeping this chunk helps future devs verify variables exist for chosen year.
#    Feel free to delete/ comment once comfortable.
load_variables(2023, "acs5", cache = TRUE) %>%
  filter(str_detect(name, "B17010")) %>%
  select(name, label) %>%
  head()

## 2) Chosen ACS variables ------------------------------------------------------
vars <- c(
  pop_tot    = "B01003_001",  # total population
  med_income = "B19013_001",  # median household income (USD)
  pov_count  = "B17010_002"   # persons below poverty level
)

## 3) Download 2023 ACS block‑group data ---------------------------------------
message("📥  Pulling 2023 ACS block‑group stats …")
acs_bg <- get_acs(
  geography = "block group",
  variables = vars,
  year      = 2023,  # five‑year ACS release labelled 2023 (covers 2019‑2023)
  state     = "NY",
  county    = c("Bronx", "Kings", "New York", "Queens", "Richmond"),
  output    = "wide",
  geometry  = TRUE   # we need shapes for a spatial join
)

## 4) Read MapPLUTO parcels -----------------------------------------------------
message("📥  Reading MapPLUTO shapefile … (takes ~30 s)")
bbl_sf <- st_read("data/raw/MapPLUTO.shp", quiet = TRUE) %>%
  st_transform(crs = st_crs(acs_bg))  # align CRS so joins work

# 4b) Repair geometries (common in parcel data)
if (!all(st_is_valid(bbl_sf))) {
  message("🔧  Fixing invalid geometries …")
  bbl_sf <- sf::st_make_valid(bbl_sf)
}

## 5) Get one representative point per lot -------------------------------------
#    Plain centroids can fall *outside* skinny L‑shaped lots → PointOnSurface
message("📐  Generating inside‑the‑polygon centroids …")
bbl_pts <- st_point_on_surface(bbl_sf)  # always falls inside polygon

## 6) Spatial join: each lot inherits block‑group attributes --------------------
message("🔗  Joining lots to block groups …")
acs_by_bbl <- st_join(
  bbl_pts,
  acs_bg %>% select(GEOID, ends_with("E")),
  join = st_within,   # stricter than st_intersects; what we want here
  left = FALSE        # drop parcels that don’t fall inside an ACS polygon
) %>%
  st_drop_geometry() %>%
  rename_with(~ str_remove(.x, "E$"), ends_with("E")) %>%  # strip trailing E
  select(
    BBL, GEOID,
    pop_tot, med_income, pov_count
  )

## 7) Write to disk -------------------------------------------------------------
output_path <- "data/processed/ACS.csv"
write_csv(acs_by_bbl, output_path)
message("✅  Saved ", scales::comma(nrow(acs_by_bbl)), " rows to ", output_path)

## 8) Sanity check: aggregate pop once per GEOID -------------------------------
total_pop <- acs_by_bbl %>%
  distinct(GEOID, pop_tot) %>%
  summarise(nyc_pop = sum(pop_tot, na.rm = TRUE)) %>%
  pull(nyc_pop)

message("🔎  Sum of unique block‑group populations = ", scales::comma(total_pop))