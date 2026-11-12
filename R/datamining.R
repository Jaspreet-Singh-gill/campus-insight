# datamining script: association rules (apriori), k-means clustering, and logistic regression
library(ggplot2)
library(arules)

set.seed(42)

df <- read.csv("data/clean.csv", stringsAsFactors = FALSE)

# a) association rules (apriori)
cat("=== Association Rules Mining ===\n")

# prepare transaction items for each student
item_list <- list()

for (i in 1:nrow(df)) {
  # split comma separated values
  outs <- paste0("outlet=", trimws(unlist(strsplit(df$outlets[i], ","))))
  facts <- paste0("factor=", trimws(unlist(strsplit(df$factors[i], ","))))
  imprs <- paste0("improve=", trimws(unlist(strsplit(df$improvements[i], ","))))
  
  # add binned categorical features
  sp <- ifelse(df$spend_mid[i] <= 1000, "spend=Low",
        ifelse(df$spend_mid[i] <= 2000, "spend=Medium", "spend=High"))
  sat <- ifelse(df$satisfaction[i] >= 4, "sat=Satisfied",
         ifelse(df$satisfaction[i] == 3, "sat=Neutral", "sat=Dissatisfied"))
  skip <- paste0("skip=", df$skipped_meal[i])
  diet <- paste0("diet=", df$diet[i])
  
  # combine all items for this student
  items <- c(outs, facts, imprs, sp, sat, skip, diet)
  item_list[[i]] <- unique(items)
}

# convert to arules transactions object
trans <- as(item_list, "transactions")

# plot and save top 15 most frequent items
png("outputs/plots/dm_item_frequency.png", width = 800, height = 550, res = 100)
itemFrequencyPlot(trans, topN = 15, col = "#4C72B0", main = "Top 15 Most Frequent Items", ylab = "Item Frequency (Support)")
dev.off()

# run apriori algorithm
rules <- apriori(trans, parameter = list(supp = 0.12, conf = 0.6, minlen = 2, target = "rules"),
                 control = list(verbose = FALSE))

# sort by lift
rules_sorted <- sort(rules, by = "lift")

cat("Total rules found:", length(rules_sorted), "\n\n")
cat("--- Top 15 Rules by Lift ---\n")
inspect(head(rules_sorted, 15))
cat("\n")

# save top rules to csv table
rules_df <- as(rules_sorted, "data.frame")
write.csv(rules_df, "outputs/tables/rules.csv", row.names = FALSE)
cat("Rules saved to outputs/tables/rules.csv\n\n")

# b) k-means clustering
cat("=== K-Means Clustering ===\n")

# scale numeric features
clust_vars <- c("spend_mid", "satisfaction", "outside_num", "meals_num")
scaled_data <- scale(df[, clust_vars])

# elbow method: calculate within-cluster sum of squares for k = 1 to 8
wss <- numeric(8)
for (k in 1:8) {
  km_fit <- kmeans(scaled_data, centers = k, nstart = 20)
  wss[k] <- km_fit$tot.withinss
}

elbow_df <- data.frame(k = 1:8, wss = wss)

p_elbow <- ggplot(elbow_df, aes(x = k, y = wss)) +
  geom_line(color = "#4C72B0", linewidth = 1) +
  geom_point(color = "#C44E52", size = 3) +
  scale_x_continuous(breaks = 1:8) +
  labs(title = "Elbow Method for Optimal k", x = "Number of Clusters (k)", y = "Total Within-Cluster SS") +
  theme_minimal()
ggsave("outputs/plots/dm_elbow.png", p_elbow, width = 7, height = 4.5)

# fit k-means with k = 3
km3 <- kmeans(scaled_data, centers = 3, nstart = 25)
df$cluster <- factor(km3$cluster)

cat("--- Cluster Sizes (k=3) ---\n")
print(table(df$cluster))
cat("\n")

cat("--- Cluster Averages (Original Scale) ---\n")
cluster_summary <- aggregate(cbind(spend_mid, satisfaction, outside_num, meals_num) ~ cluster, data = df, mean)
cluster_summary[, -1] <- round(cluster_summary[, -1], 2)
print(cluster_summary)
cat("\n")

# cluster descriptions:
# Cluster 1: Budget diners - moderate spend (~1400), avg satisfaction (~3.0), low outside orders (~0.2), ~1 campus meal
# Cluster 2: Frequent outside orderers - higher spend (~2000), regular outside delivery (~2.2/wk), ~1 campus meal
# Cluster 3: High campus meal users - active campus diners (~1.6 meals/day), spend (~1800), avg satisfaction (~2.9)

# scatter plot of clusters
p_clust <- ggplot(df, aes(x = spend_mid, y = satisfaction, color = cluster)) +
  geom_jitter(width = 80, height = 0.15, size = 3, alpha = 0.8) +
  scale_color_manual(values = c("#4C72B0", "#DD8452", "#55A868"),
                     labels = c("Budget Diners", "Frequent Outside Orderers", "Heavy Campus Diners")) +
  labs(title = "K-Means Student Clusters (k = 3)", x = "Monthly Spend (INR)", y = "Satisfaction Rating (1-5)", color = "Student Segment") +
  theme_minimal()
ggsave("outputs/plots/dm_clusters.png", p_clust, width = 7.5, height = 4.5)

# c) simple logistic regression predicting satisfied (satisfaction >= 4)
cat("=== Logistic Regression: Predicting Satisfaction ===\n")
df$satisfied <- as.integer(df$satisfaction >= 4)
logit_model <- glm(satisfied ~ spend_mid + outside_num + meals_num, data = df, family = binomial)
print(summary(logit_model))

# accuracy check
prob_pred <- predict(logit_model, type = "response")
class_pred <- ifelse(prob_pred >= 0.5, 1, 0)
acc <- mean(class_pred == df$satisfied) * 100
cat(sprintf("Model Classification Accuracy: %.1f%%\n", acc))

cat("\nAll data mining plots and tables saved successfully.\n")

