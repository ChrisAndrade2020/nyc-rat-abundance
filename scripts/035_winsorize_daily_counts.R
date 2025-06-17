# ───────────────────────────────────────────────────────────
# Script: 035_winsorize_daily_counts.R
# Purpose: Cap (winsorize) daily counts at the 99th percentile for visualization
# Inputs:  output/daily_rats_by_cd.csv
# Outputs: output/daily_rats_by_cd_win.csv
# Depends: dplyr, readr
# ───────────────────────────────────────────────────────────

# 1. Load data-wrangling libraries
library(dplyr)
library(readr)

# 2. Read daily counts CSV
daily_cd <- read_csv("output/daily_rats_by_cd.csv", show_col_types = FALSE)

# 3. Determine the winsorization threshold (99th percentile)
P      <- 0.99
cap_val <- quantile(daily_cd$calls, P, na.rm = TRUE)
message("Capping calls at the ", P*100, "th percentile: ", cap_val)

# 4. Add capped value and flag to each row
daily_cd <- daily_cd %>%
  mutate(
    calls_capped = pmin(calls, cap_val),
    capped_flag  = calls > cap_val
  )

# 5. Write out the winsorized counts CSV
write_csv(daily_cd, "output/daily_rats_by_cd_win.csv")
message("Wrote winsorized daily counts to output/daily_rats_by_cd_win.csv")
