# Enrich each cleaned rat sighting with parcel (PLUTO) attributes **and** ACS
# block‑group socioeconomic metrics. Result is a ready‑to‑map GeoJSON.
#
# Workflow
#   1. Read `rats_clean.csv` (already flagged & filtered).
#   2. Convert to an sf points object.
#   3. Spatial‑join to MapPLUTO to recover the tax‑lot ID (BBL).
#   4. Bring in full PLUTO attributes and a pre‑built `ACS.csv` keyed by BBL.
#   5. Write one tidy GeoJSON.
#
# Assumes you have already run 021_acs_fetch.R so `ACS.csv` exists.
# -----------------------------------------------------------------------------

## 0) Libraries ----------------------------------------------------------------
library(sf)      # spatial data
library(dplyr)   # %>% and verbs
library(readr)   # read_csv(), write_csv()

## 1) Load cleaned rats data ----------------------------------------------------
rats_clean <- read_csv("data/processed/rats_clean.csv")

## 2) Remove stale BBL col (we’ll re‑attach a fresh one) ------------------------
rats_clean_join <- rats_clean %>% select(-BBL)

# 2b) Drop rows without coordinates – can’t map what we can’t locate
missing_n <- rats_clean_join %>%
  filter(is.na(Longitude) | is.na(Latitude)) %>%
  nrow()
if (missing_n > 0) {
  message("⚠  Dropping ", missing_n, " rows without coordinates")
  rats_clean_join <- rats_clean_join %>%
    filter(!is.na(Longitude), !is.na(Latitude))
}

## 3) Cast to sf points ---------------------------------------------------------
rat_sf <- st_as_sf(
  rats_clean_join,
  coords = c("Longitude", "Latitude"),
  crs    = 4326,   # WGS84
  remove = FALSE
)

## 3b) Read Community District boundaries -------------------------------------
cd_sf <- sf::st_read(
    "data/raw/NYC_Community_Districts/NYC_Community_Districts.shp",
    quiet = TRUE
  ) %>% 
    st_transform(crs = st_crs(rat_sf))

## 3c) Join CD_ID onto each rat point -----------------------------------------
rat_sf <- rat_sf %>%
    st_join(
        cd_sf %>% select(CD_ID = boro_cd),  # rename the shapefile’s boro_cd field
        join = st_within,
        left = TRUE
      )

## 4) Read PLUTO parcels & ensure valid geometries -----------------------------
bbl_sf <- st_read("data/raw/MapPLUTO.shp", quiet = TRUE) %>%
  st_transform(crs = st_crs(rat_sf))

if (!all(st_is_valid(bbl_sf))) {
  message("🔧  Fixing invalid PLUTO polygons …")
  bbl_sf <- st_make_valid(bbl_sf)
}

## 5) Spatial join lots → rat points to grab BBL -------------------------------
#    Keep only the BBL column from PLUTO at this stage (lighter memory).
rat_bbl <- st_join(
  rat_sf,
  bbl_sf %>% select(join_BBL = BBL),
  join = st_within,   # point must fall *inside* lot polygon
  left = TRUE         # keep all rat points even if no lot (e.g., parks, water)
) %>%
  rename(BBL = join_BBL)

## 6) Load full PLUTO attributes (no geometry needed) --------------------------
pluto_attrs <- st_read("data/raw/MapPLUTO.shp", quiet = TRUE) %>%
  st_drop_geometry()

## 7) Load ACS metrics keyed by BBL --------------------------------------------
acs <- read_csv("data/processed/ACS.csv")

## 8) Attribute joins -----------------------------------------------------------
rat_enriched <- rat_bbl %>%
  left_join(pluto_attrs, by = "BBL") %>%
  left_join(acs,         by = "BBL")

## 9) Ensure output dir exists --------------------------------------------------
output_dir <- "output"
if (!dir.exists(output_dir)) dir.create(output_dir, recursive = TRUE)

## 10) Write GeoJSON ------------------------------------------------------------
output_path <- file.path(output_dir, "rats_enriched.geojson")
st_write(rat_enriched, output_path, driver = "GeoJSON", delete_dsn = TRUE)

message("✅  Spatial join complete – wrote " , output_path)