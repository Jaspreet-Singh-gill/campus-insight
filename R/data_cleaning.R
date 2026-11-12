# read the raw survey data
df <- read.csv("data/data.csv", check.names = FALSE, stringsAsFactors = FALSE)

cat("--- Raw Data Info ---\n")
cat("Rows:", nrow(df), "Columns:", ncol(df), "\n\n")

# count missing values in each column
cat("--- Missing values per column ---\n")
missing_counts <- colSums(is.na(df) | df == "")
print(missing_counts)
cat("\n")

# check for duplicate rows
cat("Exact duplicates:", sum(duplicated(df)), "\n")
cat("Duplicates without timestamp:", sum(duplicated(df[, -1])), "\n\n")

# identify completely empty columns (all 88 rows are NA)
# columns 16-20 (dining aspect ratings & nutrition) and Untitled Question have no responses
empty_cols <- names(df)[colSums(!is.na(df) & df != "") == 0]
cat("Empty columns dropped (100% missing):\n")
print(empty_cols)
cat("\n")

# drop timestamp and empty columns
df <- df[, !(names(df) %in% c("Timestamp", empty_cols))]

# rename to short column names
colnames(df) <- c(
  "year", "residence", "gender", "diet", "outlets",
  "meals_per_day", "skipped_meal", "monthly_spend",
  "outside_orders", "factors", "satisfaction",
  "improvements", "payment"
)

# trim whitespace from text columns
for (col in names(df)) {
  if (is.character(df[[col]])) {
    df[[col]] <- trimws(df[[col]])
  }
}

# clean up accent marks in outlet names to prevent encoding bugs
df$outlets <- gsub("Nescaf[^\", ]*", "Nescafe", df$outlets)

# fill any missing values (unknown for text, median for numeric)
for (col in names(df)) {
  if (is.character(df[[col]])) {
    df[[col]][is.na(df[[col]]) | df[[col]] == ""] <- "Unknown"
  } else if (is.numeric(df[[col]])) {
    med_val <- median(df[[col]], na.rm = TRUE)
    df[[col]][is.na(df[[col]])] <- med_val
  }
}

# convert monthly_spend into numeric spend_mid
# strips 'Rs.', commas, '/-' and 'around' to get pure numbers
clean_spend <- gsub("[^0-9]", "", df$monthly_spend)
df$spend_mid <- as.numeric(clean_spend)

# convert meals_per_day into numeric meals_num
df$meals_num <- suppressWarnings(as.numeric(df$meals_per_day))
df$meals_num[df$meals_per_day == "1-2 meals"] <- 1.5
df$meals_num[df$meals_per_day == "1 times"] <- 1.0

# convert outside_orders into numeric outside_num
df$outside_num <- suppressWarnings(as.numeric(df$outside_orders))
df$outside_num[df$outside_orders == "twice a week"] <- 2.0
df$outside_num[df$outside_orders == "1 times"] <- 1.0

# check satisfaction ratings are valid (1 to 5)
cat("--- Satisfaction Range Check ---\n")
cat("Min satisfaction:", min(df$satisfaction), "Max satisfaction:", max(df$satisfaction), "\n\n")

# remove duplicate rows if any
df <- unique(df)

# before and after summary
cat("--- Data Cleaning Summary ---\n")
cat("Initial: 88 rows, 20 columns, 528 missing values (6 completely empty columns)\n")
cat("Cleaned: ", nrow(df), "rows,", ncol(df), "columns,", sum(is.na(df)), "missing values\n\n")

# save to clean.csv
write.csv(df, "data/clean.csv", row.names = FALSE)
cat("Cleaned dataset saved to data/clean.csv\n")

