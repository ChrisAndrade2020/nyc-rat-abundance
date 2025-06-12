# Generates yearly rat-population estimates with 95% CI via full-posterior draws.
#
# Inputs:
#  • output/qhcr_draws.rds
#  • output/quarter_effects.csv
# Output:
#  • output/yearly_rat_population.csv
# Columns:
#    year, rat_index, rat_index_low, rat_index_high,
#    estimated_rats, rats_low, rats_high

library(readr)
library(dplyr)
library(lubridate)
library(posterior)
library(tidyr)

# 1) Load posterior draws & quarter metadata
draws     <- read_rds("output/qhcr_draws.rds")
occasions <- read_csv("output/quarter_effects.csv", show_col_types = FALSE)$quarter

# 2) Compute city_mean per draw from lambda draws
lambda_draws <- draws %>%
  select(starts_with("lambda[")) %>%
  mutate(draw = row_number()) %>%
  pivot_longer(-draw, names_to="param", values_to="log_lambda") %>%
  mutate(lambda = exp(log_lambda)) %>%
  group_by(draw) %>%
  summarise(city_mean = mean(lambda), .groups="drop")

# 3) Expand delta draws to quarters, compute q_abund
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

# 4) Yearly mean per draw
yearly_draw <- city_q %>%
  group_by(draw, year) %>%
  summarise(
    mean_qhcr = mean(q_abund),
    .groups   = "drop"
  ) %>%
  group_by(draw) %>%
  mutate(
    rat_index = mean_qhcr / mean_qhcr[year == 2010]
  ) %>%
  ungroup()

# 5) Summarise posterior quantiles per year
yearly_ci <- yearly_draw %>%
  group_by(year) %>%
  summarise(
    rat_index      = mean(rat_index),
    rat_index_low  = quantile(rat_index, 0.025),
    rat_index_high = quantile(rat_index, 0.975),
    .groups        = "drop"
  ) %>%
  filter(year <= 2024)

# 6) Anchor 2010 = 2,000,000 rats → absolute counts
anchor_rats <- 2e6
yearly_out <- yearly_ci %>%
  mutate(
    estimated_rats = rat_index      * anchor_rats,
    rats_low       = rat_index_low  * anchor_rats,
    rats_high      = rat_index_high * anchor_rats
  )

# 7) Write result for Tableau
write_csv(yearly_out, "output/yearly_rat_population.csv")
message("✅ Wrote output/yearly_rat_population.csv (", nrow(yearly_out), " rows)")
