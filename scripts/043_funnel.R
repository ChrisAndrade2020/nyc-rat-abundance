# ───────────────────────────────────────────────────────────
# Script: 043_funnel.R
# Purpose: Compute funnel metrics (calls → inspections → violations) for Tableau
# Inputs:  
#   • data/processed/rats_clean.csv  
#   • data/raw/Rodent_Inspection_20250611.csv  
# Outputs:  
#   • output/rat_funnel.csv  
# Depends: data.table, stringr, lubridate  
# ───────────────────────────────────────────────────────────

# 1. Load libraries
library(data.table)
library(stringr)
library(lubridate)

# 2. Read calls and inspections
rats <- fread("data/processed/rats_clean.csv")
insp <- fread("data/raw/Rodent_Inspection_20250611.csv")

# 3. Normalize column names for both tables
setnames(rats, c("Unique Key","created_dt","BBL"),
         c("call_id","created_dt","bbl"))
setnames(insp, c("BBL","INSPECTION_DATE","RESULT"),
         c("bbl","inspection_date","result"))

# 4. Keep only needed columns
rats <- rats[, .(call_id = as.character(call_id),
                 bbl     = as.character(bbl),
                 call_dt = ymd_hms(created_dt))]
insp <- insp[, .(bbl     = as.character(bbl),
                 insp_dt = ymd(inspection_date),
                 result_lc = tolower(result))]

# 5. Flag each inspection row
insp[, inspected := TRUE]
insp[, violation := str_detect(result_lc, "failed|nov") &
       !str_detect(result_lc, "no violation")]

# 6. Prepare calls for non-equi join (±30 days)
setkey(insp, bbl, insp_dt)
rats[, low  := call_dt - days(30)]
rats[, high := call_dt + days(30)]

# 7. Non-equi join: match each call to first inspection in ±30-day window
matched <- insp[rats,
                on = .(bbl,
                       insp_dt >= low,
                       insp_dt <= high),
                mult = "first",
                nomatch = 0L]

# 8. Collapse flags per call
flags <- matched[, .(inspected = TRUE,
                     violation = any(violation)),
                 by = call_id]
funnel <- merge(rats[, .(call_id)], flags,
                by = "call_id", all.x = TRUE)[
                  is.na(inspected),  inspected := FALSE
                ][is.na(violation), violation := FALSE]

# 9. Compute funnel counts and percentages
Counts <- data.table(
  stage        = c("Calls", "Inspections", "Violations"),
  n            = c(nrow(funnel),
                   sum(funnel$inspected),
                   sum(funnel$violation))
)
Counts[, pct_of_calls := round(n / n[stage == "Calls"] * 100, 1)]

# 10. Write funnel summary for Tableau
dir.create("output", showWarnings = FALSE)
fwrite(Counts, "output/rat_funnel.csv")
print(Counts)


# ——— Duplicate block (repeats same steps) —————————————————————
library(data.table)
library(stringr)
library(lubridate)

rats <- fread("data/processed/rats_clean.csv")
insp <- fread("data/raw/Rodent_Inspection_20250611.csv")

setnames(rats, c("Unique Key","created_dt","BBL"),
         c("call_id","created_dt","bbl"))
setnames(insp, c("BBL","INSPECTION_DATE","RESULT"),
         c("bbl","inspection_date","result"))

rats <- rats[, .(call_id = as.character(call_id),
                 bbl     = as.character(bbl),
                 call_dt = ymd_hms(created_dt))]
insp <- insp[, .(bbl     = as.character(bbl),
                 insp_dt = ymd(inspection_date),
                 result_lc = tolower(result))]

insp[, inspected := TRUE]
insp[, violation := str_detect(result_lc, "failed|nov") &
       !str_detect(result_lc, "no violation")]

setkey(insp, bbl, insp_dt)
rats[, low  := call_dt - days(30)]
rats[, high := call_dt + days(30)]

matched <- insp[rats,
                on = .(bbl,
                       insp_dt >= low,
                       insp_dt <= high),
                mult = "first",
                nomatch = 0L]

flags <- matched[, .(inspected = TRUE,
                     violation = any(violation)),
                 by = call_id]
funnel <- merge(rats[, .(call_id)], flags,
                by = "call_id", all.x = TRUE)[
                  is.na(inspected),  inspected := FALSE
                ][is.na(violation), violation := FALSE]

Counts <- data.table(
  stage        = c("Calls", "Inspections", "Violations"),
  n            = c(nrow(funnel),
                   sum(funnel$inspected),
                   sum(funnel$violation))
)
Counts[, pct_of_calls := round(n / n[stage == "Calls"] * 100, 1)]

dir.create("output", showWarnings = FALSE)
fwrite(Counts, "output/rat_funnel.csv")
print(Counts)
