# ───────────────────────────────────────────────────────────
# Script: 041_rat_pop_est.R
# Purpose: Generate yearly rat-population indices and absolute counts from QHCR model draws
# Inputs:  
#   • output/qhcr_draws.rds  
#   • output/quarter_effects.csv  
# Outputs:  
#   • output/yearly_rat_population.csv  
# Depends: readr, dplyr, lubridate, posterior, tidyr  
# ───────────────────────────────────────────────────────────

# 1. Load libraries
library(readr)
library(dplyr)
library(lubridate)
library(posterior)
library(tidyr)

# 2. Read posterior draws and quarter metadata
draws     <- read_rds("output/qhcr_draws.rds")
occasions <- read_csv("output/quarter_effects.csv", show_col_types = FALSE)$quarter

# 3. Compute city_mean per draw from lambda
lambda_draws <- draws %>%
  select(starts_with("lambda[")) %>%
  mutate(draw = row_number()) %>%
  pivot_longer(-draw, names_to="param", values_to="log_lambda") %>%
  mutate(lambda = exp(log_lambda)) %>%
  group_by(draw) %>%
  summarise(city_mean = mean(lambda), .groups="drop")

# 4. Expand delta draws, map to quarters, compute per-quarter abundance
delta_draws <- draws %>%
  select(starts_with("delta[")) %>%
  mutate(draw = row_number()) %>%
  pivot_longer(-draw, names_to="param", values_to="log_delta") %>%
  mutate(
    q_idx   = as.integer(gsub(".*\\[(\\d+)\\].*", "\\1", param)),
    quarter = as.Date(occasions[q_idx]),
    factor  = exp(log_delta),
    year    = year(quarter)
  )
city_q <- delta_draws %>%
  left_join(lambda_draws, by="draw") %>%
  mutate(q_abund = city_mean * factor)

# 5. Compute yearly mean and index relative to 2010 per draw
yearly_draw <- city_q %>%
  group_by(draw, year) %>%
  summarise(mean_qhcr = mean(q_abund), .groups="drop") %>%
  group_by(draw) %>%
  mutate(rat_index = mean_qhcr / mean_qhcr[year == 2010]) %>%
  ungroup()

# 6. Summarise posterior quantiles per year
yearly_ci <- yearly_draw %>%
  group_by(year) %>%
  summarise(
    rat_index      = mean(rat_index),
    rat_index_low  = quantile(rat_index, 0.025),
    rat_index_high = quantile(rat_index, 0.975),
    .groups        = "drop"
  ) %>%
  filter(year <= 2024)

# 7. Convert index to absolute rat counts (anchor 2010 = 2M)
anchor_rats <- 2e6
yearly_out <- yearly_ci %>%
  mutate(
    estimated_rats = rat_index      * anchor_rats,
    rats_low       = rat_index_low  * anchor_rats,
    rats_high      = rat_index_high * anchor_rats
  )

# 8. Write out for Tableau
write_csv(yearly_out, "output/yearly_rat_population.csv")
message("Wrote output/yearly_rat_population.csv (", nrow(yearly_out), " rows)")
