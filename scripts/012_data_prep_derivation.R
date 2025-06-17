# ───────────────────────────────────────────────────────────
# Script: 012_data_prep_derivation.R
# Purpose: Transform rats_clean into Tableau-ready artifacts
# Inputs:  data/processed/rats_clean.csv; ACS API key
# Outputs: data/processed/rats_ready.csv; data/processed/borough_rates.csv
# Depends: readr, dplyr, lubridate, forcats, stringr, tidycensus
# ───────────────────────────────────────────────────────────

# 0. Load packages (install once if needed)
# install.packages(c("readr","dplyr","lubridate","forcats","stringr","tidycensus"))
library(readr); library(dplyr); library(lubridate)
library(forcats); library(stringr); library(tidycensus)

# 1. Read cleaned rat calls and standardize Borough labels
rats_clean <- read_csv("data/processed/rats_clean.csv") %>%
  mutate(Borough = str_to_title(Borough))

# 2. Create point-level file for mapping/charting
rats_ready <- rats_clean %>%
  transmute(
    UniqueKey    = `Unique Key`,
    Created      = created_dt,
    Borough,
    LocationType = fct_lump_n(`Location Type`, 8),
    Latitude, Longitude,
    month        = floor_date(Created, "month")
  )

# 3. Fetch 2023 borough populations via ACS (needs CENSUS_API_KEY)
census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)
boro_pop <- get_acs(
  geography = "county",
  variables = c(pop_tot = "B01003_001"),
  year      = 2023,
  state     = "NY",
  county    = c("Bronx","Kings","New York","Queens","Richmond"),
  output    = "wide", geometry = FALSE
) %>%
  rename(population = pop_totE) %>%
  mutate(Borough = recode(
    NAME,
    "Bronx County, New York"    = "Bronx",
    "Kings County, New York"    = "Brooklyn",
    "New York County, New York" = "Manhattan",
    "Queens County, New York"   = "Queens",
    "Richmond County, New York" = "Staten Island"
  )) %>%
  select(Borough, population)

# 4. Compute calls per 10,000 residents by borough
borough_rates <- rats_ready %>%
  count(Borough, name = "calls") %>%
  left_join(boro_pop, by = "Borough") %>%
  mutate(rate_per_10k = calls / population * 10000)

# 5. Write out both files for Tableau
write_csv(rats_ready,    "data/processed/rats_ready.csv")
write_csv(borough_rates, "data/processed/borough_rates.csv")
message("Wrote rats_ready.csv and borough_rates.csv")
