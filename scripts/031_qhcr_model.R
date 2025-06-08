# 031_qhcr_model.R
# -----------------------------------------------------------------------------
# Build quarterly QHCR (quantitative hierarchical capture–recapture) model
# for rat abundance by Community District (CD_ID).
# 1) Read enriched sightings (with CD_ID)
# 2) Assign each sighting to a quarter
# 3) Build capture histories (counts) by CD_ID × quarter
# 4) Fit the Stan-based QHCR model
# 5) Export posterior summaries to CSV
# -----------------------------------------------------------------------------

# 0) Libraries ---------------------------------------------------------------
library(sf)
library(dplyr)
library(tidyr)
library(lubridate)
library(rstan)
library(posterior)
library(readr)

# 1) Load enriched rat sightings ---------------------------------------------
rats_sf <- sf::st_read(
  "output/rats_enriched.geojson",
  quiet = TRUE
) %>%
  st_drop_geometry()

# 2) Assign each call to a quarter -------------------------------------------
rats_q <- rats_sf %>%
  mutate(
    call_date = ymd_hms(call_date),
    quarter  = floor_date(call_date, unit = "quarter")
  ) %>%
  filter(!is.na(CD_ID))

# 3) Build capture history matrix --------------------------------------------
# Identify unique districts and occasions
districts <- sort(unique(rats_q$CD_ID))
occasions <- sort(unique(rats_q$quarter))

# Count sightings per district × quarter
cap_hist <- rats_q %>%
  group_by(CD_ID, quarter) %>%
  summarise(calls = n(), .groups = "drop") %>%
  complete(
    CD_ID  = districts,
    quarter = occasions,
    fill = list(calls = 0)
  ) %>%
  arrange(match(CD_ID, districts), quarter) %>%
  pivot_wider(
    names_from  = quarter,
    values_from = calls
  )

# Convert to matrix for Stan
count_matrix <- as.matrix(cap_hist[ , as.character(occasions)])

# 4) Prepare data list for Stan ----------------------------------------------
stan_data <- list(
  D = nrow(count_matrix),     # number of districts
  T = ncol(count_matrix),     # number of capture occasions (quarters)
  y = count_matrix            # counts matrix
)

# 5) Fit the QHCR model ------------------------------------------------------
# Ensure you have a Stan model at `stan/qhcr_model.stan`
stan_model <- rstan::stan_model("stan/qhcr_model.stan")
fit <- rstan::sampling(
  object = stan_model,
  data   = stan_data,
  iter   = 2000,
  chains = 4,
  cores  = parallel::detectCores()
)