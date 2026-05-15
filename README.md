# International Low Grade Glioma Registry — Enrollment Dashboard (R Shiny)

[![Live Demo](https://img.shields.io/badge/Live%20Demo-shinyapps.io-blue?logo=r)](https://fgkm0803.shinyapps.io/LYDIA_BAO_Final/)

Interactive **R Shiny** dashboard for the International Low Grade Glioma Registry: cumulative enrollment through a selected year, age and pathology distributions, and a **U.S. choropleth** of cumulative participants by state (ZIP → state via `zipcodeR`). Cleaning supports both U.S. and international postal formats; enrollment window filter **2000–01-01** through **2025-12-01**.

> **[→ Open live dashboard](https://fgkm0803.shinyapps.io/LYDIA_BAO_Final/)** *(deployed on shinyapps.io using a synthetic demo dataset)*

---

## 1. What's in the app

| Area | Description |
|------|-------------|
| **Enrollment slider** | Choose "data through Dec 31" of a year; updates totals and charts below. |
| **Total participants** | Cumulative count up to that year (U.S. + international). |
| **Age histogram** | 10-year age bands at enrollment (`ggplot2`). |
| **Diagnosis pie** | Astrocytoma / mixed / oligodendroglioma / other / unknown (`plotly`). |
| **U.S. state map** | Cumulative enrollment bins (0, 1–10, 11–50, 51–200, 200+); **not** filtered by the year slider. |

**Technical stack:** `shiny`, `readxl`, `dplyr`, `tidyr`, `stringr`, `lubridate`, `ggplot2`, `plotly`, `zipcodeR`, `maps`.

---

## 2. Prerequisites

- **R** 4.x recommended.
- Network access on first run so `zipcodeR` can resolve U.S. ZIPs (package behavior).

Install R packages once:

```r
install.packages(c(
  "shiny", "readxl", "dplyr", "tidyr", "stringr", "lubridate",
  "ggplot2", "plotly", "zipcodeR", "maps"
))
```

---

## 3. Data setup

The app reads **`Glioma_BIS679A_2025.xls`** from the **same directory as `app.R`** (`read_excel(...)` in `app.R`).

- **Public GitHub:** do **not** commit identifiable patient data or restricted files. Prefer a **private** repo, or ship **only** code plus a short note that users must supply their own Excel file locally.
- Add to `.gitignore` before pushing, for example:

```gitignore
*.xls
*.xlsx
.Rhistory
.DS_Store
```

If your file lives elsewhere or has another name, change the path in `app.R` inside `read_excel()`.

---

## 4. Running the Shiny app

From this folder in R:

```r
shiny::runApp("app.R")
```

Or from the terminal (current directory = this project):

```bash
R -e "shiny::runApp('.')"
```

---

## 5. Repository layout

```
LYDIA_BAO_Final/
├── app.R              # UI + server + data preparation (single-file Shiny app)
├── Lydia_Bao_Final.R # Supplementary R analysis script
├── BAO_LYDIA_SAS.txt # Supplementary notes / exports
└── README.md
```

---

## 6. 中文摘要

- **内容：** 国际低级别胶质瘤登记库入组情况可视化——按年份累计入组人数、入组年龄分布、病理占比饼图、美国各州累计入组分层地图。  
- **数据：** 需在本地放置 `Glioma_BIS679A_2025.xls`（与 `app.R` 同目录或修改路径）。**请勿将可识别健康信息推送到公开仓库。**  
- **运行：** `shiny::runApp("app.R")`。

---

_Suggested GitHub repository description (one line):_  
`R Shiny dashboard: ILGG registry enrollment trends, age/diagnosis distributions, U.S. state map via ZIP→state (zipcodeR).`
