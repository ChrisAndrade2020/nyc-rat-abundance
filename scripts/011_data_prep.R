# Goal: turn the *raw* NYC 311 rat-related CSV into rats_clean. From which we can derive
#       other dataframes into smaller workable csvs
#
# The workflow, in plain English:
#   0. Make sure required packages are installed, then load them.
#   1. Point to the raw CSV (downloaded separately).
#   2. Pull a 5 000-row preview so you can eyeball column names & sample data.
#   3. Read *all* rows, parse dates, add QA/QC flags, classify event types.
#   4. Stick to the columns we actually need and filter to rat/rodent keywords.
#   5. Save the cleaned file for downstream use.
# -----------------------------------------------------------------------------

## 0) Install + load packages ----
#    Run `install.packages()` the *very first* time, then comment it out ✂️.
#    Keeping it here (commented) reminds newcomers what’s needed.
install.packages(c("vroom", "dplyr", "stringr", "lubridate", "readr"))
library(vroom)      # Fast CSV reader (multi-threaded)
library(dplyr)      # Data wrangling verbs (filter/ mutate / summarise …)
library(stringr)    # Regex helpers that read like English
library(lubridate)  # Date-time parsing without tears
library(readr)      # write_csv() for output

## 1) Raw data path ----
#    Hard-coded for now; you might parameterise via config later.
data_path <- "data/raw/311_Service_Requests_from_2010_to_Present_20250526.csv"

## 2) Quick 5k-row peek ----
#    Safety check: confirms schema before loading millions of rows.
rats_5k_sample <- vroom(
  file       = data_path,
  n_max      = 5000,
  col_select = c(
    "Unique Key", "Created Date", "Closed Date", "Status",
    "Resolution Description", "Location Type",
    "Incident Zip", "Borough", "BBL",
    "Latitude", "Longitude", "Descriptor"
  )
)
print(head(rats_5k_sample, 5))
print(names(rats_5k_sample))

## 3) Full ingest + cleaning ----
#    We’ll parse ~10M rows, so be mindful of memory on 🍎/Windows laptops.

# a) Fixed reference dates
sentinel_date <- as_datetime("2010-01-01 00:00:00")  # anything closed *before* 2010 looks wrong
snapshot_date <- as.Date("2025-05-26")               # pretend “today” when ticket is still open

# b) Read the data – narrow to columns we care about & set explicit types
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
    # Parse raw strings to POSIXct – lubridate guesses the format.
    created_dt    = mdy_hms(`Created Date`),
    closed_dt_raw = mdy_hms(`Closed Date`),
    
    # Flag suspicious closes (before NYC started publishing 311: 2010-01-01)
    bad_close     = closed_dt_raw < sentinel_date,
    
    # If closed date is bogus, treat as NA (ticket still open)
    closed_dt     = if_else(bad_close, NA_POSIXct_, closed_dt_raw),
    
    # Compute *days open* – if closed use real diff, else diff to snapshot_date
    days_open     = as.numeric(
      if_else(
        !is.na(closed_dt),
        difftime(closed_dt, created_dt, units = "days"),
        difftime(snapshot_date, as.Date(created_dt), units = "days")
      ),
      units = "days"
    ),
    
    # Flag tickets that have been open > 1 year (possible data issue)
    stale_open    = days_open > 365,
    
    # Categorise the *kind* of rat evidence – may help in modelling later
    event_type = case_when(
      str_detect(Descriptor, regex("sighting",   ignore_case = TRUE)) ~ "direct",  # saw a rat
      str_detect(Descriptor, regex("dropp|burrow", ignore_case = TRUE)) ~ "sign",   # found droppings, nests
      TRUE                                                             ~ "other"
    )
  ) %>%
  
  # Keep only useful columns so downstream files stay slim
  select(
    `Unique Key`, created_dt, closed_dt, days_open,
    bad_close, stale_open, event_type,
    Status, `Resolution Description`,
    `Location Type`, `Incident Zip`, Borough, BBL,
    Latitude, Longitude, Descriptor
  ) %>%
  
  # Focus on rows that look rodent-related (broad regex net)
  filter(
    str_starts(Descriptor, regex("Rat|Rodent|Mouse", ignore_case = TRUE)) |
      str_detect(Descriptor, regex("dropp|burrow|bait|nest|runway|gnaw", ignore_case = TRUE))
  )

## 4) Quick sanity report ----
message(
  "✅ Clean & flagged: ", nrow(rats_clean), " rows; ",
  sum(rats_clean$bad_close), " bad_close; ",
  sum(rats_clean$stale_open), " stale_open"
)
glimpse(rats_clean)

## 5) Write cleaned data to disk ----
write_csv(
  rats_clean,
  "data/processed/rats_clean.csv"
)
message("✏️ Wrote rats_clean.csv to data/processed/") 
