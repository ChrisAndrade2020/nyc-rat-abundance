# ───────────────────────────────────────────────────────────
# Script: 031_qhcr_model.R
# Purpose: Fit quarterly QHCR model for rat abundance by community district
# Inputs:  output/rats_enriched.geojson
#          stan/qhcr_model_upgraded.stan
# Outputs: output/qhcr_draws.rds
#          output/district_qhcr_v2.csv
#          output/quarter_effects.csv
# Depends: sf, dplyr, tidyr, lubridate, rstan, posterior, readr, stringr
# ───────────────────────────────────────────────────────────

# 1. Load necessary libraries
library(sf)
library(dplyr)
library(tidyr)
library(lubridate)
library(rstan)
library(posterior)
library(readr)
library(stringr)

# 2. Read enriched rat sightings, drop spatial component
rats_sf <- sf::st_read("output/rats_enriched.geojson", quiet = TRUE) %>%
  st_drop_geometry()

# 3. Assign each sighting to its calendar quarter
rats_q <- rats_sf %>%
  mutate(
    call_date = ymd_hms(created_dt),
    quarter   = floor_date(call_date, unit = "quarter")
  ) %>%
  filter(!is.na(CD_ID))

# 4. Build capture history: counts by CD_ID × quarter
districts <- sort(unique(rats_q$CD_ID))
occasions <- sort(unique(rats_q$quarter))
cap_hist <- rats_q %>%
  group_by(CD_ID, quarter) %>%
  summarise(calls = n(), .groups = "drop") %>%
  complete(CD_ID = districts, quarter = occasions, fill = list(calls = 0)) %>%
  arrange(match(CD_ID, districts), quarter) %>%
  pivot_wider(names_from = quarter, values_from = calls)

# 5. Prepare data list for Stan
count_matrix      <- as.matrix(cap_hist[, as.character(occasions)])
total_districts   <- length(districts)
total_occasions   <- length(occasions)
stan_data <- list(D = total_districts, T = total_occasions, y = count_matrix)

# 6. Compile and fit the QHCR Stan model
stan_mod <- rstan::stan_model("stan/qhcr_model_upgraded.stan")
fit      <- rstan::sampling(
  stan_mod,
  data    = stan_data,
  iter    = 2000,
  chains  = 4,
  control = list(adapt_delta = 0.9, max_treedepth = 12)
)

# 7. Extract full posterior draws and save as RDS
post <- as_draws_df(fit)
write_rds(post, "output/qhcr_draws.rds")

# 8. Summarize district‐level abundance (lambda) and write CSV
lambda_summ <- post %>%
  select(starts_with("lambda[")) %>%
  summarise_draws(mean, ~quantile(.x, c(0.025, 0.975))) %>%
  rename(estimate = mean, lower = `2.5%`, upper = `97.5%`) %>%
  mutate(
    idx   = as.integer(str_extract(variable, "(?<=\\[)\\d+(?=\\])")),
    CD_ID = districts[idx]
  ) %>%
  select(CD_ID, estimate, lower, upper)
write_csv(lambda_summ, "output/district_qhcr_v2.csv")

# 9. Summarize seasonal quarter effects (delta) and write CSV
delta_summ <- post %>%
  select(starts_with("delta[")) %>%
  summarise_draws(mean, ~quantile(.x, c(0.025, 0.975))) %>%
  rename(estimate = mean, lower = `2.5%`, upper = `97.5%`) %>%
  mutate(
    idx     = as.integer(str_extract(variable, "(?<=\\[)\\d+(?=\\])")),
    quarter = occasions[idx]
  ) %>%
  select(quarter, estimate, lower, upper)
write_csv(delta_summ, "output/quarter_effects.csv")

message("✅ QHCR model complete – wrote output files")
