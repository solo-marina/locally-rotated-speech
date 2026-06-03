library(tidyverse)

# ── 1. Load data ──────────────────────────────────────────────────────────────

f0 <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/F0.csv')

speech <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/speech_mod_pavlovia/ALL_COMBINED_RESCALE.csv')

# ── 2. Inspect ────────────────────────────────────────────────────────────────

glimpse(f0)
glimpse(speech)

# ── 3. Filter noisy 10-band and 14-band conditions ───────────────────────────

speech_filtered <- speech %>%
  filter(
    bands == "10b",
    cond == "N",
    proc=="LR"
  )

cat("\nRows after filtering:", nrow(speech_filtered), "\n")
cat("Unique band values retained:", unique(speech_filtered$bands), "\n")

# ── 4. Compute mean word_percentage_rescale per talker ────────────────────────

speech_means <- speech_filtered %>%
  group_by(ID) %>%
  summarise(
    mean_word_pct_rescale = mean(word_percentage_rescale, na.rm = TRUE),
    n_trials = n(),
    .groups = "drop"
  )

cat("\nSpeech means per talker:\n")
print(speech_means)

# ── 5. Harmonise talker IDs and merge ─────────────────────────────────────────
# Speech file: ID is numeric (e.g. 7)
# F0 file:     Talker ID is zero-padded string (e.g. "ID07")
# Convert speech ID → "ID07" format to match F0

speech_means <- speech_means %>%
  mutate(talker_id = paste0("ID", str_pad(ID, width = 2, pad = "0")))

f0_clean <- f0 %>%
  rename(talker_id = `Talker ID`)

merged <- inner_join(f0_clean, speech_means, by = "talker_id")

cat("\nMerged dataset (n =", nrow(merged), "):\n")
print(merged)

# ── 6. Run linear regression: mean intelligibility ~ Mean F0 ──────────────────

model <- lm(mean_word_pct_rescale ~ `Mean F0 (Hz)`, data = merged)

cat("\n──────────────────────────────────────────\n")
cat("Regression: mean_word_pct_rescale ~ Mean F0 (Hz)\n")
cat("──────────────────────────────────────────\n")
print(summary(model))

# ── 7. Correlation ────────────────────────────────────────────────────────────

cat("\nPearson correlation:\n")
print(cor.test(merged$`Mean F0 (Hz)`, merged$mean_word_pct_rescale))

# ── 8. Plot ───────────────────────────────────────────────────────────────────

ggplot(merged, aes(x = `Mean F0 (Hz)`, y = mean_word_pct_rescale)) +
  geom_point(size = 3, colour = "#1D9E75") +
  geom_smooth(method = "lm", se = TRUE, colour = "#0F6E56", fill = "#9FE1CB") +
  geom_text(aes(label = talker_id), vjust = -0.8, size = 3, colour = "grey40") +
  labs(
    title = "Mean F0 vs Intelligibility (noisy 10- & 14-band conditions)",
    x = "Mean F0 (Hz)",
    y = "Mean word % rescaled"
  ) +
  theme_minimal(base_size = 13)

ggsave("f0_intelligibility_regression.png", width = 7, height = 5, dpi = 150)
cat("\nPlot saved to: f0_intelligibility_regression.png\n")
