# ───────────────────────────────────────────────────────────
# Script: 023_income_scatter.R
# Purpose: Prepare tract-level call rates paired with median income for Tableau scatter
# Inputs:  output/rats_enriched.geojson
#          data/processed/ACS.csv
# Outputs: output/income_scatter.csv
# Depends: sf, dplyr, readr, stringr
# ───────────────────────────────────────────────────────────

# 1. Load spatial and data libraries
library(sf)
library(dplyr)
library(readr)
library(stringr)

# 2. Read the enriched GeoJSON (includes GEOID from ACS join)
rats_enriched <- st_read("output/rats_enriched.geojson", quiet = TRUE)

# 3. Count calls per tract (first 11 characters of GEOID)
calls_by_tract <- rats_enriched %>%
  mutate(tract = str_sub(GEOID, 1, 11)) %>%
  st_drop_geometry() %>%
  count(tract, name = "calls")

# 4. Load block-group ACS metrics
acs_bbl <- read_csv("data/processed/ACS.csv")

# 5. Aggregate block-group metrics up to tract level
tract_acs <- acs_bbl %>%
  distinct(GEOID, pop_tot, med_income) %>%
  mutate(tract = str_sub(GEOID, 1, 11)) %>%
  group_by(tract) %>%
  summarise(
    pop_tot    = sum(pop_tot, na.rm = TRUE),
    med_income = sum(med_income * pop_tot, na.rm = TRUE) / sum(pop_tot, na.rm = TRUE)
  ) %>%
  ungroup()

# 6. Join calls + demographics, filter, compute calls per 10k residents
income_scatter_df <- calls_by_tract %>%
  left_join(tract_acs, by = "tract") %>%
  filter(
    med_income > 0,
    pop_tot   >= 200
  ) %>%
  mutate(rate_per_10k = calls / pop_tot * 10000)

# 7. Write out the CSV for Tableau
write_csv(income_scatter_df, "output/income_scatter.csv")
message("Wrote income scatter data: ", nrow(income_scatter_df), " tracts")
