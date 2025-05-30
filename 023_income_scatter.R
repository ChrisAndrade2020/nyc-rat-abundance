# Purpose: Aggregate rat calls and ACS data to tract level
#          and compute call-rate vs. median income for Tableau.

# 0) Load required packages
install.packages("tidyverse")

library(tidyverse)
library(sf)

# 1) Read in your enriched rat sightings (with GEOID) from the spatial join
rats_enriched <- st_read("output/rat_clean.geojson")

# 2) Derive tract ID (first 11 characters of the block-group GEOID)
rats_enriched <- rats_enriched %>%
  mutate(tract = str_sub(GEOID, 1, 11))


