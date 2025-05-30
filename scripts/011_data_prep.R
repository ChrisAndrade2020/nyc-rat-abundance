# Purpose: Clean raw 311 rat‐sighting data, select key fields, derive month & lump top location types,
#          compute borough‐level call counts and rates per 10k using ACS population, 
#          and write out rats_ready.csv and borough_rates.csv.

# 0) Install & load packages (run install.packages() once, then comment it out)
install.packages(c("vroom", "dplyr", "stringr", "lubridate", "readr"))
library(vroom)
library(dplyr)
library(stringr)
library(lubridate)
library(readr)

# 1) Path to raw 311 data
data_path <- "data/raw/311_Service_Requests_from_2010_to_Present_20250526.csv"

# 2) Preview 5 000 rows to confirm columns
rats_5k_sample <- vroom(
  file      = data_path,
  n_max     = 5000,
  col_select = c(
    "Unique Key", "Created Date", "Closed Date", "Status",
    "Resolution Description", "Location Type",
    "Incident Zip", "Borough", "BBL",
    "Latitude", "Longitude", "Descriptor"
  )
)
# Inspect
print(head(rats_5k_sample, 5))
print(names(rats_5k_sample))

# 3) Parse dates, flag bad closes (pre-2010), compute days_open as of 2025-05-26,
#    and also flag stale_open if days_open > 365

# a) Define your fixed sentinel & snapshot dates
sentinel_date <- as_datetime("2010-01-01 00:00:00")  # anything before this is bogus
snapshot_date <- as.Date("2025-05-26")               # cut-off for still-open

rats_clean <- vroom(
  file       = data_path,
  col_select = c(
    "Unique Key", "Created Date", "Closed Date", "Status",
    "Resolution Description", "Location Type",
    "Incident Zip", "Borough", "BBL",
    "Latitude", "Longitude", "Descriptor"
  ),
  col_types = cols(
    `Unique Key`             = col_character(),
    `Created Date`           = col_character(),
    `Closed Date`            = col_character(),
    Status                   = col_character(),
    `Resolution Description` = col_character(),
    `Location Type`          = col_character(),
    `Incident Zip`           = col_character(),
    Borough                  = col_character(),
    BBL                      = col_character(),
    Latitude                 = col_double(),
    Longitude                = col_double(),
    Descriptor               = col_character()
  )
) %>%
  mutate(
    # parse raw strings
    created_dt    = mdy_hms(`Created Date`),
    closed_dt_raw = mdy_hms(`Closed Date`),
    
    # flag any closed before sentinel_date
    bad_close     = closed_dt_raw < sentinel_date,
    
    # recode closed_dt: NA if bad_close or truly missing
    closed_dt     = if_else(bad_close, NA_POSIXct_, closed_dt_raw),
    
    # compute days_open: real closes vs snapshot for pending
    days_open     = as.numeric(
      if_else(
        !is.na(closed_dt),
        difftime(closed_dt, created_dt, units = "days"),
        difftime(snapshot_date, as.Date(created_dt), units = "days")
      ),
      units = "days"
    ),
    
    # flag extremely long‐open tickets (> 365 days)
    stale_open    = days_open > 365,
    
    # classify event type for modeling later
    event_type = case_when(
      str_detect(Descriptor, regex("sighting",   ignore_case = TRUE)) ~ "direct",
      str_detect(Descriptor, regex("dropp|burrow",ignore_case = TRUE)) ~ "sign",
      TRUE                                                            ~ "other"
    )
  ) %>%
  # keep only the fields we need
  select(
    `Unique Key`, created_dt, closed_dt, days_open,
    bad_close, stale_open, event_type,
    Status, `Resolution Description`,
    `Location Type`, `Incident Zip`, Borough, BBL,
    Latitude, Longitude, Descriptor
  ) %>%
  # filter to your rodent-related reports
  filter(
    str_starts(Descriptor, regex("Rat|Rodent|Mouse",   ignore_case = TRUE)) |
      str_detect(Descriptor,   regex("dropp|burrow|bait|nest|runway|gnaw", ignore_case = TRUE))
  )

# 4) Final check
message("✅ Clean & flagged: ", nrow(rats_clean), " rows; ",
        sum(rats_clean$bad_close), " bad_close, ",
        sum(rats_clean$stale_open), " stale_open")
glimpse(rats_clean)

# 5) Export cleaned rats dataset
write_csv(
  rats_clean,
  "data/processed/rats_clean.csv"
)
message("✏️ Saved rats_clean.csv to data/processed/") 

