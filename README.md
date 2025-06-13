# NYC Rat Sightings Dashboard 🚇🐀

> A reproducible pipeline that cleans NYC 311 “Rat Sightings” data, enriches it with tax‑lot (PLUTO) and socioeconomic context (ACS), and feeds a Tableau Public workbook with five interactive visualisations.

---

## 📊 Visualizations Deliverables

---To be updated--

The published dashboard is here → [Tableau Dashboard](https://public.tableau.com/app/profile/chris.kevin.andrade/viz/NYCRatSightingsDashboard2_0/Rats_Of_NYC).

---

## 🗂️ Repository Structure

```
--To be updated--
```

### Key Data Products

--To be updated--
---

## 🚀 Quick Start

```bash
# 1. Clone the repo
$ git clone https://github.com/your‑org/nyc‑rat‑dashboard.git
$ cd nyc‑rat‑dashboard

# 2. Manually unpack raw archives
#    Before running anything, extract all .zip (and .7z) files in data/raw/
#    • Windows: right-click each → “Extract All…” or use 7-Zip → “Extract Here”
#    • macOS/Linux: `unzip data/raw/*.zip`
#
#    This will drop MapPLUTO.dbf, 311_Calls.csv, etc. into data/raw/.

# 3. Open R (or RStudio) and install deps once
> source("scripts/000_setup_cmdstanr.R")   # installs CmdStan if needed

# 4. **Set your Census API key** (one-time per machine)
> Sys.setenv(CENSUS_API_KEY = "YOUR_KEY_HERE")

# 5. Rebuild the whole pipeline (≈ 15±5 min)
> source("run_script.R")
```

After the final 🎉 message you can connect Tableau to the CSV/GeoJSON outputs in the `output/` folder.

---

## 🛠️ Scripts Breakdown

--To be updated--

---

## 🖥️ Requirements

* R ≥ 4.2
* Packages: **tidyverse, sf, tidycensus, vroom, cmdstanr, lubridate, stringr, forcats, readr, scales, cli** (installed automatically when sourcing scripts)
* Census API key (free): [https://api.census.gov/data/key\_signup.html](https://api.census.gov/data/key_signup.html)
* \~10 GB free disk (raw data + CmdStan build)

---

## 📜 License

MIT

---

## 🙏 Acknowledgements

* [NYC Open Data for 311 rat sightings](https://opendata.cityofnewyork.us/data/)
* [NYC Department of City Planning for MapPLUTO](https://www.nyc.gov/content/planning/pages/resources)
* [U.S. Census Bureau for ACS estimates](https://www.census.gov/data.html)
