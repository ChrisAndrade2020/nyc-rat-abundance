# 0) Load required packages
library(sf)      # spatial data handling
library(dplyr)   # data wrangling
library(readr)   # CSV import

# 1) Read in your cleaned rats dataset (kept intact)
rats_clean <- read_csv("data/processed/rats_clean.csv")

# 2) Create a join‐ready copy and drop its old BBL
rats_clean_join <- rats_clean %>%
  select(-BBL)

# 2b) Drop any rows in the join copy with missing coords
missing_n <- rats_clean_join %>%
  filter(is.na(Longitude) | is.na(Latitude)) %>%
  nrow()
if (missing_n > 0) {
  message("⚠ Dropping ", missing_n, " rows with missing Longitude/Latitude")
  rats_clean_join <- rats_clean_join %>%
    filter(!is.na(Longitude), !is.na(Latitude))
}

# 3) Convert the join copy to sf point geometry
rat_sf <- st_as_sf(
  rats_clean_join,
  coords = c("Longitude", "Latitude"),
  crs    = 4326,
  remove = FALSE
)

# 4) Read PLUTO parcels and repair invalid geometries
bbl_sf <- st_read("data/raw/MapPLUTO.shp") %>%
  st_transform(crs = st_crs(rat_sf))
if (!all(st_is_valid(bbl_sf))) {
  message("🔧 Repairing invalid PLUTO geometries…")
  bbl_sf <- sf::st_make_valid(bbl_sf)
}

# 5) Spatial‐join: bring in the parcel BBL under a temp name
rat_bbl <- st_join(
  rat_sf,
  bbl_sf %>% select(join_BBL = BBL),
  join = st_within,
  left = TRUE
) %>%
  rename(BBL = join_BBL)

# 6) Read PLUTO attributes (directly from shapefile) and drop geometry
message("🔄 Reading PLUTO shapefile for attributes…")
pluto <- st_read("data/raw/MapPLUTO.shp") %>%
  st_drop_geometry()

# 7) Read in ACS table (keyed by BBL)
message("🔄 Reading ACS×BBL CSV…")
acs <- read_csv("data/raw/ACS.csv")

# 8) Attribute‐join covariates to each sighting
rat_enriched <- rat_bbl %>%
  left_join(pluto, by = "BBL") %>%
  left_join(acs,   by = "BBL")

# 9) Ensure outputs folder exists
if (!dir.exists("outputs")) dir.create("outputs", recursive = TRUE)

# 10) Write out enriched GeoJSON
st_write(
  rat_enriched,
  "outputs/rat_clean.geojson",
  driver     = "GeoJSON",
  delete_dsn = TRUE
)

message("✅ Spatial join complete: outputs/rat_clean.geojson written")  
