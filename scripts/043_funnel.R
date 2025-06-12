library(data.table)
library(stringr)   # for str_detect
library(lubridate) # easy date math

# ── 1) load 311 calls  &  DOHMH inspections ────────────────────────────
rats <- fread("data/processed/rats_clean.csv")
insp <- fread("data/raw/Rodent_Inspection_20250611.csv")

#  clean names you need
setnames(rats, c("Unique Key",   "created_dt", "BBL"),
         c("call_id",      "created_dt", "bbl"))
setnames(insp, c("BBL", "INSPECTION_DATE",   "RESULT"),
         c("bbl", "inspection_date",   "result"))

#  keep only needed cols
rats <- rats[, .(call_id = as.character(call_id),
                 bbl     = as.character(bbl),
                 call_dt = ymd_hms(created_dt))]

insp <- insp[, .(bbl     = as.character(bbl),
                 insp_dt = ymd(inspection_date),
                 result_lc = tolower(result))]

# ── 2) flag each inspection row ────────────────────────────────────────
insp[, inspected := TRUE ]
insp[, violation := str_detect(result_lc, "failed|nov") &
       !str_detect(result_lc, "no violation") ]

# ── 3) non-equi join: one inspection per call within ±30 days ──────────
setkey(insp, bbl, insp_dt)          # data.table wants a key

# add 30-day window boundaries
rats[, low  := call_dt - days(30)]
rats[, high := call_dt + days(30)]

matched <- insp[rats,              # right join (calls table order kept)
                on = .(bbl,
                       insp_dt >= low,
                       insp_dt <= high),
                mult = "first",    # take FIRST inspection that meets window
                nomatch = 0L]      # unmatched calls handled later

# ── 4) collapse flags per call (one row each) ──────────────────────────
flags <- matched[, .(inspected = TRUE,
                     violation = any(violation)),
                 by = call_id]

# calls with no match get FALSE flags
funnel <- merge(
  rats[, .(call_id)], flags,
  by = "call_id", all.x = TRUE
)[is.na(inspected),   inspected := FALSE
][is.na(violation),  violation := FALSE]

# ── 5) funnel counts  ---------------------------------------------------
Counts <- data.table(
  stage = c("Calls", "Inspections", "Violations"),
  n     = c(nrow(funnel),
            sum(funnel$inspected),
            sum(funnel$violation))
)
Counts[, pct_of_calls := round(n / n[stage == "Calls"] * 100, 1)]

# ── 6) write for Tableau  ----------------------------------------------
dir.create("output", showWarnings = FALSE)
fwrite(Counts, "output/rat_funnel.csv")
print(Counts)