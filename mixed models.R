install.packages("lme4")
install.packages("lmerTest")
library(lme4)
library(lmerTest)
library(tidyverse)

input_file <- '/Users/marina-solo/Downloads/STAGE 2026 Solo/speech_mod_pavlovia/ALL_COMBINED_RESCALE.csv'
f0_file    <- '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/F0.csv'

# --- Load data ---
data <- read_csv(input_file, col_types = cols(.default = col_character()))
f0   <- read_csv(f0_file)

# --- Prepare F0 table ---
f0 <- f0 %>%
  rename(talker_id = `Talker ID`,
         mean_f0   = `Mean F0 (Hz)`) %>%
  select(talker_id, mean_f0)

# --- Define talker sex ---
male_ids   <- c("ID01", "ID06", "ID10", "ID12")

# --- Join F0 and talker_sex into main data ---
model_data_mixed <- data %>%
  mutate(
    talker_id  = paste0("ID", str_sub(stimulus_path, 9, 10)),  # extract from stimulus_path
    talker_sex = ifelse(talker_id %in% male_ids, "Male", "Female")
  ) %>%
  left_join(f0, by = "talker_id") %>%
  mutate(
    n_bands      = as.numeric(str_extract(bands, "\\d+")),
    log_bands    = log(n_bands),
    is_noisy     = as.integer(cond == "N"),
    is_LR        = as.integer(proc == "LR"),
    is_male      = as.integer(talker_sex == "Male"),
    n_correct    = as.numeric(str_extract(word_proportion_M, "^\\d+")),
    n_total      = as.numeric(str_extract(word_proportion_M, "\\d+$")),
    prop_rescale = as.numeric(word_percentage_rescale) / 100,
    f0_centered  = scale(mean_f0, center = TRUE, scale = FALSE)[,1],  # center F0
    participant  = as.factor(participant),
    cond         = as.factor(cond),
    proc         = as.factor(proc)
  ) %>%
  filter(!is.na(prop_rescale), !is.na(f0_centered))

# --- Check join worked ---
cat("Talker IDs in data:\n")
print(sort(unique(model_data_mixed$talker_id)))
cat("\nMissing F0 rows:", sum(is.na(model_data_mixed$mean_f0)), "\n")
cat("Talker sex distribution:\n")
print(table(model_data_mixed$talker_sex))

m_mixed <- glmer(
  prop_rescale ~ log_bands * is_LR * is_noisy + is_male*log_bands + f0_centered +
    (1 | participant),
  data    = model_data_mixed,
  family  = binomial(link = "probit"),
  weights = n_total
)

print(summary(m_mixed))

