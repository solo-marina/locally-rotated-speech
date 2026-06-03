library(tidyverse)
library(stringr)
library(stringdist)
library(SnowballC)

# SETTINGS

input_folders <- c(
  '/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/data'
)

ieee_path <- '/Users/marina-solo/Downloads/STAGE 2026 Solo/IEEE.csv'
output_file <- '/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/ALL_COMBINED_STEM_NA_FUZZY.csv'

# FUNCTION 0 - One merged file
csv_files <- map(input_folders, ~ list.files(.x, pattern = "\\.csv$", full.names = TRUE)) %>%
  unlist() %>%
  .[!str_detect(., "ALL_COMBINED")]

message("Found ", length(csv_files), " CSV files across all folders.")

# FUNCTION 1 - IEEE reference
ieee_raw <- read_csv(ieee_path, col_names = FALSE)
ieee_lines <- unlist(ieee_raw) %>% na.omit() %>% str_trim() %>% .[. != ""]
ieee_lookup <- tibble(list_num = integer(), sent_num = integer(), sentence = character())
current_list <- NA_integer_

for (line in ieee_lines) {
  if (str_detect(line, "^H\\d+\\s+Harvard Sentences")) {
    current_list <- as.integer(str_extract(line, "(?<=H)\\d+"))
  } else if (str_detect(line, "^\\d+\\.\\s+")) {
    sent_num <- as.integer(str_extract(line, "^\\d+"))
    sentence <- str_remove(line, "^\\d+\\.\\s+") %>% str_trim()
    ieee_lookup <- ieee_lookup %>% add_row(list_num = current_list, sent_num = sent_num, sentence = sentence)
  }
}

# FUNCTION 2 - NUMBERS TO TEXT
number_to_words <- function(text) {
  if (is.na(text)) return(NA_character_)
  ones <- c("zero","one","two","three","four","five","six","seven","eight","nine",
            "ten","eleven","twelve","thirteen","fourteen","fifteen","sixteen",
            "seventeen","eighteen","nineteen")
  tens <- c("","","twenty","thirty","forty","fifty","sixty","seventy","eighty","ninety")
  n2w <- function(n) {
    n <- as.integer(n)
    if (n < 20) return(ones[n + 1])
    if (n < 100) {
      t <- tens[n %/% 10 + 1]
      o <- if (n %% 10 > 0) paste0("-", ones[n %% 10 + 1]) else ""
      return(paste0(t, o))
    }
    if (n < 1000) {
      h <- paste(ones[n %/% 100 + 1], "hundred")
      rest <- n %% 100
      if (rest > 0) return(paste(h, "and", n2w(rest))) else return(h)
    }
    return(as.character(n))
  }
  step1 <- str_replace_all(text, fixed("+"), " plus ")
  step2 <- str_replace_all(step1, "\\b\\d+\\b", function(ns) map_chr(ns, n2w))
  str_squish(step2)
}

# FUNCTION 2b - CLEAN TEXT
clean_text <- function(text) {
  text %>% str_to_lower() %>% str_remove_all("[[:punct:]]") %>% str_squish()
}

# FUNCTION 3 - PROPORTION AND PERCENTAGE
compare_sentences <- function(ieee, response, threshold) {
  if (is.na(ieee)) return(list(proportion = NA_character_, percentage = NA_real_))
  
  if (is.na(response) | str_squish(response) == "") {
    n_ieee <- length(wordStem(str_split(clean_text(ieee), " ")[[1]], language = "english"))
    return(list(proportion = paste0("0 of ", n_ieee), percentage = 0))
  }
  
  ieee_clean <- str_split(clean_text(ieee), " ")[[1]]
  response_clean <- str_split(clean_text(response), " ")[[1]]
  ieee_lengths <- nchar(ieee_clean)
  ieee_words <- wordStem(ieee_clean, language = "english")
  response_words <- wordStem(response_clean, language = "english")
  n_ieee <- length(ieee_words)
  available <- response_words
  
  correct <- sum(map_lgl(seq_along(ieee_words), function(i) {
    w <- ieee_words[i]
    allowed <- ifelse(ieee_lengths[i] <= 3, 0, threshold)
    distances <- stringdist(w, available, method = "lv")
    match_idx <- which(distances <= allowed)
    if (length(match_idx) > 0) {
      available[match_idx[1]] <<- NA_character_
      TRUE
    } else {
      FALSE
    }
  }))
  
  list(proportion = paste0(correct, " of ", n_ieee), percentage = round((correct / n_ieee) * 100, 1))
}

# FUNCTION 4 - FUZZY MATCHES
get_fuzzy_matches <- function(ieee, response, threshold) {
  if (is.na(ieee)) return(NA_character_)
  if (is.na(response) | str_squish(response) == "") return(NA_character_)
  
  ieee_clean <- str_split(clean_text(ieee), " ")[[1]]
  response_clean <- str_split(clean_text(response), " ")[[1]]
  ieee_lengths <- nchar(ieee_clean)
  ieee_words <- wordStem(ieee_clean, language = "english")
  response_words <- wordStem(response_clean, language = "english")
  available <- response_words
  available_orig <- response_clean
  fuzzy_pairs <- c()
  
  for (i in seq_along(ieee_words)) {
    w <- ieee_words[i]
    allowed <- ifelse(ieee_lengths[i] <= 3, 0, threshold)
    distances <- stringdist(w, available, method = "lv")
    match_idx <- which(distances <= allowed)
    
    if (length(match_idx) > 0) {
      best_idx <- match_idx[which.min(distances[match_idx])]
      best_dist <- distances[best_idx]
      if (best_dist > 0) {
        fuzzy_pairs <- c(fuzzy_pairs, paste0(ieee_clean[i], "→", available_orig[best_idx]))
      }
      available[best_idx] <- NA_character_
      available_orig[best_idx] <- NA_character_
    }
  }
  
  if (length(fuzzy_pairs) == 0) return("")
  paste(fuzzy_pairs, collapse = ", ")
}

# PROCESS ALL CSV FILES
all_data <- map_dfr(csv_files, function(file) {
  message("Processing: ", basename(file))
  
  exp_data <- read_csv(file, col_types = cols(.default = col_character()))
  
  # Add a column to track which file each row came from
  exp_data <- exp_data %>% mutate(
    source_file = basename(file),
    experiment = str_extract(file, "data_exp\\d+")
  )
  
  # PART 1 - IEEE sentence lookup (adds list_num, sent_num, original_ieee; no columns overwritten)
  exp_data <- exp_data %>%
    mutate(
      list_num = as.integer(str_extract(stimulus_path, "(?<=L)\\d+")),
      sent_num = as.integer(str_extract(stimulus_path, "(?<=S)\\d+"))
    ) %>%
    left_join(ieee_lookup, by = c("list_num", "sent_num")) %>%
    rename(original_ieee = sentence)
  
  # PART 2 - Numbers to words in textbox_1.text (added as new column, original preserved)
  exp_data <- exp_data %>%
    mutate(textbox_1_converted = map_chr(`textbox_1.text`, number_to_words))
  
  # PART 3 - Compare words and fuzzy matches (threshold = 1)
  results_1 <- map2(exp_data$original_ieee, exp_data$textbox_1_converted, compare_sentences, threshold = 1)
  exp_data <- exp_data %>%
    mutate(
      word_proportion = map_chr(results_1, ~ as.character(.x[["proportion"]])),
      word_percentage = map_dbl(results_1, ~ as.numeric(.x[["percentage"]])),
      fuzzy_matches = map2_chr(original_ieee, textbox_1_converted, ~ get_fuzzy_matches(.x, .y, threshold = 1))
    )
  
  exp_data
})

# SAVE COMBINED OUTPUT
write_csv(all_data, output_file)
message("Done! Combined file saved to: ", output_file)
