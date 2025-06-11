# Allocate the citywide rat‐population estimate (and CI) to each borough
# in proportion to 311 call‐volume, by year (2010–2024).
#
# Input:
#  • output/yearly_rat_population.csv
#      (columns: year, estimated_rats, rats_low, rats_high)
#  • data/processed/rats_ready.csv
#      (must include: Created Date, Borough)
#
# Output:
#  • output/boro_yearly_rat_population.csv
#    columns: Borough, year, calls, calls_total, 
#             estimated_rats, rats_low, rats_high

library(readr)
library(dplyr)
library(lubridate)

# 1) Load the citywide rat‐population estimates -------------------------------
annual <- read_csv("output/yearly_rat_population.csv", show_col_types = FALSE)

# 2) Load raw 311 rat‐call data -----------------------------------------------
rats <- read_csv("data/processed/rats_ready.csv", show_col_types = FALSE) %>%
  mutate(year = year(mdy_hms(`Created`))) %>%
  filter(year <= 2024)

# 3) Sum calls by borough & year ----------------------------------------------
calls_by_boro <- rats %>%
  filter(!is.na(Borough)) %>%
  group_by(Borough, year) %>%
  summarise(calls = n(), .groups = "drop")

# 4) Compute total calls per year ---------------------------------------------
total_calls <- calls_by_boro %>%
  group_by(year) %>%
  summarise(calls_total = sum(calls), .groups = "drop")

# 5) Allocate rat counts + CI to borough --------------------------------------
boro_rats <- calls_by_boro %>%
  left_join(total_calls, by = "year") %>%
  left_join(annual %>% select(year, estimated_rats, rats_low, rats_high),
            by = "year") %>%
  mutate(
    rats_est    = estimated_rats * (calls / calls_total),
    rats_est_low= rats_low       * (calls / calls_total),
    rats_est_high= rats_high     * (calls / calls_total)
  ) %>%
  select(Borough, year, calls, calls_total,
         estimated_rats, rats_low, rats_high,
         rats_est, rats_est_low, rats_est_high)

# 6) Write out ----------------------------------------------------------------
write_csv(boro_rats, "output/boro_yearly_rat_population.csv")
message("✅ Wrote output/boro_yearly_rat_population.csv with ", nrow(boro_rats), " rows")
