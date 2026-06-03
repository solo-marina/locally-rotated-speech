library(tidyverse)

input_file <- '/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/ALL_RESULTS.csv'
output_file <- '/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/ALL_RESULTS_M.csv'

data <- read_csv(input_file, col_types = cols(.default = col_character()))

data <- data %>%
  mutate(
    # Helper columns (kept in output)
    n_words   = as.integer(str_extract(word_proportion, "\\d+$")),
    n_correct = as.integer(str_extract(word_proportion, "^\\d+")),
    
    word_proportion_M = case_when(
      flag_attitude == "1"                        ~ paste0("0 of ", n_words),
      !is.na(flag_spelling) & flag_spelling != "" ~ paste0(pmax(0, n_correct - as.integer(flag_spelling)), " of ", n_words),
      TRUE                                        ~ word_proportion
    ),
    
    word_percentage_M = case_when(
      flag_attitude == "1"                        ~ 0,
      !is.na(flag_spelling) & flag_spelling != "" ~ round(pmax(0, n_correct - as.integer(flag_spelling)) / n_words * 100, 1),
      TRUE                                        ~ as.numeric(word_percentage)
    )
  )
# no select() — all columns including n_words and n_correct are kept

write_csv(data, output_file)
message("Done! Saved to: ", output_file)
