# Take the cleaned point-level file **rats_clean.csv** and reshape it into two
# artefacts that Tableau needs:
#   • **rats_ready.csv**    – still point‑level, but trimmed to essential fields
#                             and with helper columns (month, lumped LocationType).
#   • **borough_rates.csv** – one row per borough with a calls‑per‑10k‑residents
#                             metric (feeds the bar chart).
#
# One run per data refresh is enough; reruns just overwrite the two outputs.
# -----------------------------------------------------------------------------

## 0) Install + load required packages -----------------------------------------
# install.packages(c("readr", "dplyr", "lubridate", "forcats", "stringr", "tidycensus"))
library(readr)      # read_csv(), write_csv()
library(dplyr)      # mutate(), transmute(), joins …
library(lubridate)  # floor_date()
library(forcats)    # fct_lump_n()
library(stringr)    # str_to_title()
library(tidycensus) # get_acs()

## 1) Read the cleaned dataset --------------------------------------------------
rats_clean <- read_csv("data/processed/rats_clean.csv") %>%
  mutate(
    # Ensure Borough capitalisation matches ACS download later
    Borough = str_to_title(Borough)
  )

## 2) Build *rats_ready* --------------------------------------------------------
#    – Fields that mapping / charting workbooks actually need.
rats_ready <- rats_clean %>%
  transmute(
    UniqueKey    = `Unique Key`,
    Created      = created_dt,
    Borough      = Borough,
    LocationType = `Location Type`,
    Latitude     = Latitude,
    Longitude    = Longitude,
    
    # Collapse to first day of month (keeps timezone quirks away)
    month        = floor_date(Created, "month"),
    
    # Keep the eight most common location types; lump the rest as "Other"
    LocationType = fct_lump_n(LocationType, 8)
  )

## 3) Download 2023 borough populations from ACS -------------------------------
#    You need an API key in the env‑var CENSUS_API_KEY. Grab one at
#    https://api.census.gov/data/key_signup.html and run
#    Sys.setenv(CENSUS_API_KEY = "your_key") once per machine.

census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)
message("🔄 Downloading 2023 borough populations from ACS …")

boro_pop <- get_acs(
  geography = "county",
  variables = c(pop_tot = "B01003_001"),
  year      = 2023,             # 2023 five‑year estimate (~2021‑2023 midpoint)
  state     = "NY",
  county    = c("Bronx", "Kings", "New York", "Queens", "Richmond"),
  output    = "wide",
  geometry  = FALSE
) %>%
  rename(population = pop_totE) %>%
  mutate(
    Borough = case_when(
      NAME == "Bronx County, New York"    ~ "Bronx",
      NAME == "Kings County, New York"    ~ "Brooklyn",
      NAME == "New York County, New York" ~ "Manhattan",
      NAME == "Queens County, New York"   ~ "Queens",
      NAME == "Richmond County, New York" ~ "Staten Island"
    )
  ) %>%
  select(Borough, population)

## 4) Calls per 10k residents ----------------------------------------------------
borough_rates <- rats_ready %>%
  count(Borough, name = "calls") %>%
  left_join(boro_pop, by = "Borough") %>%
  mutate(
    rate_per_10k = calls / population * 10000
  )

## 5) Write outputs -------------------------------------------------------------
write_csv(rats_ready,    "data/processed/rats_ready.csv")
write_csv(borough_rates, "data/processed/borough_rates.csv")

message("✅ Wrote rats_ready.csv and borough_rates.csv to data/processed/")