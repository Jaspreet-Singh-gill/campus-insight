# Phase 3: Exploratory Data Analysis (EDA) for Facts
# Purpose: Compute group averages, run chi-square tests (skipping groups < 8),
#          check numeric correlations, and save ggplot charts to outputs/plots/.

library(tidyverse)

set.seed(1)

df <- readRDS("outputs/clean.rds")
opt_map <- read_csv("outputs/multiselect_options.csv", show_col_types = FALSE)

cat("=== PHASE 3: EDA FOR FACTS (n =", nrow(df), ") ===\n\n")

# Helper 1: Keep only groups with at least 8 students -------------------------
filter_min_group <- function(data, x_col, min_n = 8) {
  counts <- count(data, val = as.character(.data[[x_col]]))
  dropped <- counts |> filter(n < min_n) |> pull(val)
  kept <- data |>
    mutate(x_val = as.character(.data[[x_col]])) |>
    add_count(x_val, name = "nx") |>
    filter(nx >= min_n)
  list(data = kept, dropped = dropped)
}

# Helper 2: Compute group averages and percentages -----------------------------
summarize_by_group <- function(data, group_col, group_label) {
  data |>
    group_by(group_val = as.character(.data[[group_col]])) |>
    summarise(
      n = n(),
      mean_satisfaction = round(mean(satisfaction), 2),
      pct_satisfied = round(100 * mean(satisfied), 1),
      mean_spend = round(mean(spend), 0),
      median_spend = round(median(spend), 0),
      mean_meals_per_day = round(mean(meals_per_day), 2),
      pct_skips_breakfast = round(100 * mean(skips_breakfast), 1),
      mean_outside_orders = round(mean(outside_orders), 2),
      pct_heavy_outside = round(100 * mean(heavy_outside), 1),
      .groups = "drop"
    ) |>
    mutate(grouping = group_label, too_few_flag = n < 8) |>
    relocate(grouping, group_val, n, too_few_flag)
}

# Helper 3: Run chi-square test cleanly (uses simulated p if expected < 5) -----
run_chisq <- function(data, x_col, y_col, comparison_name) {
  grp <- filter_min_group(data, x_col, min_n = 8)
  tbl <- table(grp$data$x_val, as.character(grp$data[[y_col]]))
  skipped_txt <- ifelse(length(grp$dropped) == 0, "None", paste(grp$dropped, collapse = ", "))

  if (nrow(tbl) < 2 || ncol(tbl) < 2) {
    return(tibble(
      comparison = comparison_name, x_var = x_col, y_var = y_col,
      n_used = nrow(grp$data), skipped_small_groups = skipped_txt,
      statistic = NA_real_, df = NA_real_, p_value = NA_real_, min_expected = NA_real_,
      test_type = "Not enough groups >= 8", verdict = "Cannot test (too few responses)"
    ))
  }

  raw_test <- suppressWarnings(chisq.test(tbl))
  min_exp <- min(raw_test$expected)

  if (min_exp < 5) {
    test_used <- chisq.test(tbl, simulate.p.value = TRUE, B = 5000)
    df_val <- NA_real_
    t_type <- "Chi-square (simulated p-value; expected < 5)"
  } else {
    test_used <- raw_test
    df_val <- unname(raw_test$parameter)
    t_type <- "Pearson Chi-square"
  }

  p_val <- test_used$p.value
  verdict_txt <- case_when(
    p_val < 0.05 ~ "Real difference (statistically supported, p < 0.05)",
    p_val < 0.10 ~ "Noticeable pattern only (borderline p < 0.10, may be luck)",
    TRUE         ~ "No statistical support (difference may be luck, p >= 0.10)"
  )

  tibble(
    comparison = comparison_name, x_var = x_col, y_var = y_col,
    n_used = nrow(grp$data), skipped_small_groups = skipped_txt,
    statistic = round(unname(test_used$statistic), 3), df = df_val,
    p_value = round(p_val, 4), min_expected = round(min_exp, 2),
    test_type = t_type, verdict = verdict_txt
  )
}

# 1. Group averages by demographics & behavior ---------------------------------
cat("=== 1. GROUP AVERAGES BY DEMOGRAPHICS ===\n")
cat("Note: Day Scholar (n=4), Cash (n=2), and Vegan (n=1) are flagged (< 8).\n\n")

df_demo <- df |>
  mutate(breakfast_flag = if_else(skips_breakfast == 1, "Skips Breakfast", "Skips Other/Rarely"))

demo_groups <- c(
  year = "Year", gender = "Gender", diet = "Diet",
  spend_band = "Spend Band", breakfast_flag = "Breakfast Skipping"
)
demo_summary <- map_dfr(names(demo_groups), ~ summarize_by_group(df_demo, .x, demo_groups[[.x]]))

print(demo_summary, n = Inf, width = Inf)
write_csv(demo_summary, "outputs/eda_group_averages.csv")

# 2. Group averages for eligible outlets (>= 8 users and >= 8 non-users) -------
cat("\n=== 2. OUTLET USER VS NON-USER AVERAGES ===\n")
eligible_outlets <- opt_map |> filter(group == "outlets", count >= 8, (nrow(df) - count) >= 8)
small_outlets <- opt_map |> filter(group == "outlets", count < 8 | (nrow(df) - count) < 8)

cat("Eligible outlets (>= 8):", paste(eligible_outlets$option_label, collapse = ", "), "\n")
cat("Skipped outlets (< 8)  :", paste0(small_outlets$option_label, " (n=", small_outlets$count, ")", collapse = ", "), "\n\n")

outlet_summary <- map_dfr(seq_len(nrow(eligible_outlets)), function(i) {
  tmp <- df |>
    mutate(user_status = if_else(.data[[eligible_outlets$column_name[i]]] == 1, "Uses Outlet", "Does Not Use"))
  summarize_by_group(tmp, "user_status", eligible_outlets$option_label[i])
})

print(outlet_summary, n = Inf, width = Inf)
write_csv(outlet_summary, "outputs/eda_outlet_comparisons.csv")

# 3. Cross-tables and Chi-Square Tests -----------------------------------------
cat("\n=== 3. CHI-SQUARE TESTS ===\n")

df_test <- df |>
  mutate(
    satisfied_lbl = if_else(satisfied == 1, "Satisfied (4-5)", "Not Satisfied (1-3)"),
    breakfast_lbl = if_else(skips_breakfast == 1, "Skips Breakfast", "Other/Rarely"),
    outside_lbl   = if_else(heavy_outside == 1, "Heavy Outside (>=2)", "Low Outside (0-1)")
  )

eligible_factors  <- opt_map |> filter(group == "factors", count >= 8, (nrow(df) - count) >= 8)
eligible_improves <- opt_map |> filter(group == "improvements", count >= 8, (nrow(df) - count) >= 8)

# Clean lookup labels so test comparison names stay readable
var_labels <- c(
  year = "Year", gender = "Gender", diet = "Diet", spend_band = "Spend Band",
  satisfied_lbl = "Satisfied", breakfast_lbl = "Skips Breakfast", outside_lbl = "Heavy Outside Ordering",
  setNames(paste(eligible_outlets$option_label, "User"), eligible_outlets$column_name),
  setNames(paste("Factor:", eligible_factors$option_label), eligible_factors$column_name),
  setNames(paste("Improvement:", eligible_improves$option_label), eligible_improves$column_name)
)

demo_vars <- c("year", "gender", "diet", "spend_band")
out_vars  <- c("satisfied_lbl", "breakfast_lbl", "outside_lbl", "spend_band")

test_pairs <- bind_rows(
  crossing(x = demo_vars, y = out_vars) |> filter(x != y),
  tibble(x = "breakfast_lbl", y = c("satisfied_lbl", "outside_lbl")),
  crossing(x = eligible_outlets$column_name, y = out_vars),
  crossing(x = c("gender", "year", "diet"), y = eligible_outlets$column_name),
  tibble(x = c(eligible_factors$column_name, eligible_improves$column_name), y = "satisfied_lbl")
) |>
  mutate(
    y_label = if_else(
      y %in% eligible_outlets$column_name,
      paste("Uses", str_remove(var_labels[y], " User$")),
      var_labels[y]
    ),
    name = paste(var_labels[x], "vs", y_label)
  )

chisq_results <- map_dfr(seq_len(nrow(test_pairs)), function(i) {
  run_chisq(df_test, test_pairs$x[i], test_pairs$y[i], test_pairs$name[i])
}) |>
  arrange(p_value)

cat("--- Top 30 Chi-Square Tests (sorted by p-value) ---\n")
print(chisq_results, n = 30, width = Inf)
write_csv(chisq_results, "outputs/eda_chisq_tests.csv")

# Print cross-tables for noticeable findings (p < 0.15)
cat("\n=== DETAILED CROSS-TABLES FOR TOP FINDINGS (p < 0.15) ===\n")
top_tests <- chisq_results |> filter(p_value < 0.15)
for (i in seq_len(nrow(top_tests))) {
  r <- top_tests[i, ]
  cat(sprintf("\n[%d] %s | p = %.4f (%s)\n", i, r$comparison, r$p_value, r$verdict))
  grp <- filter_min_group(df_test, r$x_var, min_n = 8)
  ct <- table(grp$data$x_val, as.character(grp$data[[r$y_var]]))
  print(ct)
  cat("Row percentages (%):\n")
  print(round(100 * prop.table(ct, margin = 1), 1))
}

# 4. Numeric Correlations ------------------------------------------------------
cat("\n=== 4. CORRELATIONS BETWEEN NUMERIC COLUMNS ===\n")
num_cols <- c("spend", "meals_per_day", "outside_orders", "satisfaction")
num_labels <- c(
  spend = "Monthly Spend (Rs)", meals_per_day = "Campus Meals/Day",
  outside_orders = "Outside Orders/Week", satisfaction = "Satisfaction (1-5)"
)

cor_matrix <- cor(df[, num_cols], use = "complete.obs", method = "pearson")
print(round(cor_matrix, 3))

cor_pairs <- combn(num_cols, 2, simplify = FALSE) |>
  map_dfr(function(pair) {
    res <- cor.test(df[[pair[1]]], df[[pair[2]]], method = "pearson")
    tibble(
      var1 = pair[1], var2 = pair[2],
      label1 = unname(num_labels[pair[1]]), label2 = unname(num_labels[pair[2]]),
      r = round(unname(res$estimate), 3), p_value = round(res$p.value, 4),
      significant = res$p.value < 0.05,
      plain_meaning = if_else(res$p.value < 0.05, "Statistically supported link", "Weak/no real linear link (may be luck)")
    )
  }) |>
  arrange(p_value)

print(cor_pairs, width = Inf)
write_csv(cor_pairs, "outputs/eda_correlations.csv")

# 5. Charts (saved to outputs/plots/) ------------------------------------------
theme_campus <- theme_minimal(base_size = 11.5) +
  theme(plot.title = element_text(face = "bold"), panel.grid.minor = element_blank())

# Shared helper for faceted demographic bar charts (Plots 5 and 8)
plot_demo_facets <- function(sum_df, y_col, y_lab, title_txt, sub_txt, prefix = "", suffix = "", pal = "Set2") {
  sum_df |>
    filter(grouping %in% c("Year", "Gender", "Diet"), !too_few_flag) |>
    mutate(label_n = paste0(group_val, "\n(n=", n, ")"), y_val = .data[[y_col]]) |>
    ggplot(aes(x = label_n, y = y_val, fill = grouping)) +
    geom_col(width = 0.65, show.legend = FALSE) +
    geom_text(aes(label = paste0(prefix, y_val, suffix)), vjust = -0.35, size = 3.3) +
    facet_wrap(~ grouping, scales = "free_x") +
    scale_y_continuous(expand = expansion(mult = c(0, 0.18))) +
    scale_fill_brewer(palette = pal) +
    labs(title = title_txt, subtitle = sub_txt, x = NULL, y = y_lab) +
    theme_campus
}

p_demo_sat <- plot_demo_facets(
  demo_summary, "pct_satisfied", "% Satisfied",
  "Share of Satisfied Students (Rating 4 or 5) by Group",
  "Groups with fewer than 8 students (Vegan n=1, Day Scholar n=4) excluded",
  suffix = "%", pal = "Set2"
)
ggsave("outputs/plots/05_eda_satisfaction_by_group.png", p_demo_sat, width = 9.5, height = 4.8, dpi = 150)

p_outlet_sat <- outlet_summary |>
  ggplot(aes(x = grouping, y = pct_satisfied, fill = group_val)) +
  geom_col(position = position_dodge(width = 0.72), width = 0.65) +
  geom_text(
    aes(label = paste0(pct_satisfied, "%\n(n=", n, ")")),
    position = position_dodge(width = 0.72), vjust = -0.25, size = 2.9
  ) +
  scale_y_continuous(limits = c(0, 62)) +
  scale_fill_manual(values = c("Uses Outlet" = "#1b9e77", "Does Not Use" = "#999999")) +
  labs(
    title = "Satisfaction Rate: Outlet Users vs. Non-Users",
    subtitle = "Only outlets with at least 8 users shown (Campus Café, Chai Vyanjan, etc. < 8)",
    x = NULL, y = "% Satisfied (Rating 4-5)", fill = NULL
  ) +
  theme_campus +
  theme(legend.position = "top")
ggsave("outputs/plots/06_eda_outlet_satisfaction.png", p_outlet_sat, width = 9, height = 5.2, dpi = 150)

cor_df <- as.data.frame(as.table(cor_matrix)) |>
  rename(r = Freq) |>
  mutate(
    Label1 = factor(unname(num_labels[as.character(Var1)]), levels = unname(num_labels)),
    Label2 = factor(unname(num_labels[as.character(Var2)]), levels = rev(unname(num_labels)))
  )
p_corr <- ggplot(cor_df, aes(x = Label1, y = Label2, fill = r)) +
  geom_tile(color = "white", linewidth = 0.8) +
  geom_text(aes(label = sprintf("%.2f", r)), size = 4.2, fontface = "bold") +
  scale_fill_gradient2(low = "#d73027", mid = "#f7f7f7", high = "#1a9850", midpoint = 0, limits = c(-1, 1)) +
  labs(
    title = paste0("Correlations Between Numeric Variables (n = ", nrow(df), ")"),
    subtitle = "Pearson r values from -1 (strong opposite) to +1 (strong together)",
    x = NULL, y = NULL, fill = "Pearson r"
  ) +
  theme_campus +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave("outputs/plots/07_eda_correlations_heatmap.png", p_corr, width = 7.2, height = 5.5, dpi = 150)

p_spend_groups <- plot_demo_facets(
  demo_summary, "mean_spend", "Mean Monthly Spend (Rs)",
  "Average Monthly Extra Food Spend by Group",
  "Excludes prepaid hostel mess fees; groups < 8 excluded",
  prefix = "Rs ", pal = "Pastel1"
)
ggsave("outputs/plots/08_eda_spend_by_group.png", p_spend_groups, width = 9.5, height = 4.8, dpi = 150)

saveRDS(
  list(
    group_averages = demo_summary, outlet_comparisons = outlet_summary,
    chisq_tests = chisq_results, correlations = cor_pairs, cor_matrix = cor_matrix
  ),
  "outputs/eda_results.rds"
)

cat("\nPhase 3 complete. Saved EDA tables, tests, and plots to outputs/.\n")
