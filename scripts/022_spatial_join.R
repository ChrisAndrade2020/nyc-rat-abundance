# ───────────────────────────────────────────────────────────
# Script: 022_spatial_join.R
# Purpose: Add parcel (PLUTO) and ACS metrics to cleaned rat sightings; output GeoJSON
# Inputs:  data/processed/rats_clean.csv
#          data/raw/NYC_Community_Districts/NYC_Community_Districts.shp
#          data/raw/MapPLUTO.shp
#          data/processed/ACS.csv
# Outputs: output/rats_enriched.geojson
# Depends: sf, dplyr, readr
# ───────────────────────────────────────────────────────────

# 1. Load spatial and data‐wrangling libraries
library(sf)
library(dplyr)
library(readr)

# 2. Read the cleaned rat sightings
rats_clean <- read_csv("data/processed/rats_clean.csv")

# 3. Drop any existing BBL column so we can re-derive it
rats_clean_join <- rats_clean %>% select(-BBL)

# 4. Remove rows missing coordinates (can’t map those)
missing_n <- rats_clean_join %>%
  filter(is.na(Longitude) | is.na(Latitude)) %>%
  nrow()
if (missing_n > 0) {
  message("Dropping ", missing_n, " rows missing coordinates")
  rats_clean_join <- rats_clean_join %>%
    filter(!is.na(Longitude), !is.na(Latitude))
}

# 5. Convert to an sf points object (WGS84)
rat_sf <- st_as_sf(
  rats_clean_join,
  coords = c("Longitude", "Latitude"),
  crs    = 4326,
  remove = FALSE
)

# 6. Read Community District boundaries, project to match rat_sf
cd_sf <- st_read(
  "data/raw/NYC_Community_Districts/NYC_Community_Districts.shp",
  quiet = TRUE
) %>% 
  st_transform(crs = st_crs(rat_sf))

# 7. Attach CD_ID (community district) to each rat point
rat_sf <- rat_sf %>%
  st_join(
    cd_sf %>% select(CD_ID = BoroCD),
    join = st_within,
    left = TRUE
  )

# 8. Read PLUTO parcels, repair any invalid geometries, project to match rat_sf
bbl_sf <- st_read("data/raw/MapPLUTO.shp", quiet = TRUE) %>%
  st_transform(crs = st_crs(rat_sf))
if (!all(st_is_valid(bbl_sf))) {
  message("Repairing invalid PLUTO polygons")
  bbl_sf <- st_make_valid(bbl_sf)
}

# 9. Spatial-join parcels to rat points to recover BBL
rat_bbl <- st_join(
  rat_sf,
  bbl_sf %>% select(join_BBL = BBL),
  join = st_within,
  left = TRUE
) %>%
  rename(BBL = join_BBL)

# 10. Load full PLUTO attribute table (drop geometry)
pluto_attrs <- st_read("data/raw/MapPLUTO.shp", quiet = TRUE) %>%
  st_drop_geometry()

# 11. Load ACS metrics keyed by BBL
acs <- read_csv("data/processed/ACS.csv")

# 12. Combine everything and drop duplicate tickets
rat_enriched <- rat_bbl %>%
  left_join(pluto_attrs, by = "BBL") %>%
  left_join(acs,         by = "BBL") %>%
  distinct(`Unique Key`, .keep_all = TRUE)

# 13. Create output directory if needed
output_dir <- "output"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

# 14. Write final GeoJSON
output_path <- file.path(output_dir, "rats_enriched.geojson")
st_write(rat_enriched, output_path, driver = "GeoJSON", delete_dsn = TRUE)
message("Wrote enriched GeoJSON to ", output_path)
