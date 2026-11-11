# Phase 6: Campus Food Insights — Interactive Shiny Dashboard
# Run from project root with: shiny::runApp("app")
# Or from inside app/ with:   shiny::runApp("app.R")

library(shiny)
library(tidyverse)
library(plotly)
library(DT)
library(rpart)
library(rpart.plot)

# Resolve outputs/ whether launched from project root or from app/
out_dir <- if (dir.exists("outputs")) "outputs" else "../outputs"

# Load precomputed cleaned data and analysis results for fast startup
clean_df   <- readRDS(file.path(out_dir, "clean.rds"))
opt_map    <- readr::read_csv(file.path(out_dir, "multiselect_options.csv"), show_col_types = FALSE)
overall_r  <- readRDS(file.path(out_dir, "overall_results.rds"))
eda_r      <- readRDS(file.path(out_dir, "eda_results.rds"))
quest_r    <- readRDS(file.path(out_dir, "questions_results.rds"))
mining_r   <- readRDS(file.path(out_dir, "mining_results.rds"))

# Use cleaned data directly in app
app_df <- clean_df

# Helper: build human-readable label -> column mapping for rule matching
item_col_lookup <- c(
  stats::setNames(
    opt_map$column_name,
    paste0(
      dplyr::case_when(
        opt_map$group == "outlets" ~ "Outlet: ",
        opt_map$group == "factors" ~ "Factor: ",
        opt_map$group == "improvements" ~ "Improve: "
      ),
      opt_map$option_label
    )
  ),
  "Flag: Satisfied (4-5)"        = "satisfied",
  "Flag: Skips Breakfast"        = "skips_breakfast",
  "Flag: Heavy Outside (>=2/wk)" = "heavy_outside"
)

# Parse an arules rule string "{A,B} => {C}" to compute count/support in filtered data
compute_filtered_rule_stats <- function(rule_str, data) {
  if (nrow(data) == 0) return(list(count = 0L, support = 0))
  parts <- stringr::str_split(rule_str, "\\s*=>\\s*", simplify = TRUE)
  lhs_items <- stringr::str_split(stringr::str_remove_all(parts[1], "^\\{|\\}$"), ",")[[1]]
  rhs_items <- stringr::str_split(stringr::str_remove_all(parts[2], "^\\{|\\}$"), ",")[[1]]
  all_items <- stringr::str_trim(c(lhs_items, rhs_items))
  cols <- unname(item_col_lookup[all_items])
  if (any(is.na(cols))) return(list(count = NA_integer_, support = NA_real_))
  matched <- apply(as.matrix(data[, cols, drop = FALSE]) == 1, 1, all)
  cnt <- sum(matched)
  list(count = cnt, support = round(cnt / nrow(data), 3))
}

# Pre-build filter choices
year_choices   <- levels(app_df$year)
diet_choices   <- sort(unique(app_df$diet))
gender_choices <- sort(unique(app_df$gender))

# Static plain-language Q&A definitions anchored to FINDINGS.md
qa_catalog <- list(
  Q1 = list(
    title = "Q1. Why are high spenders (> Rs 2,000/month) much more satisfied than low or medium spenders?",
    trigger = "EDA showed Spend Band is significantly linked to satisfaction (p = 0.0123): 52.4% of High spenders (> Rs 2,000) are satisfied vs. 18.2% (Low) and 20.0% (Medium).",
    answer = paste(
      "High spenders (n = 21) eat fewer campus outlet meals per day (0.71 vs 1.01), order outside slightly more (1.10 vs 0.88/week; 28.6% heavy vs 16.4%),",
      "and use Nescafe more (57.1% vs 38.8%) while using Yadav Canteen less (19.0% vs 32.8%). However, none of these single items reaches p < 0.05 on its own,",
      "and high spenders still request Better Food Quality (57.1%), Better Hygiene (52.4%), and Lower Prices (52.4%).",
      "In plain terms, a larger budget lets students buy flexibility and extra choices, though the survey did not record which exact off-campus or premium items they buy."
    )
  ),
  Q2 = list(
    title = "Q2. What sets Nescafe users apart from non-users, and does using Nescafe explain their higher satisfaction?",
    trigger = "Nescafe users (n = 38) are more than twice as likely to be satisfied (39.5% vs 18.0% for non-users, p = 0.0456).",
    answer = paste(
      "Nescafe users select more campus outlets overall (2.58 vs 1.74), spend slightly more on average (Rs 1,879 vs Rs 1,658), and show higher satisfaction inside every spend tier",
      "(30.0% vs 8.3% in Low, 25.0% vs 17.2% in Medium, 66.7% vs 33.3% in High). Yet they ask for the exact same top improvements (50% Better Hygiene, 50% Better Quality, 50% Lower Prices).",
      "Because the survey only asked for overall campus satisfaction rather than per-outlet ratings, it cannot prove Nescafe caused higher satisfaction."
    )
  ),
  Q3 = list(
    title = "Q3. Who skips breakfast most often, and how does skipping breakfast link to outlets and eating habits?",
    trigger = "70.5% of students (62/88) skip breakfast most often, while Yadav Canteen users appeared to skip breakfast less (53.8% vs 77.4%, p = 0.0505).",
    answer = paste(
      "Breakfast skipping is widespread across every year (66.7%-80.0%), gender (68.8%-71.4%), and diet (66.7%-74.4%) with no demographic difference.",
      "The clearest link is outlet usage: only 22.6% of breakfast skippers use Yadav Canteen vs 46.2% of non-skippers (p = 0.0505), while Night Canteen users lean the opposite way (29.0% vs 11.5%, p = 0.138).",
      "Breakfast skippers are also twice as likely to eat 0 campus outlet meals/day (30.6% vs 15.4%). The survey did not collect class timings or sleep hours to explain why."
    )
  ),
  Q4 = list(
    title = "Q4. Do Vegetarian and Non-Vegetarian students rely on different food channels or ask for different improvements?",
    trigger = "Diet showed borderline patterns in heavy outside ordering (30.8% Veg vs 10.3% Non-Veg, p = 0.0652), Hostel Mess use (66.7% vs 41.0%), and Night Canteen use (12.8% vs 33.3%).",
    answer = paste(
      "Vegetarians (n = 39) and Non-Vegetarians (n = 39) rely on noticeably different channels: Vegetarians use Hostel Mess more (66.7% vs 41.0%), Night Canteen less (12.8% vs 33.3%),",
      "and order outside >= 2 times/week three times as often (30.8% vs 10.3%). Crucially, Vegetarians ask for Lower Prices significantly more often (56.4% vs 25.6% Non-Veg and 44.4% Eggetarian, p = 0.0206).",
      "Overall satisfaction does not differ reliably by diet (p = 0.430), and Vegans (n = 1) have too few responses for any claim."
    )
  ),
  Q5 = list(
    title = "Q5. Do dissatisfied students ask for different improvements than neutral or satisfied students, or are complaints campus-wide?",
    trigger = "Only 27.3% of students are satisfied, while over half want Better Hygiene (52.3%) and Better Quality (50.0%) and all 4 facility-rating columns were blank.",
    answer = paste(
      "Complaints are campus-wide across Dissatisfied (1-2, n = 22), Neutral (3, n = 42), and Satisfied (4-5, n = 24) students: around half in every tier want",
      "Better Hygiene (54.5%, 52.4%, 50.0%; p = 0.953), Better Food Quality (45.5%, 50.0%, 54.2%; p = 0.840), and Lower Prices (45.5%, 38.1%, 45.8%; p = 0.773).",
      "Dissatisfied students ask slightly more for Larger Portions (36.4% vs 19.0%/20.8%, p = 0.280, may be luck). The data cannot identify which specific dining facility aspect caused low ratings because those 4 columns were 100% empty."
    )
  )
)

# UI ---------------------------------------------------------------------------
ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      body { background-color: #f8fafc; font-family: 'Segoe UI', Arial, sans-serif; }
      .kpi-card {
        background: #ffffff; border: 1px solid #e2e8f0; border-radius: 8px;
        padding: 12px 15px; margin-bottom: 12px; box-shadow: 0 1px 2px rgba(0,0,0,0.04);
      }
      .kpi-title { font-size: 12px; color: #64748b; text-transform: uppercase; letter-spacing: 0.4px; }
      .kpi-val { font-size: 24px; font-weight: 700; color: #0f172a; margin-top: 2px; }
      .kpi-sub { font-size: 12px; color: #475569; margin-top: 2px; }
      .warn-box {
        background-color: #fff7ed; border-left: 4px solid #ea580c; color: #9a3412;
        padding: 10px 14px; border-radius: 4px; margin-bottom: 14px; font-weight: 500;
      }
      .info-box {
        background-color: #eff6ff; border-left: 4px solid #2563eb; color: #1e3a8a;
        padding: 10px 14px; border-radius: 4px; margin-bottom: 14px;
      }
      .qa-card {
        background: #ffffff; border: 1px solid #cbd5e1; border-radius: 8px;
        padding: 14px 18px; margin-bottom: 14px;
      }
    "))
  ),

  titlePanel("Campus Food Insights — Interactive Analytics Dashboard"),

  sidebarLayout(
    sidebarPanel(
      width = 3,
      h4("Filter Students"),
      p("Filters apply across all 7 tabs.", style = "color: #475569; font-size: 13px;"),
      checkboxGroupInput("f_year", "Year of Study:", choices = year_choices, selected = year_choices),
      checkboxGroupInput("f_diet", "Dietary Preference:", choices = diet_choices, selected = diet_choices),
      checkboxGroupInput("f_gender", "Gender:", choices = gender_choices, selected = gender_choices),
      actionButton("reset_filters", "Reset All Filters", class = "btn-default btn-sm"),
      hr(),
      h5("Sample Notes"),
      tags$ul(
        style = "font-size: 12px; color: #475569; padding-left: 18px;",
        tags$li("Total sample: 88 students (mostly 3rd Year 75%, Hostel 95.5%)."),
        tags$li("Small groups (< 8): Day Scholar (4), Vegan (1), Cash (2)."),
        tags$li("4 dining rating columns & nutrition item were 100% empty.")
      )
    ),

    mainPanel(
      width = 9,
      uiOutput("sample_banner"),
      tabsetPanel(
        id = "main_tabs",

        # Tab 1: Overview
        tabPanel(
          "1. Overview",
          br(),
          fluidRow(
            column(3, uiOutput("kpi_n")),
            column(3, uiOutput("kpi_spend")),
            column(3, uiOutput("kpi_sat")),
            column(3, uiOutput("kpi_bf"))
          ),
          fluidRow(
            column(6, plotlyOutput("p_ov_sat", height = "340px")),
            column(6, plotlyOutput("p_ov_outlets", height = "340px"))
          ),
          br(),
          fluidRow(
            column(6, plotlyOutput("p_ov_factors", height = "360px")),
            column(6, plotlyOutput("p_ov_improve", height = "360px"))
          )
        ),

        # Tab 2: EDA Facts
        tabPanel(
          "2. EDA Facts",
          br(),
          div(
            class = "info-box",
            strong("Key Confirmed Facts (Full Sample n = 88): "),
            "High spenders (> Rs 2,000) are much more satisfied (52.4% vs 18-20%, p = 0.0123). ",
            "Nescafe users are more than twice as likely to be satisfied (39.5% vs 18.0%, p = 0.0456). ",
            "Vegetarians demand Lower Prices more than Non-Vegetarians (56.4% vs 25.6%, p = 0.0206)."
          ),
          fluidRow(
            column(
              4,
              selectInput(
                "eda_group", "Group By:",
                choices = c(
                  "Spend Band" = "spend_band",
                  "Year of Study" = "year",
                  "Gender" = "gender",
                  "Diet (excl. <8 in tests)" = "diet",
                  "Uses Nescafe" = "outlet_nescafe",
                  "Uses Hostel Mess" = "outlet_hostel_mess",
                  "Uses Yadav Canteen" = "outlet_yadav_canteen",
                  "Uses Night Canteen" = "outlet_night_canteen"
                ),
                selected = "spend_band"
              )
            ),
            column(
              4,
              selectInput(
                "eda_metric", "Metric to Plot:",
                choices = c(
                  "% Satisfied (Rating 4-5)" = "pct_satisfied",
                  "Mean Satisfaction (1-5)" = "mean_sat",
                  "Mean Monthly Spend (Rs)" = "mean_spend",
                  "% Skips Breakfast" = "pct_bf",
                  "% Heavy Outside (>=2/wk)" = "pct_heavy"
                ),
                selected = "pct_satisfied"
              )
            )
          ),
          fluidRow(
            column(7, plotlyOutput("p_eda_group", height = "360px")),
            column(5, plotlyOutput("p_eda_corr", height = "360px"))
          ),
          br(),
          h4("Chi-Square Tests (Full Sample, Groups < 8 Excluded)"),
          DTOutput("tbl_eda_chisq")
        ),

        # Tab 3: Questions and Answers
        tabPanel(
          "3. Questions & Answers",
          br(),
          selectInput(
            "qa_pick", "Choose a Research Question:",
            choices = c(
              "Q1: Why are high spenders more satisfied?" = "Q1",
              "Q2: What sets Nescafe users apart?" = "Q2",
              "Q3: Who skips breakfast and what goes with it?" = "Q3",
              "Q4: Diet vs food channels & prices" = "Q4",
              "Q5: Are complaints campus-wide across satisfaction tiers?" = "Q5"
            ),
            width = "100%"
          ),
          uiOutput("qa_text_box"),
          plotlyOutput("p_qa_live", height = "400px")
        ),

        # Tab 4: Association Rules
        tabPanel(
          "4. Association Rules",
          br(),
          div(
            class = "info-box",
            strong("How to read rules: "),
            "23 non-redundant rules mined from full sample (support >= 0.14, confidence >= 0.65, lift > 1.15). ",
            "Lift > 1 means the items appear together more often than expected by chance. ",
            "Columns on the right update live to show matches in your current sidebar filter."
          ),
          plotlyOutput("p_rules_scatter", height = "320px"),
          br(),
          DTOutput("tbl_rules")
        ),

        # Tab 5: Decision Tree
        tabPanel(
          "5. Decision Tree",
          br(),
          div(
            class = "info-box",
            strong("Decision Tree Target = Satisfied (Rating 4-5): "),
            "Majority-class baseline = 72.7% (always guessing Not Satisfied). ",
            "10-fold CV accuracy = 73.9% (in-sample = 79.5%). ",
            "First split is spend < Rs 2,250; among higher spenders (>= Rs 2,250), those who prioritize Hygiene/Cleanliness remain 78% unsatisfied, while those who do not are 75% satisfied."
          ),
          fluidRow(
            column(7, plotOutput("p_tree_static", height = "400px")),
            column(5, plotlyOutput("p_tree_leaves", height = "400px"))
          ),
          br(),
          h4("Filtered Evaluation Across Tree Leaves"),
          DTOutput("tbl_tree_metrics")
        ),

        # Tab 6: Recommendations
        tabPanel(
          "6. Recommendations",
          br(),
          uiOutput("rec_live_summary"),
          fluidRow(
            column(
              4,
              div(
                class = "qa-card",
                h4("For Administration"),
                tags$ul(
                  tags$li(strong("Campus-wide hygiene audits:"), " 52.3% overall demand Better Hygiene/Cleanliness across all satisfaction tiers, and hygiene concerns block satisfaction even among higher spenders."),
                  tags$li(strong("Upgrade food quality & portions:"), " 50.0% want Better Food Quality; 36.4% of dissatisfied students ask for Larger Portions."),
                  tags$li(strong("Fix future survey collection:"), " Restore the 4 empty facility rating columns (seating, staff, hours, waste) and nutrition question.")
                )
              )
            ),
            column(
              4,
              div(
                class = "qa-card",
                h4("For Food Vendors"),
                tags$ul(
                  tags$li(strong("Add quick affordable breakfast:"), " 70.5% skip breakfast most often; Yadav Canteen users skip much less (53.8% vs 77.4%)."),
                  tags$li(strong("Improve Hostel Mess taste & price value:"), " Association rules link Hostel Mess users to Better Taste (conf 70%, lift 1.34) and Lower Prices (conf 65%)."),
                  tags$li(strong("Veg value combos & Nescafe pricing:"), " 56.4% of Vegetarians want Lower Prices (p = 0.0206); Nescafe users want better quality-to-price value (lift 1.67).")
                )
              )
            ),
            column(
              4,
              div(
                class = "qa-card",
                h4("For Students & Study Limits"),
                tags$ul(
                  tags$li(strong("Breakfast & late-night routine:"), " 85.7% of Night Canteen users skip breakfast most often."),
                  tags$li(strong("Small & biased sample (n = 88):"), " 75% are 3rd Year and 95.5% Hostel; Day Scholars (4), Vegans (1), and Cash users (2) are too few for subgroup claims."),
                  tags$li(strong("Self-reported survey:"), " Spend and meal counts are estimates collected during a 38-minute window.")
                )
              )
            )
          )
        ),

        # Tab 7: Data
        tabPanel(
          "7. Data",
          br(),
          fluidRow(
            column(6, uiOutput("data_count_label")),
            column(6, div(style = "text-align: right;", downloadButton("download_csv", "Download Filtered CSV")))
          ),
          br(),
          DTOutput("tbl_data")
        )
      )
    )
  )
)

# SERVER -----------------------------------------------------------------------
server <- function(input, output, session) {

  observeEvent(input$reset_filters, {
    updateCheckboxGroupInput(session, "f_year", selected = year_choices)
    updateCheckboxGroupInput(session, "f_diet", selected = diet_choices)
    updateCheckboxGroupInput(session, "f_gender", selected = gender_choices)
  })

  # Guarded filtered data when user unchecks all boxes in a group
  safe_df <- reactive({
    if (is.null(input$f_year) || is.null(input$f_diet) || is.null(input$f_gender)) {
      return(app_df[0, ])
    }
    app_df |>
      dplyr::filter(
        as.character(year) %in% input$f_year,
        diet %in% input$f_diet,
        gender %in% input$f_gender
      )
  })

  # Sample size banner and <10 warning
  output$sample_banner <- renderUI({
    n <- nrow(safe_df())
    if (n == 0) {
      div(class = "warn-box", "No students match the selected filters (n = 0). Please select at least one option in each filter.")
    } else if (n < 10) {
      div(
        class = "warn-box",
        sprintf("Warning: Only n = %d students remain under the current filters (fewer than 10). Treat percentages and patterns with extreme caution.", n)
      )
    } else {
      div(
        class = "info-box",
        sprintf("Showing n = %d of %d surveyed students (UPI = %d%%, Hostel = %d%%).",
                n, nrow(app_df), round(100 * mean(safe_df()$payment == "UPI/QR Code")), round(100 * mean(safe_df()$residence == "Hostel")))
      )
    }
  })

  # --- TAB 1: OVERVIEW KPIs & CHARTS ---
  kpi_box <- function(title, val, sub) {
    div(class = "kpi-card", div(class = "kpi-title", title), div(class = "kpi-val", val), div(class = "kpi-sub", sub))
  }

  output$kpi_n <- renderUI({
    n <- nrow(safe_df())
    kpi_box("Filtered Students", paste0("n = ", n), paste0(round(100 * n / nrow(app_df), 1), "% of 88 total"))
  })

  output$kpi_spend <- renderUI({
    d <- safe_df()
    if (nrow(d) == 0) return(kpi_box("Avg Monthly Spend", "N/A", ""))
    kpi_box("Avg Monthly Spend", paste0("Rs ", round(mean(d$spend))), paste0("Median: Rs ", median(d$spend)))
  })

  output$kpi_sat <- renderUI({
    d <- safe_df()
    if (nrow(d) == 0) return(kpi_box("Satisfied (4-5)", "N/A", ""))
    kpi_box("Satisfied (4-5)", paste0(round(100 * mean(d$satisfied), 1), "%"), paste0("Mean score: ", round(mean(d$satisfaction), 2), " / 5"))
  })

  output$kpi_bf <- renderUI({
    d <- safe_df()
    if (nrow(d) == 0) return(kpi_box("Skips Breakfast", "N/A", ""))
    kpi_box("Skips Breakfast", paste0(round(100 * mean(d$skips_breakfast), 1), "%"), paste0("Heavy outside (>=2/wk): ", round(100 * mean(d$heavy_outside), 1), "%"))
  })

  output$p_ov_sat <- renderPlotly({
    d <- safe_df()
    validate(need(nrow(d) > 0, "No data for selected filters."))
    sat_tbl <- tibble::tibble(rating = 1:5) |>
      dplyr::left_join(d |> dplyr::count(satisfaction, name = "count"), by = c("rating" = "satisfaction")) |>
      dplyr::mutate(count = tidyr::replace_na(count, 0L), pct = round(100 * count / nrow(d), 1))
    plot_ly(
      sat_tbl, x = ~factor(rating), y = ~count, type = "bar",
      marker = list(color = "#2c7fb8"),
      text = ~paste0(count, " (", pct, "%)"), textposition = "outside",
      hovertemplate = "Rating %{x}: %{y} students (%{text})<extra></extra>"
    ) |>
      layout(
        title = paste0("Satisfaction Distribution (n = ", nrow(d), ")"),
        xaxis = list(title = "Rating (1 = Low, 5 = High)"),
        yaxis = list(title = "Students", range = c(0, max(sat_tbl$count) * 1.2 + 1))
      )
  })

  render_multiselect_plotly <- function(group_name, title_prefix, bar_color) {
    d <- safe_df()
    validate(need(nrow(d) > 0, "No data for selected filters."))
    sub_map <- opt_map |> dplyr::filter(group == group_name)
    counts <- colSums(d[, sub_map$column_name, drop = FALSE])
    tbl <- tibble::tibble(
      label = sub_map$option_label,
      count = as.integer(counts),
      pct   = round(100 * as.integer(counts) / nrow(d), 1)
    ) |>
      dplyr::arrange(count) |>
      dplyr::mutate(label = factor(label, levels = label))
    plot_ly(
      tbl, x = ~count, y = ~label, type = "bar", orientation = "h",
      marker = list(color = bar_color),
      text = ~paste0(count, " (", pct, "%)"), textposition = "outside",
      hovertemplate = "%{y}: %{x} students (%{text})<extra></extra>"
    ) |>
      layout(
        title = paste0(title_prefix, " (n = ", nrow(d), ")"),
        xaxis = list(title = "Students", range = c(0, max(tbl$count) * 1.28 + 1)),
        yaxis = list(title = ""),
        margin = list(l = 180)
      )
  }

  output$p_ov_outlets <- renderPlotly(render_multiselect_plotly("outlets", "Regular Food Outlets", "#1b9e77"))
  output$p_ov_factors <- renderPlotly(render_multiselect_plotly("factors", "Important Decision Factors", "#7570b3"))
  output$p_ov_improve <- renderPlotly(render_multiselect_plotly("improvements", "Wanted Improvements", "#d95f02"))

  # --- TAB 2: EDA FACTS ---
  output$p_eda_group <- renderPlotly({
    d <- safe_df()
    validate(need(nrow(d) > 0, "No data for selected filters."))
    grp_col <- input$eda_group
    met_col <- input$eda_metric

    tbl <- d |>
      dplyr::mutate(grp_val = as.character(.data[[grp_col]])) |>
      dplyr::mutate(grp_val = dplyr::case_when(
        grp_col %in% c("outlet_nescafe", "outlet_hostel_mess", "outlet_yadav_canteen", "outlet_night_canteen") & grp_val == "1" ~ "Uses Outlet",
        grp_col %in% c("outlet_nescafe", "outlet_hostel_mess", "outlet_yadav_canteen", "outlet_night_canteen") & grp_val == "0" ~ "Does Not Use",
        TRUE ~ grp_val
      )) |>
      dplyr::group_by(grp_val) |>
      dplyr::summarise(
        n = dplyr::n(),
        pct_satisfied = round(100 * mean(satisfied), 1),
        mean_sat = round(mean(satisfaction), 2),
        mean_spend = round(mean(spend), 0),
        pct_bf = round(100 * mean(skips_breakfast), 1),
        pct_heavy = round(100 * mean(heavy_outside), 1),
        .groups = "drop"
      ) |>
      dplyr::mutate(
        y_val = .data[[met_col]],
        bar_col = dplyr::if_else(n < 8, "#cbd5e1", "#2b8cbe"),
        lbl_txt = paste0(grp_val, " (n=", n, ifelse(n < 8, ", <8", ""), ")")
      )

    plot_ly(
      tbl, x = ~lbl_txt, y = ~y_val, type = "bar",
      marker = list(color = ~bar_col),
      text = ~y_val, textposition = "outside",
      hovertemplate = "%{x}<br>Value: %{y}<extra></extra>"
    ) |>
      layout(
        title = paste0("Group Comparison (Filtered n = ", nrow(d), "; Grey = < 8 students)"),
        xaxis = list(title = ""),
        yaxis = list(title = met_col, range = c(0, max(tbl$y_val, na.rm = TRUE) * 1.2 + 1))
      )
  })

  output$p_eda_corr <- renderPlotly({
    d <- safe_df()
    validate(need(nrow(d) >= 3, "Need at least 3 rows for correlation matrix."))
    cols <- c("spend", "meals_per_day", "outside_orders", "satisfaction")
    lbls <- c("Spend", "Meals/Day", "Outside Orders", "Satisfaction")
    mat <- suppressWarnings(stats::cor(d[, cols], use = "complete.obs"))
    mat[is.na(mat)] <- 0
    plot_ly(
      x = lbls, y = rev(lbls), z = round(mat[rev(seq_len(4)), ], 2),
      type = "heatmap", zmin = -1, zmax = 1,
      colors = colorRamp(c("#d73027", "#f7f7f7", "#1a9850")),
      text = round(mat[rev(seq_len(4)), ], 2),
      texttemplate = "%{text}",
      hovertemplate = "%{x} vs %{y}: r = %{z}<extra></extra>"
    ) |>
      layout(title = paste0("Numeric Correlations (n = ", nrow(d), ")"))
  })

  output$tbl_eda_chisq <- renderDT({
    eda_r$chisq_tests |>
      dplyr::select(comparison, n_used, skipped_small_groups, statistic, p_value, verdict) |>
      DT::datatable(options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  # --- TAB 3: QUESTIONS & ANSWERS ---
  output$qa_text_box <- renderUI({
    q <- qa_catalog[[input$qa_pick]]
    div(
      class = "qa-card",
      h4(q$title),
      p(strong("Triggering Fact: "), q$trigger),
      p(strong("Plain-Language Answer: "), q$answer)
    )
  })

  qa_metrics <- list(
    Q1 = c("Satisfied" = "satisfied", "Uses Nescafe" = "outlet_nescafe", "Heavy Outside" = "heavy_outside"),
    Q2 = c("Satisfied" = "satisfied", "Wants Hygiene" = "improve_better_hygiene_cleanliness",
           "Wants Quality" = "improve_better_food_quality", "Wants Lower Prices" = "improve_lower_prices"),
    Q3 = c("Uses Yadav Canteen" = "outlet_yadav_canteen", "Uses Night Canteen" = "outlet_night_canteen",
           "Uses Hostel Mess" = "outlet_hostel_mess", "0 Campus Meals/Day" = "zero_meals"),
    Q4 = c("Uses Hostel Mess" = "outlet_hostel_mess", "Uses Night Canteen" = "outlet_night_canteen",
           "Heavy Outside" = "heavy_outside", "Wants Lower Prices" = "improve_lower_prices"),
    Q5 = c("Better Hygiene" = "improve_better_hygiene_cleanliness", "Better Quality" = "improve_better_food_quality",
           "Lower Prices" = "improve_lower_prices", "Larger Portions" = "improve_larger_portions")
  )

  output$p_qa_live <- renderPlotly({
    d <- safe_df()
    validate(need(nrow(d) > 0, "No data for selected filters."))
    q_id <- input$qa_pick

    d_prep <- d |>
      dplyr::mutate(
        zero_meals = as.integer(meals_per_day == 0),
        grp = dplyr::case_when(
          q_id == "Q1" ~ dplyr::if_else(spend > 2000, "High (> Rs 2,000)", "Low/Med (<= Rs 2,000)"),
          q_id == "Q2" ~ dplyr::if_else(outlet_nescafe == 1, "Nescafe User", "Non-User"),
          q_id == "Q3" ~ dplyr::if_else(skips_breakfast == 1, "Skips Breakfast", "Other/Rarely"),
          q_id == "Q4" ~ diet,
          satisfaction <= 2 ~ "Dissatisfied (1-2)",
          satisfaction == 3 ~ "Neutral (3)",
          TRUE ~ "Satisfied (4-5)"
        )
      )
    if (q_id == "Q4") d_prep <- d_prep |> dplyr::filter(diet != "Vegan")
    validate(need(nrow(d_prep) > 0, "Not enough rows in selected groups."))

    cols_map <- qa_metrics[[q_id]]
    tbl <- purrr::map_dfr(seq_along(cols_map), function(i) {
      d_prep |>
        dplyr::group_by(grp) |>
        dplyr::summarise(n = dplyr::n(), pct = round(100 * mean(.data[[cols_map[i]]]), 1), .groups = "drop") |>
        dplyr::mutate(metric = names(cols_map)[i])
    }) |>
      dplyr::mutate(grp_lbl = paste0(grp, " (n=", n, ")"))

    plot_ly(
      tbl, x = ~metric, y = ~pct, color = ~grp_lbl, type = "bar",
      text = ~paste0(pct, "%"), textposition = "outside"
    ) |>
      layout(
        barmode = "group",
        title = paste0(q_id, " Live Breakdown (Filtered n = ", nrow(d), ")"),
        xaxis = list(title = ""),
        yaxis = list(title = "% of Group", range = c(0, 105))
      )
  })

  # --- TAB 4: ASSOCIATION RULES ---
  live_rules_df <- reactive({
    d <- safe_df()
    base_rules <- mining_r$rules_df
    stats_list <- purrr::map(base_rules$rules, ~ compute_filtered_rule_stats(.x, d))
    base_rules |>
      dplyr::mutate(
        filtered_count = purrr::map_int(stats_list, "count"),
        filtered_support = purrr::map_dbl(stats_list, "support")
      )
  })

  output$p_rules_scatter <- renderPlotly({
    r_df <- live_rules_df()
    n <- nrow(safe_df())
    plot_ly(
      r_df, x = ~confidence, y = ~lift, size = ~pmax(filtered_count, 1),
      color = ~support, type = "scatter", mode = "markers",
      text = ~paste0(
        rules, "<br>Full count: ", count, " | Filtered count: ", filtered_count,
        "<br>Conf: ", confidence, " | Lift: ", lift
      ),
      hoverinfo = "text"
    ) |>
      layout(
        title = paste0("23 Mined Rules: Confidence vs Lift (Bubble Size = Filtered Matches, n = ", n, ")"),
        xaxis = list(title = "Full-Sample Confidence"),
        yaxis = list(title = "Full-Sample Lift")
      )
  })

  output$tbl_rules <- renderDT({
    live_rules_df() |>
      DT::datatable(options = list(pageLength = 10, scrollX = TRUE), rownames = FALSE)
  })

  # --- TAB 5: DECISION TREE ---
  output$p_tree_static <- renderPlot({
    rpart.plot::rpart.plot(
      mining_r$tree_plotted,
      type = 4, extra = 104, fallen.leaves = TRUE, box.palette = "BuGn",
      main = "Cross-Validated Decision Tree (Full Sample n = 88)"
    )
  })

  output$p_tree_leaves <- renderPlotly({
    d <- safe_df()
    validate(need(nrow(d) > 0, "No data for selected filters."))
    leaf_tbl <- d |>
      dplyr::mutate(
        leaf = dplyr::case_when(
          spend < 2250 ~ "1. Spend < Rs 2,250",
          factor_hygiene_cleanliness == 1 ~ "2. Spend >= 2,250 & Hygiene = 1",
          TRUE ~ "3. Spend >= 2,250 & Hygiene = 0"
        )
      ) |>
      dplyr::group_by(leaf) |>
      dplyr::summarise(
        n = dplyr::n(),
        pct_satisfied = round(100 * mean(satisfied), 1),
        .groups = "drop"
      )
    leaf_colors <- c(
      "1. Spend < Rs 2,250" = "#2b8cbe",
      "2. Spend >= 2,250 & Hygiene = 1" = "#74a9cf",
      "3. Spend >= 2,250 & Hygiene = 0" = "#1b9e77"
    )
    plot_ly(
      leaf_tbl, x = ~leaf, y = ~pct_satisfied, type = "bar",
      marker = list(color = unname(leaf_colors[leaf_tbl$leaf])),
      text = ~paste0(pct_satisfied, "% (n=", n, ")"), textposition = "outside"
    ) |>
      layout(
        title = paste0("% Satisfied in Each Tree Leaf (Filtered n = ", nrow(d), ")"),
        xaxis = list(title = ""),
        yaxis = list(title = "% Satisfied (Rating 4-5)", range = c(0, 105))
      )
  })

  output$tbl_tree_metrics <- renderDT({
    d <- safe_df()
    if (nrow(d) == 0) {
      return(DT::datatable(mining_r$tree_metrics, options = list(dom = "t"), rownames = FALSE))
    }
    pred_leaf <- dplyr::if_else(d$spend >= 2250 & d$factor_hygiene_cleanliness == 0, 1L, 0L)
    filt_acc <- round(100 * mean(pred_leaf == d$satisfied), 1)
    filt_base <- round(100 * max(mean(d$satisfied == 1), mean(d$satisfied == 0)), 1)
    live_tbl <- dplyr::bind_rows(
      mining_r$tree_metrics |> dplyr::mutate(value = as.character(value)),
      tibble::tibble(
        metric = c(
          paste0("Filtered subset baseline (%) (n=", nrow(d), ")"),
          paste0("Filtered subset tree accuracy (%) (n=", nrow(d), ")")
        ),
        value = as.character(c(filt_base, filt_acc))
      )
    )
    DT::datatable(live_tbl, options = list(pageLength = 12, dom = "t"), rownames = FALSE)
  })

  # --- TAB 6: RECOMMENDATIONS LIVE SUMMARY ---
  output$rec_live_summary <- renderUI({
    d <- safe_df()
    if (nrow(d) == 0) return(NULL)
    div(
      class = "info-box",
      sprintf(
        "Among the selected n = %d students: %.1f%% skip breakfast most often, %.1f%% want Better Hygiene, %.1f%% want Better Quality, and %.1f%% want Lower Prices.",
        nrow(d),
        100 * mean(d$skips_breakfast),
        100 * mean(d$improve_better_hygiene_cleanliness),
        100 * mean(d$improve_better_food_quality),
        100 * mean(d$improve_lower_prices)
      )
    )
  })

  # --- TAB 7: DATA & DOWNLOAD ---
  output$data_count_label <- renderUI({
    strong(sprintf("Showing %d of %d rows (49 cleaned columns)", nrow(safe_df()), nrow(app_df)))
  })

  output$tbl_data <- renderDT({
    safe_df() |>
      dplyr::select(
        respondent_id, year, residence, gender, diet, spend, spend_band,
        meals_per_day, skipped_meal, outside_orders, satisfaction,
        payment, outlets, factors, improvements
      ) |>
      DT::datatable(options = list(pageLength = 12, scrollX = TRUE), rownames = FALSE)
  })

  output$download_csv <- downloadHandler(
    filename = function() paste0("campus_food_filtered_", Sys.Date(), ".csv"),
    content = function(file) readr::write_csv(safe_df(), file)
  )
}

shinyApp(ui = ui, server = server)
