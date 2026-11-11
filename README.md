# Campus Food Insights

University **Data Mining and Analysis** lab project analyzing a Google Form survey of `88` students on campus eating habits, spending, meal skipping, outside ordering, satisfaction, and desired improvements — built entirely in **R**.

---

## Project Structure

```text
project/
  data/
    dmaProjectdata.csv        # Raw survey data (never edited)
  R/
    01_clean.R                # Phase 1: Data cleaning, quality checks, 0/1 splits
    02_overall.R              # Phase 2: Overall profile, averages, rankings, bias check
    03_eda.R                  # Phase 3: Group comparisons, chi-square tests, correlations
    04_questions.R            # Phase 4: 5 research questions derived from EDA facts
    05_mining.R               # Phase 5: Association rules and decision tree
  outputs/                    # Generated cleaned data, CSV tables, .rds files, and PNG plots
  app/
    app.R                     # Phase 6: Interactive 7-tab Shiny + Plotly + DT dashboard
  report/
    report.Rmd                # Phase 7: Final R Markdown report
    report.html               # Knitted HTML report
  FINDINGS.md                 # Running log of verified findings across all phases
  README.md                   # Setup and execution instructions
```

---

## Required R Packages

Install all required packages once in R:

```r
install.packages(c(
  "tidyverse", "janitor", "arules",
  "rpart", "rpart.plot", "shiny", "plotly", "DT",
  "rmarkdown", "knitr"
))
```

---

## How to Run Everything (In Order)

Open R / RStudio in the project root directory (`d:\study\sem5\dma_lab\project`), or run each script sequentially from PowerShell using `Rscript.exe`:

### 1. Run the Analysis Pipeline (Phases 1 to 5)

```powershell
$R = "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe"
& $R R/01_clean.R
& $R R/02_overall.R
& $R R/03_eda.R
& $R R/04_questions.R
& $R R/05_mining.R
```

*Each script reads from `data/` or `outputs/` and saves its tables, `.rds` results, and PNG charts to `outputs/`.*

### 2. Launch the Shiny Dashboard (Phase 6)

In R / RStudio:

```r
shiny::runApp("app")
```

Or from PowerShell:

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e "shiny::runApp('app', launch.browser = TRUE)"
```

### 3. Knit the Final Report (Phase 7)

In RStudio, open `report/report.Rmd` and click **Knit**.  
From PowerShell (pointing `RSTUDIO_PANDOC` to RStudio's bundled Pandoc if `pandoc` is not on your system `PATH`):

```powershell
& "C:\Program Files\R\R-4.6.1\bin\x64\Rscript.exe" -e "Sys.setenv(RSTUDIO_PANDOC='C:/Program Files/RStudio/resources/app/bin/quarto/bin/tools'); rmarkdown::render('report/report.Rmd')"
```

This outputs `report/report.html`.

