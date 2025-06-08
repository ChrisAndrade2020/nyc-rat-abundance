# 031_qhcr_model.R
# -----------------------------------------------------------------------------
# Build quarterly QHCR model for rat abundance by Community District (CD_ID)
# Steps:
# 1) Read enriched sightings (with CD_ID)
# 2) Assign each sighting to a quarter
# 3) Build capture histories (counts) by CD_ID × quarter
# 4) Fit Stan-based QHCR model
# 5) Export posterior summaries to CSV (with correct CD_ID mapping)
# -----------------------------------------------------------------------------

# 0) Libraries
library(sf)
library(dplyr)
library(tidyr)
library(lubridate)
library(rstan)
library(posterior)
library(readr)
library(stringr)

# 1) Load enriched rat sightings
rats_sf <- sf::st_read(
  "output/rats_enriched.geojson",
  quiet = TRUE
) %>%
  st_drop_geometry()

# 2) Assign each sighting to a quarter
rats_q <- rats_sf %>%
  mutate(
    call_date = ymd_hms(created_dt),  # parse the actual date-time field
    quarter   = floor_date(call_date, unit = "quarter")
  ) %>%
  filter(!is.na(CD_ID))

# 3) Build capture history matrix
districts <- sort(unique(rats_q$CD_ID))
occasions <- sort(unique(rats_q$quarter))

cap_hist <- rats_q %>%
  group_by(CD_ID, quarter) %>%
  summarise(calls = n(), .groups = "drop") %>%
  complete(CD_ID = districts, quarter = occasions, fill = list(calls = 0)) %>%
  arrange(match(CD_ID, districts), quarter) %>%
  pivot_wider(names_from = quarter, values_from = calls)

# Convert to matrix for Stan
count_matrix <- as.matrix(cap_hist[, as.character(occasions)])

# 4) Prepare data for Stan
total_districts <- length(districts)
total_occasions <- length(occasions)
stan_data <- list(
  D = total_districts,
  T = total_occasions,
  y = count_matrix
)

# 5) Fit QHCR model
rstan_options(auto_write = TRUE)
options(mc.cores = parallel::detectCores())
stan_mod <- rstan::stan_model("stan/qhcr_model.stan")
fit <- rstan::sampling(
  stan_mod,
  data   = stan_data,
  iter   = 2000,
  chains = 4
)

# 6) Extract posterior summaries and map back to actual CD_ID values
# 'lambda[d]' in Stan corresponds to districts[d]
post <- as_draws_df(fit)

lambda_summ <- post %>%
  select(starts_with("lambda[")) %>%
  summarise_draws(
    mean,
    ~quantile(.x, c(0.025, 0.975))
  ) %>%
  rename(
    estimate = mean,
    lower    = `2.5%`,
    upper    = `97.5%`
  ) %>%
  mutate(
    # extract the Stan index from variable name (e.g., "lambda[3]")
    idx = as.integer(str_extract(variable, "(?<=\\[)\\d+(?=\\])")),
    CD_ID = districts[idx]
  ) %>%
  select(CD_ID, estimate, lower, upper)

# 7) Export to CSV
write_csv(lambda_summ, "output/district_qhcr.csv")
message("✅ QHCR model complete – wrote output/district_qhcr.csv")
