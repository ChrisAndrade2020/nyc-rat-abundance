# Estimate NYC rat populations by year (2010–2024), with 95% CI,
# anchored to 2010 = 2,000,000 rats, using QHCR model outputs.
#
# Inputs:
#  • output/district_qhcr_v2.csv    (columns: CD_ID, estimate, lower, upper)
#  • output/quarter_effects.csv     (columns: quarter, estimate, lower, upper)
#
# Output:
#  • output/yearly_rat_population.csv
#    columns:
#      year,
#      mean_qhcr,   mean_low,   mean_high,
#      rat_index,   rat_index_low,   rat_index_high,
#      estimated_rats,   rats_low,   rats_high

library(readr)
library(dplyr)
library(lubridate)

# 1) Read Stan summaries ------------------------------------------------------
lambda <- read_csv("output/district_qhcr_v2.csv", show_col_types = FALSE)
delta  <- read_csv("output/quarter_effects.csv",  show_col_types = FALSE)

# 2) Exponentiate log‐scale outputs → linear abundances/factors ----------------
lambda <- lambda %>%
  mutate(
    abund_est  = exp(estimate),
    abund_low  = exp(lower),
    abund_high = exp(upper)
  )

delta <- delta %>%
  mutate(
    factor_est  = exp(estimate),
    factor_low  = exp(lower),
    factor_high = exp(upper)
  )

# 3) Compute citywide baseline abundances (constant) --------------------------
lambda_bar_est  <- mean(lambda$abund_est,  na.rm = TRUE)
lambda_bar_low  <- mean(lambda$abund_low,  na.rm = TRUE)
lambda_bar_high <- mean(lambda$abund_high, na.rm = TRUE)

# 4) Build quarterly citywide abundance --------------------------------------
delta_q <- delta %>%
  mutate(
    year        = year(as.Date(quarter)),
    q_abund_est = lambda_bar_est  * factor_est,
    q_abund_low = lambda_bar_low  * factor_low,
    q_abund_high= lambda_bar_high * factor_high
  )

# 5) Aggregate to annual means ------------------------------------------------
annual <- delta_q %>%
  group_by(year) %>%
  summarise(
    mean_qhcr = mean(q_abund_est, na.rm = TRUE),
    mean_low  = mean(q_abund_low, na.rm = TRUE),
    mean_high = mean(q_abund_high, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(year)

# 6) Compute rat_index relative to 2010 ----------------------------------------
baseline_est  <- annual$mean_qhcr[annual$year == 2010]
baseline_low  <- annual$mean_low[annual$year == 2010]
baseline_high <- annual$mean_high[annual$year == 2010]

annual <- annual %>%
  mutate(
    rat_index      = mean_qhcr      / baseline_est,
    rat_index_low  = mean_low       / baseline_low,
    rat_index_high = mean_high      / baseline_high
  )

# 7) Estimate absolute rats (anchor: 2010 = 2,000,000) ------------------------
anchor_rats <- 2e6

annual_out <- annual %>%
  filter(year <= 2024) %>%  # drop incomplete 2025
  mutate(
    estimated_rats = rat_index      * anchor_rats,
    rats_low       = rat_index_low  * anchor_rats,
    rats_high      = rat_index_high * anchor_rats
  )

# 8) Write output for Tableau -------------------------------------------------
write_csv(annual_out, "output/yearly_rat_population.csv")
message("✅ Wrote output/yearly_rat_population.csv with ", nrow(annual_out), " rows")
