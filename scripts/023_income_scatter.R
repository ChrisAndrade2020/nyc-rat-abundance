# Build a tract‑level table that pairs rat‑call rates with median household
# income – exactly what the Tableau scatter plot needs.
#
# Steps
#   1. Read the fully enriched rat GeoJSON (has GEOID + PLUTO + ACS columns).
#   2. Count calls per *tract* (first 11 chars of the 12‑digit GEOID).
#   3. Load the BBL‑keyed ACS lookup and roll it up from BG → tract.
#   4. Join calls + income, compute calls‑per‑10k residents.
#   5. Write a slim CSV for Tableau.
# -----------------------------------------------------------------------------

## 0) Libraries ----------------------------------------------------------------
# install.packages(c("sf", "dplyr", "readr", "stringr"))
library(sf)
library(dplyr)
library(readr)
library(stringr)

## 1) Read rat sightings with GEOID -------------------------------------------
#    Note: earlier script writes *rats_enriched.geojson* – make sure the path
#    matches. If not, adjust the filename below.
rats_enriched <- st_read("output/rats_enriched.geojson", quiet = TRUE)

## 2) Calls per tract -----------------------------------------------------------
calls_by_tract <- rats_enriched %>%
  mutate(
    tract = str_sub(GEOID, 1, 11)  # GEOID[1:11] = state + county + tract
  ) %>%
  st_drop_geometry() %>%           # stats only; no need for shapes
  count(tract, name = "calls")

## 3) ACS metrics per block group ---------------------------------------------
acs_bbl <- read_csv("data/processed/ACS.csv")

bg_acs <- acs_bbl %>%
  distinct(GEOID, pop_tot, med_income) %>%   # one row per BG
  mutate(
    tract = str_sub(GEOID, 1, 11)
  )

## 4) Aggregate BG → tract ------------------------------------------------------
tract_acs <- bg_acs %>%
  group_by(tract) %>%
  summarise(
    pop_tot = sum(pop_tot, na.rm = TRUE),
    
    # Weighted mean: (Σ med_income * pop) / Σ pop
    med_income = sum(med_income * pop_tot, na.rm = TRUE) / sum(pop_tot, na.rm = TRUE)
  ) %>%
  ungroup()

## 5) Combine calls + demographics --------------------------------------------
income_scatter_df <- calls_by_tract %>%
  left_join(tract_acs, by = "tract") %>%
  filter(
    med_income > 0,
    pop_tot   >= 200
  ) %>%
  mutate(
    rate_per_10k = calls / pop_tot * 10000
  )

## 6) Save CSV for Tableau ------------------------------------------------------
write_csv(income_scatter_df, "output/income_scatter.csv")
message("✅  Wrote ", nrow(income_scatter_df), " tracts to output/income_scatter.csv")