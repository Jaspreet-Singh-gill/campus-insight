# Phase 4: Research Questions Derived from EDA Facts
# Purpose: Read FINDINGS.md, answer 5 focused research questions using simple
#          tables, chi-square tests, and charts, and save outputs/questions_results.rds.

library(tidyverse)

set.seed(1)

# 1. Read FINDINGS.md to anchor questions in Phase 2 & 3 facts ----------------
findings_lines <- readLines("FINDINGS.md", warn = FALSE)
cat("=== PHASE 4: QUESTIONS FROM FINDINGS.md ===\n")
cat("Loaded FINDINGS.md (", length(findings_lines), "lines ).\n\n")

df <- readRDS("outputs/clean.rds")

# Helper 1: Simple chi-square test (simulated p-value if any expected < 5)
simple_chisq <- function(x, y) {
  tbl <- table(x, y)
  if (nrow(tbl) < 2 || ncol(tbl) < 2) return(NA_real_)
  raw <- suppressWarnings(chisq.test(tbl))
  if (min(raw$expected) < 5) {
    round(chisq.test(tbl, simulate.p.value = TRUE, B = 5000)$p.value, 4)
  } else {
    round(raw$p.value, 4)
  }
}

# Helper 2: Compare named binary 0/1 columns across a grouping variable
# named_items format: c("Readable Label" = "column_name")
compare_items <- function(data, group_col, named_items) {
  map_dfr(seq_along(named_items), function(i) {
    lbl <- names(named_items)[i]
    col_nm <- unname(named_items[i])
    p_val <- simple_chisq(data[[group_col]], data[[col_nm]])
    data |>
      group_by(group = .data[[group_col]]) |>
      summarise(
        n = n(),
        count_yes = sum(.data[[col_nm]]),
        pct_yes = round(100 * mean(.data[[col_nm]]), 1),
        .groups = "drop"
      ) |>
      mutate(item = lbl, column_name = col_nm, p_value = p_val)
  })
}

# Shared plot theme and bar-chart helpers
theme_campus <- theme_minimal(base_size = 11.5) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())

plot_horizontal_bars <- function(comp_df, title_txt, sub_txt, fill_colors, x_max = 82) {
  comp_df |>
    mutate(item = fct_reorder(item, pct_yes)) |>
    ggplot(aes(x = pct_yes, y = item, fill = group)) +
    geom_col(position = position_dodge(width = 0.7), width = 0.65) +
    geom_text(
      aes(label = paste0(pct_yes, "%")),
      position = position_dodge(width = 0.7), hjust = -0.15, size = 3
    ) +
    scale_x_continuous(limits = c(0, x_max)) +
    scale_fill_manual(values = fill_colors) +
    labs(title = title_txt, subtitle = sub_txt, x = "% Selecting Option", y = NULL, fill = NULL) +
    theme_campus +
    theme(legend.position = "top")
}

plot_vertical_bars <- function(comp_df, items_keep, title_txt, sub_txt, fill_lab,
                               fill_vals = NULL, x_angle = 0, y_max = 80) {
  p <- comp_df |>
    filter(item %in% items_keep) |>
    ggplot(aes(x = item, y = pct_yes, fill = group)) +
    geom_col(position = position_dodge(width = 0.72), width = 0.65) +
    geom_text(
      aes(label = paste0(pct_yes, "%")),
      position = position_dodge(width = 0.72), vjust = -0.35, size = 3
    ) +
    scale_y_continuous(limits = c(0, y_max)) +
    labs(title = title_txt, subtitle = sub_txt, x = NULL, y = "% of Group", fill = fill_lab) +
    theme_campus +
    theme(legend.position = "top")

  if (!is.null(fill_vals)) p <- p + scale_fill_manual(values = fill_vals) else p <- p + scale_fill_brewer(palette = "Set2")
  if (x_angle > 0) p <- p + theme(axis.text.x = element_text(angle = x_angle, hjust = 1))
  p
}

# ==============================================================================
# Q1: Why are high spenders (> Rs 2,000) more satisfied?
# ==============================================================================
cat("--- Q1: High Spenders (> Rs 2,000) vs Low/Medium Spenders (<= Rs 2,000) ---\n")
df_q1 <- df |>
  mutate(high_spender = if_else(spend > 2000, "High (> Rs 2,000)", "Low/Med (<= Rs 2,000)"))

q1_numeric <- df_q1 |>
  group_by(high_spender) |>
  summarise(
    n = n(),
    mean_satisfaction = round(mean(satisfaction), 2),
    pct_satisfied = round(100 * mean(satisfied), 1),
    mean_meals_per_day = round(mean(meals_per_day), 2),
    mean_outside_orders = round(mean(outside_orders), 2),
    pct_heavy_outside = round(100 * mean(heavy_outside), 1),
    .groups = "drop"
  )
print(q1_numeric)

q1_comp <- compare_items(df_q1, "high_spender", c(
  "Uses Hostel Mess"           = "outlet_hostel_mess",
  "Uses Nescafé"               = "outlet_nescafe",
  "Uses Snacker"               = "outlet_snacker",
  "Uses Yadav Canteen"         = "outlet_yadav_canteen",
  "Uses Night Canteen"         = "outlet_night_canteen",
  "Factor: Price/Affordability"= "factor_price_affordability",
  "Factor: Food Quality"       = "factor_food_quality",
  "Factor: Hygiene"            = "factor_hygiene_cleanliness",
  "Wants Lower Prices"         = "improve_lower_prices",
  "Wants Better Food Quality"  = "improve_better_food_quality",
  "Wants Better Hygiene"       = "improve_better_hygiene_cleanliness"
))
print(q1_comp, n = Inf)

p_q1 <- plot_horizontal_bars(
  q1_comp,
  "Q1: How High Spenders (> Rs 2,000) Differ from Low/Medium Spenders",
  paste0("High spenders (n=", sum(df$spend > 2000), ") vs Low/Medium spenders (n=", sum(df$spend <= 2000), ")"),
  c("High (> Rs 2,000)" = "#2b8cbe", "Low/Med (<= Rs 2,000)" = "#a6bddb")
)
ggsave("outputs/plots/09_q1_high_spenders.png", p_q1, width = 8.5, height = 5.2, dpi = 150)

# ==============================================================================
# Q2: What sets Nescafé users apart from non-users?
# ==============================================================================
cat("\n--- Q2: Nescafé Users vs Non-Users ---\n")
df_q2 <- df |>
  mutate(
    nescafe_user = if_else(outlet_nescafe == 1, "Nescafé User", "Non-User"),
    n_outlets = rowSums(pick(starts_with("outlet_")))
  )

q2_numeric <- df_q2 |>
  group_by(nescafe_user) |>
  summarise(
    n = n(),
    mean_satisfaction = round(mean(satisfaction), 2),
    pct_satisfied = round(100 * mean(satisfied), 1),
    mean_spend = round(mean(spend), 0),
    pct_high_spend = round(100 * mean(spend > 2000), 1),
    mean_outlets_picked = round(mean(n_outlets), 2),
    .groups = "drop"
  )
print(q2_numeric)

q2_comp <- compare_items(df_q2, "nescafe_user", c(
  "Also uses Hostel Mess"   = "outlet_hostel_mess",
  "Also uses Snacker"       = "outlet_snacker",
  "Also uses Yadav Canteen" = "outlet_yadav_canteen",
  "Also uses Night Canteen" = "outlet_night_canteen",
  "Factor: Food Quality"    = "factor_food_quality",
  "Factor: Taste"           = "factor_taste",
  "Factor: Price"           = "factor_price_affordability",
  "Factor: Hygiene"         = "factor_hygiene_cleanliness",
  "Wants Better Hygiene"    = "improve_better_hygiene_cleanliness",
  "Wants Better Quality"    = "improve_better_food_quality",
  "Wants Lower Prices"      = "improve_lower_prices"
))
print(q2_comp, n = Inf)

cat("Satisfaction by Nescafé use within Spend Bands:\n")
df_q2 |>
  group_by(spend_band, nescafe_user) |>
  summarise(n = n(), pct_satisfied = round(100 * mean(satisfied), 1), .groups = "drop") |>
  print()

p_q2 <- plot_horizontal_bars(
  q2_comp,
  paste0("Q2: Comparing Nescafé Users (n=", sum(df$outlet_nescafe == 1), ") vs. Non-Users (n=", sum(df$outlet_nescafe == 0), ")"),
  "Co-used outlets, chosen factors, and wanted improvements",
  c("Nescafé User" = "#1b9e77", "Non-User" = "#bdbdbd"),
  x_max = 75
)
ggsave("outputs/plots/10_q2_nescafe_users.png", p_q2, width = 8.5, height = 5.2, dpi = 150)

# ==============================================================================
# Q3: Who skips breakfast most often and what goes with it?
# ==============================================================================
cat("\n--- Q3: Who Skips Breakfast and What Goes With It? ---\n")
df_q3 <- df |>
  mutate(bf_group = if_else(skips_breakfast == 1, "Skips Breakfast (n=62)", "Skips Other/Rarely (n=26)"))

q3_numeric <- df_q3 |>
  group_by(bf_group) |>
  summarise(
    n = n(),
    mean_spend = round(mean(spend), 0),
    mean_meals_per_day = round(mean(meals_per_day), 2),
    pct_zero_campus_meals = round(100 * mean(meals_per_day == 0), 1),
    mean_outside_orders = round(mean(outside_orders), 2),
    mean_satisfaction = round(mean(satisfaction), 2),
    .groups = "drop"
  )
print(q3_numeric)

q3_comp <- compare_items(df_q3, "bf_group", c(
  "Uses Hostel Mess"         = "outlet_hostel_mess",
  "Uses Nescafé"             = "outlet_nescafe",
  "Uses Snacker"             = "outlet_snacker",
  "Uses Yadav Canteen"       = "outlet_yadav_canteen",
  "Uses Night Canteen"       = "outlet_night_canteen",
  "Wants Better Availability"= "improve_better_availability",
  "Wants Faster Service"     = "improve_faster_service",
  "Wants Lower Prices"       = "improve_lower_prices"
))
print(q3_comp, n = Inf)

p_q3 <- plot_horizontal_bars(
  q3_comp |> filter(str_starts(item, "Uses ")),
  "Q3: Outlet Usage by Breakfast-Skipping Status",
  "Comparing students who skip breakfast most often vs. those who skip other meals or rarely",
  c("Skips Breakfast (n=62)" = "#e6550d", "Skips Other/Rarely (n=26)" = "#6baed6"),
  x_max = 75
)
ggsave("outputs/plots/11_q3_breakfast_skipping.png", p_q3, width = 8.2, height = 4.6, dpi = 150)

# ==============================================================================
# Q4: Diet groups vs food channels & improvement requests (Vegan n=1 excluded)
# ==============================================================================
cat("\n--- Q4: Diet Groups (Vegetarian vs Non-Vegetarian vs Eggetarian; Vegan n=1 excluded) ---\n")
q4_comp <- compare_items(df |> filter(diet != "Vegan"), "diet", c(
  "Uses Hostel Mess"            = "outlet_hostel_mess",
  "Uses Night Canteen"          = "outlet_night_canteen",
  "Heavy Outside Orders (>=2/wk)" = "heavy_outside",
  "Satisfied (4-5)"             = "satisfied",
  "Wants More Variety"          = "improve_more_variety",
  "Wants Better Quality"        = "improve_better_food_quality",
  "Wants Healthy Options"       = "improve_more_healthy_nutritious_options",
  "Wants Lower Prices"          = "improve_lower_prices"
))
print(q4_comp, n = Inf)

p_q4 <- plot_vertical_bars(
  q4_comp,
  c("Uses Hostel Mess", "Uses Night Canteen", "Heavy Outside Orders (>=2/wk)", "Wants Lower Prices"),
  "Q4: Food Channels and Price Demand by Diet (Vegan n=1 Excluded)",
  "Vegetarians (n=39) use Hostel Mess & outside delivery more and ask for Lower Prices more (56.4% vs 25.6%)",
  fill_lab = "Diet", y_max = 80
)
ggsave("outputs/plots/12_q4_diet_channels.png", p_q4, width = 8.5, height = 4.8, dpi = 150)

# ==============================================================================
# Q5: Wanted improvements across satisfaction tiers
# ==============================================================================
cat("\n--- Q5: Dissatisfied (1-2) vs Neutral (3) vs Satisfied (4-5) ---\n")
df_q5 <- df |>
  mutate(
    sat_tier = factor(
      case_when(
        satisfaction <= 2 ~ "Dissatisfied (1-2)",
        satisfaction == 3 ~ "Neutral (3)",
        TRUE              ~ "Satisfied (4-5)"
      ),
      levels = c("Dissatisfied (1-2)", "Neutral (3)", "Satisfied (4-5)"),
      ordered = TRUE
    )
  )
print(table(df_q5$sat_tier))

q5_comp <- compare_items(df_q5, "sat_tier", c(
  "Better Hygiene/Cleanliness" = "improve_better_hygiene_cleanliness",
  "Better Food Quality"        = "improve_better_food_quality",
  "Lower Prices"               = "improve_lower_prices",
  "Larger Portions"            = "improve_larger_portions",
  "Better Taste"               = "improve_better_taste",
  "More Healthy Options"       = "improve_more_healthy_nutritious_options",
  "More Variety"               = "improve_more_variety",
  "Faster Service"             = "improve_faster_service"
))
print(q5_comp, n = Inf)

p_q5 <- plot_vertical_bars(
  q5_comp,
  c("Better Hygiene/Cleanliness", "Better Food Quality", "Lower Prices", "Larger Portions", "Better Taste"),
  "Q5: Top Wanted Improvements Across Satisfaction Levels",
  "Dissatisfied (n=22), Neutral (n=42), and Satisfied (n=24) all demand hygiene and quality",
  fill_lab = "Satisfaction Tier",
  fill_vals = c("Dissatisfied (1-2)" = "#d73027", "Neutral (3)" = "#fee08b", "Satisfied (4-5)" = "#1a9850"),
  x_angle = 12, y_max = 70
)
ggsave("outputs/plots/13_q5_improvements_by_satisfaction.png", p_q5, width = 8.8, height = 5, dpi = 150)

# Save all question CSVs and combined RDS
write_csv(q1_comp, "outputs/q1_high_spenders.csv")
write_csv(q2_comp, "outputs/q2_nescafe_users.csv")
write_csv(q3_comp, "outputs/q3_breakfast_skipping.csv")
write_csv(q4_comp, "outputs/q4_diet_channels.csv")
write_csv(q5_comp, "outputs/q5_satisfaction_improvements.csv")

saveRDS(
  list(
    q1_numeric = q1_numeric, q1_comp = q1_comp,
    q2_numeric = q2_numeric, q2_comp = q2_comp,
    q3_numeric = q3_numeric, q3_comp = q3_comp,
    q4_comp = q4_comp, q5_comp = q5_comp
  ),
  "outputs/questions_results.rds"
)

cat("\nPhase 4 complete. Question tables and plots saved to outputs/.\n")
