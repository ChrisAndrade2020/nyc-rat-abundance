# ── libraries ────────────────────────────────────────────────────────────────
library(dplyr)
library(readr)

# ── load 311 rat records (2010-May 2025) ─────────────────────────────────────
rats <- read_csv("data/processed/rats_clean.csv")
# expected Boolean fields:
#   • inspected   (TRUE if the call resulted in a field inspection)
#   • violation   (TRUE if an official violation was issued)
#   • mitigated   (TRUE if the property shows a subsequent 'problem abated')

# ── collapse into the funnel counts ─────────────────────────────────────────
funnel_df <- rats %>%
  summarise(
    Calls        = n(),                                # total 311 calls
    Inspections  = sum(inspected,  na.rm = TRUE),
    Violations   = sum(violation,  na.rm = TRUE),
    Mitigations  = sum(mitigated,  na.rm = TRUE)
  ) %>%
  tidyr::pivot_longer(everything(),
                      names_to  = "stage",
                      values_to = "n") %>%
  mutate( pct_of_calls = n / first(n) * 100 )          # % of initial calls

write_csv(funnel_df, "output/rat_funnel.csv")
