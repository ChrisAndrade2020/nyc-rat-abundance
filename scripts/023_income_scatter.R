# Purpose: Build tract-level table of rat calls vs. median income for Tableau

# 0) Load packages
library(sf)
library(dplyr)
library(readr)
library(stringr)

# 1) Read in your enriched rat sightings (with GEOID) 
rats_enriched <- st_read("outputs/rat_clean.geojson")

# 2) Count calls per tract
calls_by_tract <- rats_enriched %>%
  mutate(tract = str_sub(GEOID, 1, 11)) %>%    # first 11 chars = tract
  st_drop_geometry() %>%
  count(tract, name = "calls")

# 3) Read your ACS-by-BBL table and collapse to unique block-groups
acs_bbl <- read_csv("data/raw/ACS.csv") 

bg_acs <- acs_bbl %>%
  distinct(GEOID, pop_tot, med_income) %>%     # one row per BG
  mutate(tract = str_sub(GEOID, 1, 11))

# 4) Aggregate to tract
tract_acs <- bg_acs %>%
  group_by(tract) %>%
  summarise(
    pop_tot    = sum(pop_tot, na.rm = TRUE),
    med_income = sum(med_income * pop_tot, na.rm = TRUE) / sum(pop_tot, na.rm = TRUE)
  ) %>%
  ungroup()

# 5) Join calls + ACS, drop zero-pop tracts, compute rate per 10k
income_scatter_df <- calls_by_tract %>%
  left_join(tract_acs, by = "tract") %>%
  filter(pop_tot > 0) %>%
  mutate(rate_per_10k = calls / pop_tot * 10000)

# 6) Write out for Tableau
write_csv(income_scatter_df, "outputs/income_scatter.csv")

message("✅ Wrote ", nrow(income_scatter_df), 
        " tracts to outputs/income_scatter.csv")
