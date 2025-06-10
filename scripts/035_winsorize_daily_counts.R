#  Reads output/daily_rats_by_cd_checked.csv   (or daily_rats_by_cd.csv)
#  Caps the 'calls' field at the 99th-percentile (adjustable)
#  Writes output/daily_rats_by_cd_win.csv
#
#  In Tableau:
#     Use  calls_capped  for colour / table-calcs
#     Keep  calls        in tooltips so the 229 spike is still visible

library(dplyr)
library(readr)

# ── 1) Read -------------------------------------------------------------------
daily_cd <- read_csv("output/daily_rats_by_cd.csv",
                     show_col_types = FALSE)

# ── 2) Choose a threshold -----------------------------------------------------
P <- 0.9999                     # ← change to 0.995 or 0.975 if you prefer
cap_val <- quantile(daily_cd$calls, P, na.rm = TRUE)

message("Winsorising at the ", P*100, "th percentile: cap = ", cap_val)

# ── 3) Add capped column ------------------------------------------------------
daily_cd <- daily_cd %>%
  mutate(
    calls_capped = pmin(calls, cap_val),
    capped_flag  = calls > cap_val       # TRUE if the original was trimmed
  )

# ── 4) Write out --------------------------------------------------------------
write_csv(daily_cd, "output/daily_rats_by_cd_win.csv")
message("✅ Wrote winsorised daily counts to output/daily_rats_by_cd_win.csv")
