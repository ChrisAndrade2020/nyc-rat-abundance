# 0) Load required packages
library(sf)      # spatial data handling
library(dplyr)   # data wrangling
library(readr)   # CSV import

# 1) Read in your cleaned rats dataset
#    (make sure this matches where you saved it)
rats_clean <- read_csv("data/processed/rats_clean.csv")

# 2) Convert to sf point geometry
rat_sf <- st_as_sf(
  rats_clean,
  coords = c("Longitude", "Latitude"),  # x = lon, y = lat
  crs    = 4326,                        # WGS84
  remove = FALSE                        # keep raw lon/lat cols
)

# 3) Read NYC tax-lot polygons (BBL shapefile)
bbl_sf <- st_read("data/raw/NYC_BBL_shapefile.shp") %>%
  st_transform(crs = st_crs(rat_sf))   # ensure same CRS

# 4) Spatial-join: stamp each sighting with its BBL
rat_bbl <- st_join(
  rat_sf,
  bbl_sf %>% select(BBL),  # bring over only the BBL field
  join = st_within,
  left = TRUE
)
# → any NA in rat_bbl$BBL means the point fell outside all parcels

# 5) Read in PLUTO & ACS tables (keyed by BBL)
pluto <- read_csv("data/raw/PLUTO.csv")  # must include column 'BBL'
acs   <- read_csv("data/raw/ACS.csv")    # must include column 'BBL'

# 6) Attribute-join covariates to each sighting
rat_enriched <- rat_bbl %>%
  left_join(pluto, by = "BBL") %>%
  left_join(acs,   by = "BBL")

# 7) Ensure an outputs folder exists
if (!dir.exists("outputs")) {
  dir.create("outputs", recursive = TRUE)
}

# 8) Write out enriched GeoJSON for mapping & modeling
st_write(
  rat_enriched,
  "outputs/rat_clean.geojson",
  driver     = "GeoJSON",
  delete_dsn = TRUE
)

message("✅ Spatial join complete: outputs/rat_clean.geojson written")
