# ───────────────────────────────────────────────────────────
# Script: 042_rat_pop_boro.R
# Purpose: Allocate citywide rat-population estimates to boroughs by call volume
# Inputs:  
#   • output/yearly_rat_population.csv  
#   • data/processed/rats_ready.csv  
# Outputs:  
#   • output/boro_yearly_rat_population.csv  
# Depends: readr, dplyr, lubridate  
# ───────────────────────────────────────────────────────────

# 1. Load libraries
library(readr)
library(dplyr)
library(lubridate)

# 2. Load citywide annual rat-population estimates
annual <- read_csv("output/yearly_rat_population.csv", show_col_types = FALSE)

# 3. Load cleaned rat-call data and extract year
rats <- read_csv("data/processed/rats_ready.csv", show_col_types = FALSE) %>%
  mutate(year = year(ymd_hms(Created))) %>%
  filter(year <= 2024, !is.na(Borough))

# 4. Sum calls by borough and year
calls_by_boro <- rats %>%
  group_by(Borough, year) %>%
  summarise(calls = n(), .groups = "drop")

# 5. Compute total calls per year
total_calls <- calls_by_boro %>%
  group_by(year) %>%
  summarise(calls_total = sum(calls), .groups = "drop")

# 6. Allocate rat counts (and CI) proportionally by call share
boro_rats <- calls_by_boro %>%
  left_join(total_calls, by = "year") %>%
  left_join(annual %>% select(year, estimated_rats, rats_low, rats_high),
            by = "year") %>%
  mutate(
    rats_est      = estimated_rats * (calls / calls_total),
    rats_est_low  = rats_low       * (calls / calls_total),
    rats_est_high = rats_high      * (calls / calls_total)
  ) %>%
  select(
    Borough, year, calls, calls_total,
    estimated_rats, rats_low, rats_high,
    rats_est, rats_est_low, rats_est_high
  )

# 7. Write out borough-level rat-population CSV
write_csv(boro_rats, "output/boro_yearly_rat_population.csv")
message("Wrote output/boro_yearly_rat_population.csv (", nrow(boro_rats), " rows)")
