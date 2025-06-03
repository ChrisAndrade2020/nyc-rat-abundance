# NYC Rat Sightings Dashboard 🚇🐀

> A reproducible pipeline that cleans NYC 311 “Rat Sightings” data, enriches it with tax‑lot (PLUTO) and socioeconomic context (ACS), and feeds a Tableau Public workbook with five interactive visualisations.

---

## 📊 Visualizations Deliverables

| Tab                | Chart                                                       | Notes                                  |
| ------------------ | ----------------------------------------------------------- | -------------------------------------- |
| **Heat Map**       | Kernel‑density of sightings (time slider, borough filter)   | Uses `rats_ready.csv` points           |
| **Monthly Trend**  | City‑wide monthly calls                                     | Derived from `rats_ready.csv`          |
| **Location Type**  | Stacked bar of top 7 location types                         | `LocationType` lumped in script        |
| **Borough Rate**   | Calls per 10 k residents                                    | Joins borough counts to ACS population |
| **Income Scatter** | Calls/10 k vs. median household income (tract level)        | Built from `income_scatter.csv`        |
| **TBA**            | Proof of Concept: Quarterly Heterogeneous Capture–Recapture | TBA                                    |

The published dashboard is here → [Tableau Dashboard](https://public.tableau.com/app/profile/chris.kevin.andrade/viz/NYCRatSightingsDashboard_17486367234910/Dashboard1?publish=yes).

---

## 🗂️ Repository Structure

```
├─ data/
│  ├─ raw/            # untouched downloads (311 CSV, MapPLUTO shapefile)
│  └─ processed/      # cleaned & enriched artefacts for analysis
├─ output/            # GeoJSON + CSV files used directly by Tableau
├─ scripts/           # numbered R scripts (see below)
│  └─ …
├─ run_script.R       # master driver that rebuilds everything
└─ README.md
```

### Key Data Products

| File                               | Purpose                               |
| ---------------------------------- | ------------------------------------- |
| `data/processed/rats_ready.csv`    | Point‑level cleaned sightings         |
| `data/processed/borough_rates.csv` | Borough call counts + rate per 10 k   |
| `data/processed/ACS.csv`           | Block‑group ACS metrics keyed by BBL  |
| `output/rats_enriched.geojson`     | Sightings with PLUTO + ACS attributes |
| `output/income_scatter.csv`        | Tract‑level scatter data              |
| `output/rat_with_bg_ACS_point.csv` | Point‑level ACS join (BG)             |
| `output/bg_calls_ACS_summary.csv`  | BG summary with call rate             |

---

## 🚀 Quick Start

```bash
# 1. Clone the repo
$ git clone https://github.com/your‑org/nyc‑rat‑dashboard.git
$ cd nyc‑rat‑dashboard

# 2. Open R (or RStudio) and install deps once
> source("scripts/000_setup_cmdstanr.R")   # installs CmdStan if needed

# 3. **Set your Census API key** (one‑time per machine)
> Sys.setenv(CENSUS_API_KEY = "YOUR_KEY_HERE")

# 4. Rebuild the whole pipeline (≈ 15±5 min)
> source("run_script.R")
```

After the final 🎉 message you can connect Tableau to the CSV/GeoJSON outputs in the `output/` folder.

---

## 🛠️ Scripts Breakdown

| Order | Script                       | What it does                                                 |
| ----- | ---------------------------- | ------------------------------------------------------------ |
| 000   | **setup\_cmdstanr.R**        | Installs & tests CmdStan C++ toolchain (only once)           |
| 011   | **data\_prep.R**             | Cleans raw 311 CSV, flags bad closes, saves `rats_clean.csv` |
| 012   | **data\_prep\_derivation.R** | Creates `rats_ready.csv` & `borough_rates.csv`               |
| 021   | **acs\_fetch.R**             | Downloads ACS 2023 BG metrics → `ACS.csv`                    |
| 022   | **spatial\_join.R**          | Adds PLUTO & ACS to sightings → `rats_enriched.geojson`      |
| 023   | **income\_scatter.R**        | Builds tract‑level scatter data                              |
| 024   | **bg\_acs\_join.R**          | Attaches BG ACS to points + BG summary                       |
| run   | **run\_script.R**            | Runs everything above & checks outputs                       |

Each script is extensively commented—open any file for a guided walkthrough.

---

## 🖥️ Requirements

* R ≥ 4.2
* Packages: **tidyverse, sf, tidycensus, vroom, cmdstanr, lubridate, stringr, forcats, readr, scales, cli** (installed automatically when sourcing scripts)
* Census API key (free): [https://api.census.gov/data/key\_signup.html](https://api.census.gov/data/key_signup.html)
* \~10 GB free disk (raw data + CmdStan build)

---

## 🤝 Contributing

Pull requests welcome! Please keep code style consistent (tidyverse) and include a brief description + before/after screenshots for any viz tweaks.

---

## 📜 License

MIT

---

## 🙏 Acknowledgements

* NYC Open Data for 311 rat sightings
* NYC Department of City Planning for MapPLUTO
* U.S. Census Bureau for ACS estimates
