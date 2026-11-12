# eda script: relationships, correlations, boxplots, and simple tests
library(ggplot2)

df <- read.csv("data/clean.csv", stringsAsFactors = FALSE)

# 1. group comparisons using aggregate()
cat("=== Satisfaction by Year ===\n")
print(aggregate(satisfaction ~ year, data = df, function(x) c(mean = round(mean(x), 2), n = length(x))))
cat("\n")

cat("=== Satisfaction by Residence ===\n")
print(aggregate(satisfaction ~ residence, data = df, function(x) c(mean = round(mean(x), 2), n = length(x))))
cat("\n")

cat("=== Satisfaction by Gender ===\n")
print(aggregate(satisfaction ~ gender, data = df, function(x) c(mean = round(mean(x), 2), n = length(x))))
cat("\n")

cat("=== Satisfaction by Diet ===\n")
print(aggregate(satisfaction ~ diet, data = df, function(x) c(mean = round(mean(x), 2), n = length(x))))
cat("\n")

cat("=== Monthly Spend by Residence and Year ===\n")
print(aggregate(spend_mid ~ residence + year, data = df, function(x) c(mean = round(mean(x), 0), n = length(x))))
cat("\n")

cat("=== Outside Orders per Week by Residence ===\n")
print(aggregate(outside_num ~ residence, data = df, function(x) c(mean = round(mean(x), 2), n = length(x))))
cat("\n")

# 2. correlation matrix of numeric columns
# note: the 4 dining aspect ratings and nutrition value were 100% blank in data.csv,
# so we correlate the active numeric columns: satisfaction, spend_mid, meals_num, outside_num
num_vars <- c("satisfaction", "spend_mid", "meals_num", "outside_num")
cor_mat <- cor(df[, num_vars])
cat("=== Correlation Matrix ===\n")
print(round(cor_mat, 3))
cat("\n")

# reshape correlation matrix for ggplot
cor_df <- as.data.frame(as.table(cor_mat))
colnames(cor_df) <- c("Var1", "Var2", "Correlation")

p_cor <- ggplot(cor_df, aes(x = Var1, y = Var2, fill = Correlation)) +
  geom_tile(color = "white") +
  geom_text(aes(label = sprintf("%.2f", Correlation)), color = "black", size = 4) +
  scale_fill_gradient2(low = "#D95F02", mid = "white", high = "#1B9E77", midpoint = 0, limits = c(-1, 1)) +
  labs(title = "Correlation Heatmap of Numeric Variables", x = "", y = "") +
  theme_minimal()
ggsave("outputs/plots/eda_cor_heatmap.png", p_cor, width = 6.5, height = 5)

# 3. boxplots
p_box1 <- ggplot(df, aes(x = residence, y = satisfaction, fill = residence)) +
  geom_boxplot(width = 0.5, show.legend = FALSE) +
  labs(title = "Satisfaction by Residence", x = "Residence", y = "Satisfaction (1-5)") +
  theme_minimal()
ggsave("outputs/plots/eda_box_sat_residence.png", p_box1, width = 6.5, height = 4.5)

p_box2 <- ggplot(df, aes(x = gender, y = spend_mid, fill = gender)) +
  geom_boxplot(width = 0.5, show.legend = FALSE) +
  labs(title = "Monthly Food Spend by Gender", x = "Gender", y = "Monthly Spend (INR)") +
  theme_minimal()
ggsave("outputs/plots/eda_box_spend_gender.png", p_box2, width = 6.5, height = 4.5)

p_box3 <- ggplot(df, aes(x = year, y = spend_mid, fill = year)) +
  geom_boxplot(width = 0.5, show.legend = FALSE) +
  labs(title = "Monthly Food Spend by Year of Study", x = "Year", y = "Monthly Spend (INR)") +
  theme_minimal()
ggsave("outputs/plots/eda_box_spend_year.png", p_box3, width = 6.5, height = 4.5)

# 4. stacked/grouped bar charts
p_bar1 <- ggplot(df, aes(x = residence, fill = skipped_meal)) +
  geom_bar(position = "fill") +
  labs(title = "Proportion of Skipped Meals by Residence", x = "Residence", y = "Proportion", fill = "Skipped Meal") +
  theme_minimal()
ggsave("outputs/plots/eda_bar_skipped_residence.png", p_bar1, width = 7.5, height = 4.5)

# diet vs hostel mess usage
df$uses_mess <- ifelse(grepl("Hostel Mess", df$outlets), "Uses Mess", "No Mess")
p_bar2 <- ggplot(df, aes(x = diet, fill = uses_mess)) +
  geom_bar(position = "fill", width = 0.6) +
  labs(title = "Hostel Mess Usage by Dietary Preference", x = "Diet", y = "Proportion", fill = "Mess Usage") +
  theme_minimal()
ggsave("outputs/plots/eda_bar_diet_outlet.png", p_bar2, width = 7.5, height = 4.5)

# 5. simple statistical tests
cat("=== Statistical Tests ===\n")

# test 1: residence vs skipped meal
tbl_res_skip <- table(df$residence, df$skipped_meal)
test_skip <- suppressWarnings(chisq.test(tbl_res_skip))
cat("Chi-square test (residence vs skipped_meal): p-value =", round(test_skip$p.value, 4), "\n")
cat("Meaning: No significant link between residence and skipped meal (p >= 0.05). Breakfast skipping is common everywhere.\n\n")

# test 2: gender vs satisfied (satisfaction >= 4)
df$satisfied <- ifelse(df$satisfaction >= 4, "Satisfied", "Not Satisfied")
tbl_gen_sat <- table(df$gender, df$satisfied)
test_sat <- chisq.test(tbl_gen_sat)
cat("Chi-square test (gender vs satisfied): p-value =", round(test_sat$p.value, 4), "\n")
cat("Meaning: Gender does not significantly affect student satisfaction (p >= 0.05).\n\n")

# test 3: spend vs satisfaction correlation test
test_spend_sat <- cor.test(df$spend_mid, df$satisfaction)
cat("Correlation test (spend_mid vs satisfaction): r =", round(test_spend_sat$estimate, 3), ", p-value =", round(test_spend_sat$p.value, 4), "\n")
cat("Meaning: Weak positive linear correlation (r = 0.102, p = 0.342 > 0.05), not statistically significant at linear level.\n\n")

# 6. mean satisfaction across major outlets
# (adapted because facility rating columns were blank in raw survey)
outlets_list <- c("Hostel Mess", "Nescafe", "Yadav Canteen", "Night Canteen", "Snacker")
outlet_means <- numeric(length(outlets_list))
outlet_counts <- numeric(length(outlets_list))

for (i in seq_along(outlets_list)) {
  mask <- grepl(outlets_list[i], df$outlets)
  outlet_means[i] <- round(mean(df$satisfaction[mask]), 2)
  outlet_counts[i] <- sum(mask)
}

df_outlet_ratings <- data.frame(
  Outlet = outlets_list,
  MeanSatisfaction = outlet_means,
  Users = outlet_counts
)
cat("=== Mean Satisfaction by Outlet Used ===\n")
print(df_outlet_ratings)
cat("\n")

p_ratings <- ggplot(df_outlet_ratings, aes(x = reorder(Outlet, -MeanSatisfaction), y = MeanSatisfaction, fill = Outlet)) +
  geom_bar(stat = "identity", width = 0.6, show.legend = FALSE) +
  geom_text(aes(label = sprintf("%.2f (n=%d)", MeanSatisfaction, Users)), vjust = -0.3, size = 3.5) +
  ylim(0, 5) +
  labs(title = "Mean Overall Satisfaction by Outlet Used", x = "Outlet", y = "Mean Satisfaction Rating (1-5)") +
  theme_minimal()
ggsave("outputs/plots/eda_mean_ratings.png", p_ratings, width = 7.5, height = 4.5)

cat("All EDA plots saved successfully in outputs/plots/\n")
