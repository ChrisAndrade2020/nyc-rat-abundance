# Purpose: Aggregate rat calls and ACS data to tract level
#          and compute call-rate vs. median income for Tableau.

# 0) Load required packages
install.packages("tidyverse")

library(tidyverse)
library(sf)
library(dplyr)
library(readr)

# 1) Read in your enriched rat sightings (with GEOID) from the spatial join
rats_enriched <- st_read("output/rat_clean.geojson")

# 2) Derive tract ID (first 11 characters of the block-group GEOID)
rats_enriched <- rats_enriched %>%
  mutate(tract = str_sub(GEOID, 1, 11))

# 2.5) Temp

# 2.5a) take first five rows
first5 <- rat_enriched %>% 
  slice(1:5)

# 2.5b) write them to CSV
write_csv(first5, "output/rat_enriched_first5.csv")

# 2.5c) sanity check. Lost 7.68% of matching points. Likely curbside and sidewalk(?) Too much data lost >5% 
# 024_bg_acs_join to amend
rats_enriched %>% 
  st_drop_geometry() %>% 
  summarise(
    total        = n(),
    no_parcel    = sum(is.na(GEOID)),
    pct_no_parcel= no_parcel / total * 100
  )

