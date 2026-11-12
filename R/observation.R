# observation script: inspect dataset and plot basic distributions
library(ggplot2)

# read cleaned data
df <- read.csv("data/clean.csv", stringsAsFactors = FALSE)

# basic dimensions and structure
cat("=== Dataset Dimensions ===\n")
print(dim(df))
cat("\n")

cat("=== Structure ===\n")
str(df)
cat("\n")

cat("=== Summary Statistics ===\n")
print(summary(df))
cat("\n")

cat("=== First 5 Rows ===\n")
print(head(df, 5))
cat("\n")

cat("=== Unique Values Per Column ===\n")
print(sapply(df, function(x) length(unique(x))))
cat("\n")

# frequency tables for key categorical columns
cat_cols <- c("year", "residence", "gender", "diet", "meals_per_day", "skipped_meal", "payment")

for (v in cat_cols) {
  cat("--- Frequency:", v, "---\n")
  counts <- table(df[[v]])
  pcts <- round(prop.table(counts) * 100, 1)
  tbl <- cbind(Count = counts, "Percent(%)" = pcts)
  print(tbl)
  cat("\n")
}

# make sure plots folder exists
if (!dir.exists("outputs/plots")) {
  dir.create("outputs/plots", recursive = TRUE)
}

# 1. bar chart for year of study
p1 <- ggplot(df, aes(x = year)) +
  geom_bar(fill = "#4C72B0", width = 0.6) +
  labs(title = "Respondents by Year of Study", x = "Year", y = "Count") +
  theme_minimal()
ggsave("outputs/plots/obs_year.png", p1, width = 7, height = 4.5)

# 2. bar chart for residence
p2 <- ggplot(df, aes(x = residence)) +
  geom_bar(fill = "#DD8452", width = 0.5) +
  labs(title = "Residence Distribution", x = "Residence", y = "Count") +
  theme_minimal()
ggsave("outputs/plots/obs_residence.png", p2, width = 7, height = 4.5)

# 3. bar chart for gender
p3 <- ggplot(df, aes(x = gender)) +
  geom_bar(fill = "#55A868", width = 0.5) +
  labs(title = "Gender Distribution", x = "Gender", y = "Count") +
  theme_minimal()
ggsave("outputs/plots/obs_gender.png", p3, width = 7, height = 4.5)

# 4. bar chart for dietary preference
p4 <- ggplot(df, aes(x = diet)) +
  geom_bar(fill = "#C44E52", width = 0.6) +
  labs(title = "Dietary Preferences", x = "Diet", y = "Count") +
  theme_minimal()
ggsave("outputs/plots/obs_diet.png", p4, width = 7, height = 4.5)

# 5. bar chart for skipped meals
p5 <- ggplot(df, aes(x = skipped_meal)) +
  geom_bar(fill = "#8172B3", width = 0.6) +
  labs(title = "Most Frequently Skipped Meal", x = "Meal", y = "Count") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 20, hjust = 1))
ggsave("outputs/plots/obs_skipped_meal.png", p5, width = 7, height = 4.5)

# 6. bar chart for payment methods
p6 <- ggplot(df, aes(x = payment)) +
  geom_bar(fill = "#937860", width = 0.5) +
  labs(title = "Primary Payment Method", x = "Payment Method", y = "Count") +
  theme_minimal()
ggsave("outputs/plots/obs_payment.png", p6, width = 7, height = 4.5)

# 7. histogram/bar chart for satisfaction
p7 <- ggplot(df, aes(x = satisfaction)) +
  geom_bar(fill = "#4C72B0", width = 0.6) +
  scale_x_continuous(breaks = 1:5) +
  labs(title = "Overall Satisfaction Rating (1 to 5)", x = "Satisfaction", y = "Count") +
  theme_minimal()
ggsave("outputs/plots/obs_satisfaction_hist.png", p7, width = 7, height = 4.5)

# 8. histogram for monthly food spend
p8 <- ggplot(df, aes(x = spend_mid)) +
  geom_histogram(binwidth = 500, fill = "#CCB974", color = "white") +
  labs(title = "Monthly Food Spend Distribution", x = "Monthly Spend (INR)", y = "Count") +
  theme_minimal()
ggsave("outputs/plots/obs_spend_hist.png", p8, width = 7, height = 4.5)

cat("All observation plots saved successfully in outputs/plots/\n")

