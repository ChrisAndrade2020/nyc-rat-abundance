# Purpose: From cleaned rats_clean.csv, derive:
#    • rats_ready.csv    (for map, trend line, location-type bar)
#    • borough_rates.csv (for borough-rate bar)

# 0) Install & load packages (run install.packages() once, then comment out)
# install.packages(c("readr","dplyr","lubridate","forcats","stringr","tidycensus"))
library(readr)
library(dplyr)
library(lubridate)
library(forcats)
library(stringr)
library(tidycensus)

# 1) Read in your cleaned rats dataset
rats_clean <- read_csv("data/processed/rats_clean.csv") %>%
  # Title-case Borough so it matches ACS lookup
  mutate(Borough = str_to_title(Borough))

# 2) Build the "ready" table for three viz tabs
rats_ready <- rats_clean %>%
  transmute(
    UniqueKey    = `Unique Key`,
    Created      = created_dt,
    Borough      = Borough,
    LocationType = `Location Type`,    
    Latitude     = Latitude,
    Longitude    = Longitude,
    # derive a monthly field for trends & map Pages
    month        = floor_date(Created, "month"),
    # lump to top 8 location types
    LocationType = fct_lump_n(LocationType, 8)
  )

# 3) Fetch borough (= county) population from ACS 2019–2023
census_api_key(Sys.getenv("CENSUS_API_KEY"), install = FALSE)
message("🔄 Downloading borough populations from ACS (2019–2023)…")
boro_pop <- get_acs(
  geography = "county",
  variables = c(pop_tot = "B01003_001"),
  year      = 2023,
  state     = "NY",
  county    = c("Bronx","Kings","New York","Queens","Richmond"),
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

# 4) Compute borough call-rates
borough_rates <- rats_ready %>%
  count(Borough, name = "calls") %>%
  left_join(boro_pop, by = "Borough") %>%
  mutate(rate_per_10k = calls / population * 10000)

# 5) Write out for Tableau
write_csv(rats_ready,    "data/processed/rats_ready.csv")
write_csv(borough_rates, "data/processed/borough_rates.csv")

message("✅ rats_ready.csv and borough_rates.csv written to data/processed/")
