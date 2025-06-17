# ───────────────────────────────────────────────────────────
# Script: 036_deciles.R
# Purpose:  
#   1. Compute median call rates per income decile (per quarter)  
#   2. Compute citywide median and mean call rates per quarter  
#   3. Compute average + total calls per income decile × quarter  
# Inputs:  
#   • output/bg_calls_ACS_summary.csv  
#   • output/rats_enriched.geojson  
# Outputs:  
#   • output/decile_call_rates_vfinal.csv  
#   • output/citywide_call_rate_qtr.csv  
#   • output/decile_call_counts.csv  
# Depends: sf, dplyr, readr, lubridate  
# ───────────────────────────────────────────────────────────

library(sf)
library(dplyr)
library(readr)
library(lubridate)

# — Paths & parameters -------------------------------------
rats_path  <- "output/rats_enriched.geojson"
bg_path    <- "output/bg_calls_ACS_summary.csv"
out_dir    <- "output"
n_quarters <- 58  # quarters from 2010–Q1 to 2025–Q2

# 1. Load and prep BG summary for deciles ---------------
bg <- read_csv(bg_path, show_col_types = FALSE) %>%
  mutate(
    GEOID                = as.character(GEOID),
    income_decile        = ntile(med_income, 10),
    rate_per_qtr_per_10k = rate_per_10k / n_quarters
  ) %>%
  select(GEOID, income_decile, rate_per_qtr_per_10k, pop_tot)

# 2. Compute & write median rate per decile -------------
decile_rates <- bg %>%
  group_by(income_decile) %>%
  summarise(
    median_rate_per_qtr = median(rate_per_qtr_per_10k, na.rm = TRUE),
    .groups = "drop"
  )
write_csv(decile_rates, file.path(out_dir, "decile_call_rates_vfinal.csv"))

# 3. Compute & write citywide summary -------------------
rats <- st_read(rats_path, quiet = TRUE) %>% st_drop_geometry() %>%
  mutate(
    created_dt = ymd_hms(created_dt),
    quarter    = paste0(year(created_dt), "-Q", quarter(created_dt))
  )
city_pop_10k <- sum(bg$pop_tot, na.rm = TRUE) / 1e4
city_qtr <- rats %>%
  group_by(quarter) %>%
  summarise(calls = n(), .groups = "drop") %>%
  mutate(rate_per_10k = calls / city_pop_10k)
city_stats <- city_qtr %>%
  summarise(
    median_rate_per_qtr = median(rate_per_10k, na.rm = TRUE),
    mean_rate_per_qtr   = mean(rate_per_10k,   na.rm = TRUE),
    .groups = "drop"
  )
write_csv(city_stats, file.path(out_dir, "citywide_call_rate_qtr.csv"))

# 4. Compute & write decile × quarter call counts -------
rats2 <- st_read(rats_path, quiet = TRUE) %>%
  st_drop_geometry() %>%
  mutate(
    # ensure GEOID is character to match bg$GEOID
    GEOID      = as.character(GEOID),
    created_dt = ymd_hms(created_dt),
    quarter    = paste0(year(created_dt), "-Q", quarter(created_dt))
  ) %>%
  left_join(bg %>% select(GEOID, income_decile), by = "GEOID")

decile_counts <- rats2 %>%
  group_by(income_decile, quarter) %>%
  summarise(calls = n(), .groups = "drop") %>%
  group_by(income_decile) %>%
  summarise(
    avg_calls_per_quarter = mean(calls),
    total_calls           = sum(calls),
    .groups = "drop"
  )

write_csv(decile_counts, file.path(out_dir, "decile_call_counts.csv"))

message("✅ Wrote decile rates, city stats, and decile call counts to ", out_dir)
