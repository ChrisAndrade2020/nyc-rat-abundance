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