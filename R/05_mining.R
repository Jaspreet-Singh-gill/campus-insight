# Phase 5: Data Mining and Pattern Finding
# Purpose:
#   1. Mine association rules (apriori) on outlets, factors, improvements & flags.
#   2. Fit a cross-validated decision tree (rpart) for 'satisfied' and compare
#      accuracy against the majority-class baseline.

library(tidyverse)
library(arules)
library(rpart)
library(rpart.plot)

set.seed(1)

df <- readRDS("outputs/clean.rds")
opt_map <- readr::read_csv("outputs/multiselect_options.csv", show_col_types = FALSE)

cat("=== PHASE 5: DATA MINING & PATTERN FINDING (n =", nrow(df), ") ===\n\n")

# ==============================================================================
# 1. ASSOCIATION RULES (arules / apriori)
# ==============================================================================
cat("--- 1. ASSOCIATION RULES ---\n")

# Use multi-select 0/1 columns plus key yes/no behavioral flags
item_cols <- c(
  opt_map$column_name,
  "satisfied", "skips_breakfast", "heavy_outside"
)

# Map internal column names to clean human-readable labels for rules
label_lookup <- c(
  stats::setNames(
    paste0(
      dplyr::case_when(
        opt_map$group == "outlets" ~ "Outlet: ",
        opt_map$group == "factors" ~ "Factor: ",
        opt_map$group == "improvements" ~ "Improve: "
      ),
      opt_map$option_label
    ),
    opt_map$column_name
  ),
  satisfied = "Flag: Satisfied (4-5)",
  skips_breakfast = "Flag: Skips Breakfast",
  heavy_outside = "Flag: Heavy Outside (>=2/wk)"
)

tx_df <- df |>
  dplyr::select(dplyr::all_of(item_cols)) |>
  dplyr::mutate(dplyr::across(dplyr::everything(), as.logical))
names(tx_df) <- unname(label_lookup[names(tx_df)])

tx <- methods::as(tx_df, "transactions")
cat("Transactions created:", length(tx), "rows x", ncol(tx), "items\n")

# Tune support and confidence to get ~10 to 30 non-redundant, useful rules
# Support 0.14 means at least ~13 students (well above the >= 8 rule)
rules_raw <- arules::apriori(
  tx,
  parameter = list(supp = 0.14, conf = 0.65, minlen = 2, maxlen = 3),
  control = list(verbose = FALSE)
)
cat("Raw rules found (supp >= 0.14, conf >= 0.65):", length(rules_raw), "\n")

# Keep rules with lift > 1.15 (stronger than random co-occurrence) & remove redundant
rules_filtered <- subset(rules_raw, lift > 1.15)
rules_nonred <- rules_filtered[!arules::is.redundant(rules_filtered)]
rules_sorted <- sort(rules_nonred, by = "lift", decreasing = TRUE)

cat("Non-redundant rules with lift > 1.15:", length(rules_sorted), "\n")

# If > 30 rules, tighten slightly to keep top 10-30 useful rules
if (length(rules_sorted) > 30) {
  rules_sorted <- utils::head(rules_sorted, 25)
}

rules_df <- methods::as(rules_sorted, "data.frame") |>
  tibble::as_tibble() |>
  dplyr::mutate(
    rule_id = dplyr::row_number(),
    support = round(support, 3),
    confidence = round(confidence, 3),
    coverage = round(coverage, 3),
    lift = round(lift, 3),
    count = as.integer(count)
  ) |>
  dplyr::select(rule_id, rules, count, support, confidence, lift)

print(rules_df, n = Inf, width = Inf)
readr::write_csv(rules_df, "outputs/mining_association_rules.csv")

# ==============================================================================
# 2. DECISION TREE (rpart) FOR 'satisfied'
# ==============================================================================
cat("\n--- 2. DECISION TREE (rpart) FOR 'satisfied' ---\n")

# Target: satisfied (Yes = rating 4-5, No = rating 1-3)
# Exclude tiny <8 demographic groups (residence, payment) and rare (<8) multi-selects
common_cols <- opt_map |> dplyr::filter(count >= 8) |> dplyr::pull(column_name)

tree_df <- df |>
  dplyr::mutate(
    satisfied_target = factor(
      dplyr::if_else(satisfied == 1, "Satisfied", "Not_Satisfied"),
      levels = c("Not_Satisfied", "Satisfied")
    ),
    year = factor(as.character(year)),
    gender = factor(gender),
    diet_clean = factor(dplyr::if_else(diet == "Vegan", "Other_Small", diet)),
    skipped_meal = factor(skipped_meal)
  ) |>
  dplyr::select(
    satisfied_target, year, gender, diet_clean,
    meals_per_day, spend, outside_orders, skipped_meal,
    dplyr::all_of(common_cols)
  )

# Majority-class baseline accuracy
majority_class <- names(sort(table(tree_df$satisfied_target), decreasing = TRUE))[1]
baseline_acc <- mean(tree_df$satisfied_target == majority_class)
cat("Target distribution:\n")
print(table(tree_df$satisfied_target))
cat(sprintf("Majority-class baseline (%s): %.1f%%\n", majority_class, 100 * baseline_acc))

# Fit full tree with 10-fold cross-validation inside rpart
set.seed(1)
tree_full <- rpart::rpart(
  satisfied_target ~ .,
  data = tree_df,
  method = "class",
  control = rpart::rpart.control(minsplit = 14, minbucket = 5, cp = 0.01, xval = 10)
)

cat("\nCP Table (cross-validation errors):\n")
print(rpart::printcp(tree_full))

# Explicit 10-fold CV accuracy comparison for unpruned and cp-pruned trees
set.seed(1)
folds <- sample(rep(1:10, length.out = nrow(tree_df)))

cv_eval <- function(cp_val) {
  preds <- rep(NA_character_, nrow(tree_df))
  for (f in 1:10) {
    train_d <- tree_df[folds != f, ]
    test_d <- tree_df[folds == f, ]
    m <- rpart::rpart(
      satisfied_target ~ .,
      data = train_d,
      method = "class",
      control = rpart::rpart.control(minsplit = 14, minbucket = 5, cp = cp_val, xval = 0)
    )
    preds[folds == f] <- as.character(stats::predict(m, newdata = test_d, type = "class"))
  }
  mean(preds == as.character(tree_df$satisfied_target))
}

# Check minimum xerror cp vs interpretable tree cp
cp_tbl <- as.data.frame(tree_full$cptable)
best_cp <- cp_tbl$CP[which.min(cp_tbl$xerror)]
tree_pruned <- rpart::prune(tree_full, cp = best_cp)

# Also check if best_cp pruned all splits to root; if so keep both root CV and
# best non-trivial split tree (for inspection & transparency)
cat("\nBest CV cp:", best_cp, "| Splits in pruned tree:", nrow(tree_pruned$frame) - sum(tree_pruned$frame$var == "<leaf>"), "\n")

tree_to_plot <- if (nrow(tree_pruned$frame) > 1) tree_pruned else tree_full
train_preds <- stats::predict(tree_to_plot, newdata = tree_df, type = "class")
train_acc <- mean(train_preds == tree_df$satisfied_target)
cv_acc_pruned <- cv_eval(best_cp)
cv_acc_full <- cv_eval(0.01)

cat(sprintf("Baseline accuracy (always '%s'): %.1f%%\n", majority_class, 100 * baseline_acc))
cat(sprintf("10-fold CV accuracy (pruned, cp=%.4f): %.1f%%\n", best_cp, 100 * cv_acc_pruned))
cat(sprintf("10-fold CV accuracy (unpruned, cp=0.01): %.1f%%\n", 100 * cv_acc_full))
cat(sprintf("In-sample training accuracy of plotted tree: %.1f%%\n", 100 * train_acc))

cat("\nConfusion matrix of plotted tree (in-sample):\n")
print(table(Predicted = train_preds, Actual = tree_df$satisfied_target))

cat("\nPlotted tree rules:\n")
print(tree_to_plot)

# Save decision tree plot with rpart.plot
grDevices::png("outputs/plots/16_mining_decision_tree.png", width = 1050, height = 650, res = 130)
rpart.plot::rpart.plot(
  tree_to_plot,
  type = 4,
  extra = 104,
  fallen.leaves = TRUE,
  box.palette = "BuGn",
  main = paste0(
    "Decision Tree Predicting Student Satisfaction\n(Baseline = ",
    round(100 * baseline_acc, 1), "%, 10-Fold CV = ",
    round(100 * cv_acc_pruned, 1), "%, In-Sample = ",
    round(100 * train_acc, 1), "%)"
  )
)
grDevices::dev.off()

tree_metrics <- tibble::tibble(
  metric = c(
    "Majority class",
    "Baseline accuracy (%)",
    "10-fold CV accuracy - pruned (%)",
    "10-fold CV accuracy - cp=0.01 (%)",
    "In-sample accuracy of plotted tree (%)",
    "Best CV cp",
    "Splits in best-CV pruned tree",
    "Splits in plotted tree"
  ),
  value = c(
    majority_class,
    round(100 * baseline_acc, 1),
    round(100 * cv_acc_pruned, 1),
    round(100 * cv_acc_full, 1),
    round(100 * train_acc, 1),
    round(best_cp, 4),
    sum(tree_pruned$frame$var != "<leaf>"),
    sum(tree_to_plot$frame$var != "<leaf>")
  )
)
readr::write_csv(tree_metrics, "outputs/mining_tree_metrics.csv")

saveRDS(
  list(
    rules_df = rules_df,
    tree_full = tree_full,
    tree_pruned = tree_pruned,
    tree_plotted = tree_to_plot,
    tree_metrics = tree_metrics
  ),
  "outputs/mining_results.rds"
)

cat("\nPhase 5 complete. Rules, decision tree, and plot saved to outputs/.\n")
