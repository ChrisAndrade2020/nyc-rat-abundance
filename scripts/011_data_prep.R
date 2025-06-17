# ───────────────────────────────────────────────────────────
# Script: 011_data_prep.R
# Purpose: Read raw 311 rat-related calls, clean & flag for QA
# Inputs:  data/raw/311_Service_Requests_*.csv
# Outputs: data/processed/rats_clean.csv
# Depends: vroom, dplyr, stringr, lubridate, readr
# ───────────────────────────────────────────────────────────

# 0. Load required packages (install once, then comment out the installs)
# install.packages(c("vroom","dplyr","stringr","lubridate","readr"))
library(vroom)
library(dplyr)
library(stringr)
library(lubridate)
library(readr)

# 1. Point to the raw 311 CSV file
data_path <- "data/raw/311_Service_Requests_from_2010_to_Present_20250526.csv"

# 2. Preview 5,000 rows to verify column names and types
preview <- vroom(
  file       = data_path,
  n_max      = 5000,
  col_select = c(
    "Unique Key","Created Date","Closed Date","Status",
    "Location Type","Incident Zip","Borough","BBL",
    "Latitude","Longitude","Descriptor"
  )
)
print(head(preview, 5)); print(names(preview))

# 3. Read and clean all rows:
#    - Parse dates, compute days open (using snapshot date for still-open tickets)
#    - Classify each call as direct sighting, sign of rats, or other
#    - Keep only rat/rodent-related descriptors
rats_clean <- vroom(
  file       = data_path,
  col_select = c(
    "Unique Key","Created Date","Closed Date","Status",
    "Location Type","Incident Zip","Borough","BBL",
    "Latitude","Longitude","Descriptor"
  ),
  col_types = cols(
    `Unique Key` = col_character(),
    `Created Date` = col_character(),
    `Closed Date` = col_character(),
    Status = col_character(),
    `Location Type` = col_character(),
    `Incident Zip` = col_character(),
    Borough = col_character(),
    BBL = col_character(),
    Latitude = col_double(),
    Longitude = col_double(),
    Descriptor = col_character()
  )
) %>%
  mutate(
    created_dt    = mdy_hms(`Created Date`),
    closed_dt_raw = mdy_hms(`Closed Date`),
    closed_dt     = if_else(
      closed_dt_raw < as_datetime("2010-01-01"),
      NA_POSIXct_,
      closed_dt_raw
    ),
    days_open     = as.numeric(
      if_else(
        !is.na(closed_dt),
        difftime(closed_dt, created_dt, units = "days"),
        difftime(as.Date("2025-05-26"), as.Date(created_dt), units = "days")
      ),
      units = "days"
    ),
    event_type    = case_when(
      str_detect(Descriptor, regex("sighting", ignore_case = TRUE)) ~ "direct",
      str_detect(Descriptor, regex("dropp|burrow", ignore_case = TRUE)) ~ "sign",
      TRUE ~ "other"
    )
  ) %>%
  select(
    `Unique Key`, created_dt, closed_dt, days_open,
    event_type,
    Status, `Location Type`, `Incident Zip`, Borough, BBL,
    Latitude, Longitude, Descriptor
  ) %>%
  filter(
    str_starts(Descriptor, regex("Rat|Rodent|Mouse", ignore_case = TRUE)) |
      str_detect(Descriptor, regex("dropp|burrow|bait|nest|runway|gnaw", ignore_case = TRUE))
  )

# 4. Save the cleaned rat-related calls for downstream use
write_csv(rats_clean, "data/processed/rats_clean.csv")
message("Saved cleaned data to data/processed/rats_clean.csv")
