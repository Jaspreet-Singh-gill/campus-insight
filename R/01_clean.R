# Phase 1: Data Cleaning and Quality Check
# Purpose: Read the raw survey CSV, check and drop empty columns, clean messy
#          text-to-number answers, split multi-select columns into 0/1 flags,
#          create helper columns and ordered factors, print a data-quality
#          report, and save the cleaned dataset.

library(tidyverse)
library(janitor)

# Create output folders if they do not exist yet
dir.create("outputs", showWarnings = FALSE, recursive = TRUE)
dir.create("outputs/plots", showWarnings = FALSE, recursive = TRUE)

# 1. Read the raw CSV without changing it --------------------------------------
raw_path <- "data/dmaProjectdata.csv"
raw <- readr::read_csv(raw_path, na = c("", "NA"), show_col_types = FALSE)

cat("=== RAW DATA OVERVIEW ===\n")
cat("File:", raw_path, "\n")
cat("Rows:", nrow(raw), " | Columns:", ncol(raw), "\n\n")

# 2. Check missing values across all raw columns -------------------------------
missing_report <- tibble::tibble(
  col_index = seq_along(names(raw)),
  raw_name = names(raw),
  non_missing = purrr::map_int(raw, ~ sum(!is.na(.x))),
  missing = purrr::map_int(raw, ~ sum(is.na(.x))),
  missing_pct = round(100 * missing / nrow(raw), 1)
)

cat("=== MISSING VALUES PER RAW COLUMN ===\n")
print(missing_report, n = Inf)

# Check if Timestamp is valid and print survey window
cat("\n=== SURVEY COLLECTION TIMESTAMPS ===\n")
cat("First timestamp:", as.character(raw$Timestamp[1]), "\n")
cat("Last timestamp :", as.character(raw$Timestamp[nrow(raw)]), "\n")

# 3. Check duplicates before dropping Timestamp --------------------------------
dup_all <- sum(duplicated(raw))
dup_answers <- sum(duplicated(raw[, -1]))
cat("\n=== DUPLICATE CHECK ===\n")
cat("Exact duplicate rows (all columns)          :", dup_all, "\n")
cat("Duplicate rows (excluding Timestamp column) :", dup_answers, "\n")

# 4. Identify and drop completely empty columns --------------------------------
# Check column 2 ("Untitled Question") and columns 16-20 (ratings & nutrition)
all_empty_cols <- names(raw)[purrr::map_lgl(raw, ~ all(is.na(.x)))]
cat("\n=== COMPLETELY EMPTY COLUMNS (100% NA) ===\n")
if (length(all_empty_cols) > 0) {
  print(all_empty_cols)
} else {
  cat("None.\n")
}

# Record dropped empty columns for reporting and limitations
dropped_cols_tbl <- tibble::tibble(
  raw_column = all_empty_cols,
  reason = "100% missing (all 88 values are NA)"
)
readr::write_csv(dropped_cols_tbl, "outputs/dropped_columns.csv")
readr::write_csv(missing_report, "outputs/raw_missing_report.csv")

# Keep only non-empty columns, and drop Timestamp (not needed for analysis)
df <- raw |>
  dplyr::select(-dplyr::all_of(all_empty_cols)) |>
  dplyr::select(-Timestamp)

# Verify expected 13 core survey columns remain (unless ratings had data)
expected_core_names <- c(
  "year", "residence", "gender", "diet", "outlets",
  "meals_per_day", "skipped_meal", "spend", "outside_orders",
  "factors", "satisfaction", "improvements", "payment"
)

if (ncol(df) == 13) {
  names(df) <- expected_core_names
} else {
  # If extra rating columns were non-empty, name the first 13 and clean the rest
  names(df)[1:13] <- expected_core_names
  names(df)[14:ncol(df)] <- janitor::make_clean_names(names(df)[14:ncol(df)])
}

cat("\nRenamed core columns:\n")
print(names(df))

# 5. Clean messy typed numeric columns -----------------------------------------
# Helper: check which values are not clean digits before parsing
is_plain_number <- function(x) {
  stringr::str_detect(stringr::str_trim(as.character(x)), "^[0-9]+(\\.[0-9]+)?$")
}

odd_meals <- df$meals_per_day[!is_plain_number(df$meals_per_day)]
odd_spend <- df$spend[!is_plain_number(df$spend)]
odd_outside <- df$outside_orders[!is_plain_number(df$outside_orders)]

cat("\n=== ODD TEXT VALUES BEFORE CLEANING ===\n")
cat("meals_per_day odd values :", paste(odd_meals, collapse = " | "), "\n")
cat("spend odd values         :", paste(odd_spend, collapse = " | "), "\n")
cat("outside_orders odd values:", paste(odd_outside, collapse = " | "), "\n")

# Clean meals_per_day:
# Note: "1-2 meals" becomes 1 with parse_number(), treating a range conservatively
# as its lower bound; "1 times" also becomes 1.
meals_raw_chr <- stringr::str_trim(as.character(df$meals_per_day))
df$meals_per_day <- readr::parse_number(meals_raw_chr)

# Clean spend: remove "Rs." prefix first so readr::parse_number() does not get
# confused by the dot in "Rs.", then parse "2,000/-" -> 2000 and "around 1000" -> 1000
spend_raw_chr <- stringr::str_trim(as.character(df$spend))
spend_prepped <- stringr::str_remove(
  spend_raw_chr,
  stringr::regex("^Rs\\.?\\s*", ignore_case = TRUE)
)
df$spend <- readr::parse_number(spend_prepped)

# Clean outside_orders: handle "twice a week" as 2 before parse_number()
outside_raw_chr <- stringr::str_trim(as.character(df$outside_orders))
outside_prepped <- dplyr::if_else(
  stringr::str_detect(stringr::str_to_lower(outside_raw_chr), "twice"),
  "2",
  outside_raw_chr
)
df$outside_orders <- readr::parse_number(outside_prepped)

# Clean satisfaction (ensure integer 1 to 5)
df$satisfaction <- as.integer(df$satisfaction)

# Count how many rows had non-plain-numeric text that was fixed
fixed_meals_n <- sum(!is_plain_number(meals_raw_chr))
fixed_spend_n <- sum(!is_plain_number(spend_raw_chr))
fixed_outside_n <- sum(!is_plain_number(outside_raw_chr))
rows_with_any_fix <- sum(
  !is_plain_number(meals_raw_chr) |
    !is_plain_number(spend_raw_chr) |
    !is_plain_number(outside_raw_chr)
)

cat("\n=== NUMERIC CLEANING SUMMARY ===\n")
cat("meals_per_day rows fixed :", fixed_meals_n, "\n")
cat("spend rows fixed         :", fixed_spend_n, "\n")
cat("outside_orders rows fixed:", fixed_outside_n, "\n")
cat("Total distinct rows fixed:", rows_with_any_fix, "\n")

# Verify no NAs were introduced by parsing
cat("NAs after parsing -> meals:", sum(is.na(df$meals_per_day)),
    "| spend:", sum(is.na(df$spend)),
    "| outside_orders:", sum(is.na(df$outside_orders)),
    "| satisfaction:", sum(is.na(df$satisfaction)), "\n")

stopifnot(
  sum(is.na(df$meals_per_day)) == 0,
  sum(is.na(df$spend)) == 0,
  sum(is.na(df$outside_orders)) == 0,
  sum(is.na(df$satisfaction)) == 0
)

# 6. Check outside_orders distribution and justify heavy_outside cutoff --------
cat("\n=== OUTSIDE ORDERS DISTRIBUTION (PER WEEK) ===\n")
outside_dist <- table(df$outside_orders)
print(outside_dist)
print(round(100 * prop.table(outside_dist), 1))

# Justification for cutoff:
# Most students order from outside 0 times (28) or 1 time (43) per week,
# which together is 71 out of 88 students (80.7%).
# Only 17 students (19.3%) order 2 or 3 times a week (roughly the top 20%).
# Therefore, outside_orders >= 2 is a clear, practical cutoff for "heavy_outside".

# 7. Create ordered factors and clean categorical columns ----------------------
# Trim whitespace from categorical text columns
df <- df |>
  dplyr::mutate(dplyr::across(c(year, residence, gender, diet, skipped_meal, payment), stringr::str_trim))

# Ordered factor for year of study
year_levels <- c("1st Year", "2nd Year", "3rd Year", "4th Year")
present_years <- year_levels[year_levels %in% unique(df$year)]
df$year <- factor(df$year, levels = present_years, ordered = TRUE)

# Check spend distribution to create balanced, easy-to-explain spend bands
cat("\n=== SPEND DISTRIBUTION (INR PER MONTH) ===\n")
print(table(df$spend))

# Spend bands: <= 1000 (Low), 1001-2000 (Medium), > 2000 (High)
# Gives balanced group sizes: 22, 45, and 21 students.
df$spend_band <- dplyr::case_when(
  df$spend <= 1000 ~ "Low (<= Rs 1,000)",
  df$spend <= 2000 ~ "Medium (Rs 1,001-2,000)",
  TRUE             ~ "High (> Rs 2,000)"
)
df$spend_band <- factor(
  df$spend_band,
  levels = c("Low (<= Rs 1,000)", "Medium (Rs 1,001-2,000)", "High (> Rs 2,000)"),
  ordered = TRUE
)

# Check rare categories
cat("\n=== CHECKING RARE CATEGORIES (< 8 STUDENTS) ===\n")
cat("Day Scholar:", sum(df$residence == "Day Scholar"), "\n")
cat("Vegan      :", sum(df$diet == "Vegan"), "\n")
cat("Cash       :", sum(df$payment == "Cash"), "\n")
cat("Skip Dinner:", sum(df$skipped_meal == "Dinner"), "\n")
cat("Rarely Skip:", sum(df$skipped_meal == "I rarely skip meals"), "\n")

# 8. Create helper columns (0/1 integer flags) ---------------------------------
# satisfied: rating 4 or 5 on the 1-5 scale
# skips_breakfast: most often skipped meal is Breakfast
# heavy_outside: orders outside food 2 or more times per week (top ~19%)
df <- df |>
  dplyr::mutate(
    respondent_id = dplyr::row_number(),
    satisfied = as.integer(satisfaction >= 4),
    skips_breakfast = as.integer(skipped_meal == "Breakfast"),
    heavy_outside = as.integer(outside_orders >= 2)
  ) |>
  dplyr::relocate(respondent_id)

# 9. Split multi-select columns into 0/1 columns -------------------------------
split_multiselect <- function(data, col_name, prefix) {
  raw_vec <- as.character(data[[col_name]])
  # Extract unique comma-separated options and print them so none are missed
  options <- sort(unique(stringr::str_trim(unlist(stringr::str_split(raw_vec, ",")))))
  options <- options[options != "" & !is.na(options)]

  cat(sprintf("\n--- Unique options in '%s' (%d found) ---\n", col_name, length(options)))
  for (i in seq_along(options)) {
    cat(sprintf("  %2d. %s\n", i, options[i]))
  }

  # Create clean ASCII column names (e.g., Nescafé -> nescafe)
  clean_opts <- janitor::make_clean_names(iconv(options, from = "UTF-8", to = "ASCII//TRANSLIT"))
  col_names <- paste0(prefix, "_", clean_opts)

  for (i in seq_along(options)) {
    data[[col_names[i]]] <- as.integer(stringr::str_detect(raw_vec, stringr::fixed(options[i])))
  }

  # Verify that dummy sum matches comma-separated count in every row
  expected_counts <- lengths(stringr::str_split(raw_vec, ","))
  actual_counts <- rowSums(data[, col_names, drop = FALSE])
  mismatch_rows <- sum(expected_counts != actual_counts)
  cat(sprintf("Verification for '%s': rows where dummy sum != selection count = %d\n",
              col_name, mismatch_rows))

  list(
    data = data,
    mapping = tibble::tibble(
      group = col_name,
      option_label = options,
      column_name = col_names,
      count = colSums(data[, col_names, drop = FALSE]),
      pct = round(100 * colSums(data[, col_names, drop = FALSE]) / nrow(data), 1)
    )
  )
}

res_outlets <- split_multiselect(df, "outlets", "outlet")
df <- res_outlets$data

res_factors <- split_multiselect(df, "factors", "factor")
df <- res_factors$data

res_improve <- split_multiselect(df, "improvements", "improve")
df <- res_improve$data

multiselect_map <- dplyr::bind_rows(
  res_outlets$mapping,
  res_factors$mapping,
  res_improve$mapping
)
readr::write_csv(multiselect_map, "outputs/multiselect_options.csv")

# 10. Save quality summary and cleaned data ------------------------------------
quality_summary <- tibble::tibble(
  metric = c(
    "Raw rows",
    "Raw columns",
    "Empty columns dropped",
    "Exact duplicate rows (all cols)",
    "Duplicate rows (excluding Timestamp)",
    "Rows fixed in meals_per_day",
    "Rows fixed in spend",
    "Rows fixed in outside_orders",
    "Distinct rows with text-to-number fixes",
    "Clean rows saved",
    "Clean columns saved"
  ),
  value = c(
    nrow(raw),
    ncol(raw),
    length(all_empty_cols),
    dup_all,
    dup_answers,
    fixed_meals_n,
    fixed_spend_n,
    fixed_outside_n,
    rows_with_any_fix,
    nrow(df),
    ncol(df)
  )
)

cat("\n=== FINAL DATA QUALITY REPORT ===\n")
print(quality_summary, n = Inf)

readr::write_csv(quality_summary, "outputs/data_quality_summary.csv")
saveRDS(df, "outputs/clean.rds")
readr::write_csv(df, "outputs/clean.csv")

cat("\nSaved outputs/clean.rds and outputs/clean.csv successfully.\n")

