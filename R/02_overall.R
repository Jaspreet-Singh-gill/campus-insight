# Phase 2: Overall Analysis (Big-Picture View)
# Purpose: Describe the overall sample profile, numeric averages/medians,
#          satisfaction distribution, most used outlets, top factors,
#          top wanted improvements, and sample biases before subgroup tests.

library(tidyverse)

# Load cleaned dataset and option label lookup
df <- readRDS("outputs/clean.rds")
opt_map <- readr::read_csv("outputs/multiselect_options.csv", show_col_types = FALSE)
n_total <- nrow(df)

cat("=== PHASE 2: OVERALL ANALYSIS (n =", n_total, ") ===\n\n")

# 1. Respondent profile (counts and percentages) -------------------------------
make_freq_table <- function(data, var_name) {
  data |>
    dplyr::count(.data[[var_name]], name = "count") |>
    dplyr::rename(category = 1) |>
    dplyr::mutate(
      variable = var_name,
      category = as.character(category),
      pct = round(100 * count / sum(count), 1),
      small_group_flag = count < 8
    ) |>
    dplyr::select(variable, category, count, pct, small_group_flag)
}

profile_vars <- c("year", "residence", "gender", "diet", "payment", "skipped_meal", "spend_band")
overall_profile <- purrr::map_dfr(profile_vars, ~ make_freq_table(df, .x))

cat("=== RESPONDENT PROFILE ===\n")
print(overall_profile, n = Inf)
readr::write_csv(overall_profile, "outputs/overall_profile.csv")

# 2. Overall numeric summaries -------------------------------------------------
summarize_numeric <- function(data, var_name, label) {
  x <- data[[var_name]]
  tibble::tibble(
    variable = var_name,
    label = label,
    n = sum(!is.na(x)),
    mean = round(mean(x, na.rm = TRUE), 2),
    sd = round(sd(x, na.rm = TRUE), 2),
    median = round(median(x, na.rm = TRUE), 2),
    q25 = round(stats::quantile(x, 0.25, na.rm = TRUE), 2),
    q75 = round(stats::quantile(x, 0.75, na.rm = TRUE), 2),
    min = min(x, na.rm = TRUE),
    max = max(x, na.rm = TRUE)
  )
}

numeric_summary <- dplyr::bind_rows(
  summarize_numeric(df, "spend", "Monthly food spend (Rs, excl. mess)"),
  summarize_numeric(df, "meals_per_day", "Campus outlet meals per day"),
  summarize_numeric(df, "outside_orders", "Outside food orders per week"),
  summarize_numeric(df, "satisfaction", "Overall campus food satisfaction (1-5)")
)

cat("\n=== OVERALL NUMERIC SUMMARIES ===\n")
print(numeric_summary, n = Inf)
readr::write_csv(numeric_summary, "outputs/overall_numeric_summary.csv")

# 3. Satisfaction distribution and key yes/no rates ----------------------------
sat_dist <- tibble::tibble(rating = 1:5) |>
  dplyr::left_join(
    df |> dplyr::count(satisfaction, name = "count"),
    by = c("rating" = "satisfaction")
  ) |>
  dplyr::mutate(
    count = tidyr::replace_na(count, 0L),
    pct = round(100 * count / n_total, 1)
  )

cat("\n=== SATISFACTION RATING DISTRIBUTION (1 to 5) ===\n")
print(sat_dist)
readr::write_csv(sat_dist, "outputs/overall_satisfaction_dist.csv")

flag_summary <- tibble::tibble(
  flag = c("satisfied (rating >= 4)", "skips_breakfast", "heavy_outside (>= 2/week)"),
  count = c(sum(df$satisfied), sum(df$skips_breakfast), sum(df$heavy_outside)),
  pct = round(100 * count / n_total, 1)
)
cat("\n=== KEY BEHAVIORAL FLAGS ===\n")
print(flag_summary)
readr::write_csv(flag_summary, "outputs/overall_flags.csv")

# 4. Outlet popularity, top factors, top wanted improvements -------------------
get_ranked_multiselect <- function(group_name) {
  opt_map |>
    dplyr::filter(group == group_name) |>
    dplyr::arrange(dplyr::desc(count), option_label) |>
    dplyr::mutate(rank = dplyr::row_number()) |>
    dplyr::select(rank, option_label, column_name, count, pct)
}

outlets_rank <- get_ranked_multiselect("outlets")
factors_rank <- get_ranked_multiselect("factors")
improve_rank <- get_ranked_multiselect("improvements")

cat("\n=== OUTLET POPULARITY ===\n")
print(outlets_rank, n = Inf)
cat("\n=== IMPORTANT FACTORS WHEN CHOOSING AN OUTLET ===\n")
print(factors_rank, n = Inf)
cat("\n=== TOP WANTED IMPROVEMENTS ===\n")
print(improve_rank, n = Inf)

readr::write_csv(outlets_rank, "outputs/overall_outlets.csv")
readr::write_csv(factors_rank, "outputs/overall_factors.csv")
readr::write_csv(improve_rank, "outputs/overall_improvements.csv")

# Also check how many outlets / factors / improvements each student picks
multi_prefixes <- c(
  "Outlets selected per student" = "outlet_",
  "Factors selected per student" = "factor_",
  "Improvements selected per student" = "improve_"
)
multi_counts <- purrr::map_dfr(seq_along(multi_prefixes), function(i) {
  totals <- rowSums(df |> dplyr::select(dplyr::starts_with(multi_prefixes[i])))
  tibble::tibble(
    question = names(multi_prefixes)[i],
    mean_selected = round(mean(totals), 2),
    median_selected = median(totals)
  )
})
cat("\n=== MULTI-SELECT COUNTS PER RESPONDENT ===\n")
print(multi_counts)

# 5. Flag sample bias and small groups -----------------------------------------
bias_flags <- overall_profile |>
  dplyr::filter(pct >= 60 | count < 8) |>
  dplyr::mutate(
    bias_note = dplyr::case_when(
      count < 8 ~ paste0("Too few responses (n = ", count, " < 8); avoid subgroup claims."),
      pct >= 60 ~ paste0("Dominant group (", pct, "% of sample); results mostly reflect this group.")
    )
  )

cat("\n=== SAMPLE BIAS & SMALL-GROUP WARNINGS ===\n")
print(bias_flags, n = Inf)
readr::write_csv(bias_flags, "outputs/overall_sample_bias.csv")

# 6. Save overall charts to outputs/plots/ -------------------------------------
theme_campus <- ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold"),
    panel.grid.minor = ggplot2::element_blank()
  )

# Plot 1: Satisfaction distribution
p_sat <- ggplot2::ggplot(sat_dist, ggplot2::aes(x = factor(rating), y = count)) +
  ggplot2::geom_col(fill = "#2c7fb8", width = 0.65) +
  ggplot2::geom_text(
    ggplot2::aes(label = paste0(count, " (", pct, "%)")),
    vjust = -0.4, size = 3.6
  ) +
  ggplot2::scale_y_continuous(expand = ggplot2::expansion(mult = c(0, 0.15))) +
  ggplot2::labs(
    title = paste0("Overall Campus Food Satisfaction (n = ", n_total, ")"),
    subtitle = paste0(
      "1 = Very Unsatisfied, 5 = Very Satisfied (Mean = ",
      round(mean(df$satisfaction), 2), ", Median = ",
      median(df$satisfaction), ")"
    ),
    x = "Satisfaction Rating (1-5)",
    y = "Number of Students"
  ) +
  theme_campus

ggplot2::ggsave("outputs/plots/01_overall_satisfaction.png", p_sat, width = 7, height = 4.5, dpi = 150)

# Helper to avoid duplicating ranked horizontal bar charts
plot_ranked_bar <- function(df_rank, title_text, fill_hex, subtitle_text = NULL) {
  df_rank |>
    dplyr::mutate(option_label = forcats::fct_reorder(option_label, count)) |>
    ggplot2::ggplot(ggplot2::aes(x = count, y = option_label)) +
    ggplot2::geom_col(fill = fill_hex, width = 0.7) +
    ggplot2::geom_text(
      ggplot2::aes(label = paste0(count, " (", pct, "%)")),
      hjust = -0.1, size = 3.3
    ) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.22))) +
    ggplot2::labs(
      title = title_text,
      subtitle = subtitle_text,
      x = "Number of Students",
      y = NULL
    ) +
    theme_campus
}

# Plot 2: Outlet popularity
p_outlets <- plot_ranked_bar(
  outlets_rank,
  paste0("Most Regularly Used Food Outlets (n = ", n_total, ")"),
  "#1b9e77",
  "Multi-select question (students could pick more than one outlet)"
)
ggplot2::ggsave("outputs/plots/02_outlet_popularity.png", p_outlets, width = 8, height = 5, dpi = 150)

# Plot 3: Important factors
p_factors <- plot_ranked_bar(
  factors_rank,
  paste0("Most Important Factors When Choosing an Outlet (n = ", n_total, ")"),
  "#7570b3"
)
ggplot2::ggsave("outputs/plots/03_important_factors.png", p_factors, width = 8, height = 5, dpi = 150)

# Plot 4: Wanted improvements
p_improve <- plot_ranked_bar(
  improve_rank,
  paste0("Biggest Wanted Improvements in Campus Food (n = ", n_total, ")"),
  "#d95f02"
)
ggplot2::ggsave("outputs/plots/04_wanted_improvements.png", p_improve, width = 8, height = 5, dpi = 150)

# Save overall list object for easy loading in Shiny / Rmd
saveRDS(
  list(
    profile = overall_profile,
    numeric_summary = numeric_summary,
    satisfaction_dist = sat_dist,
    flag_summary = flag_summary,
    outlets = outlets_rank,
    factors = factors_rank,
    improvements = improve_rank,
    multi_counts = multi_counts,
    bias_flags = bias_flags
  ),
  "outputs/overall_results.rds"
)

cat("\nPhase 2 complete. Tables and plots saved to outputs/.\n")
