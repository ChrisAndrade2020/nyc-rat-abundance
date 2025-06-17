# Reads the block-group summary → recalculates decile-based median call-rates
# Outputs: output/decile_call_rates_bg.csv
# ————————————————————————————————

library(dplyr)
library(readr)

# 1. Load your block-group ACS summary (must include rate_per_10k & med_income)
bg <- read_csv("output/bg_calls_ACS_summary.csv", show_col_types = FALSE)

# 2. Assign each BG to an income decile based on median household income
bg_deciles <- bg %>%
  filter(!is.na(med_income)) %>%
  mutate(income_decile = ntile(med_income, 10))

# 3. Compute the median BG call-rate per quarter per 10k within each decile
decile_rates_bg <- bg_deciles %>%
  group_by(income_decile) %>%
  summarise(
    median_rate_per_qtr = median(rate_per_10k, na.rm = TRUE),
    .groups = "drop"
  )

# 4. Write out your new decile rates CSV
write_csv(decile_rates_bg, "output/decile_call_rates_bg.csv")

message("✅ Written output/decile_call_rates_bg.csv — ready for Tableau.")
