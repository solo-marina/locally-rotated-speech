library(tidyverse)
library(patchwork)

data <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/speech_mod_pavlovia/ALL_COMBINED_RESCALE.csv',
                 col_types = cols(.default = col_character()))

# Prepare data
plot_data <- data %>%
  filter(proc %in% c("NV", "LR")) %>%
  mutate(
    word_percentage_rescale = as.numeric(word_percentage_rescale),
    bands_num  = as.integer(str_remove(bands, "b")),
    talker_id  = str_sub(stimulus_path, 9, 10),
    talker_sex = ifelse(talker_id %in% c("01", "06", "10", "12"), "Male", "Female"),
    condition  = case_when(cond == "Q" ~ "Quiet", cond == "N" ~ "Noisy", TRUE ~ cond),
    proc_label = case_when(proc == "NV" ~ "Noise Vocoded", proc == "LR" ~ "Locally Rotated", TRUE ~ proc)
  ) %>%
  filter(!is.na(word_percentage_rescale), !is.na(bands_num), cond %in% c("Q", "N"))

# Average per proc and sex
avg_data <- plot_data %>%
  group_by(bands_num, proc_label, condition, talker_sex) %>%
  summarise(
    mean_correct = mean(word_percentage_rescale, na.rm = TRUE),
    se           = sd(word_percentage_rescale, na.rm = TRUE) / sqrt(n()),
    .groups = "drop"
  ) %>%
  mutate(group_label = paste(proc_label, talker_sex, sep = "."))

# Plot function
make_plot <- function(cond_label) {
  d <- avg_data %>% filter(condition == cond_label)
  
  ggplot(d, aes(x = bands_num, y = mean_correct,
                colour = group_label,
                group  = group_label)) +
    geom_line(linewidth = 0.8) +
    geom_point(size = 2) +
    geom_errorbar(aes(ymin = mean_correct - se, ymax = mean_correct + se),
                  width = 0.3) +
    scale_colour_manual(
      values = c(
        "Noise Vocoded.Male"     = "#E66100",
        "Locally Rotated.Male"   = "#5D3A9B",
        "Noise Vocoded.Female"   = "#06A100",
        "Locally Rotated.Female" = "#1D3ABB"
      ),
      name = "Processing / Sex"
    ) +
    scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
    scale_x_continuous(breaks = sort(unique(d$bands_num))) +
    labs(
      title = cond_label,
      x     = "Number of Bands",
      y     = "Mean % Words Correct (rescaled)"
    ) +
    theme_minimal(base_size = 13) +
    theme(
      legend.position  = "bottom",
      panel.grid.minor = element_blank(),
      plot.title       = element_text(hjust = 0.5, face = "bold")
    )
}

p_quiet <- make_plot("Quiet")
p_noisy <- make_plot("Noisy")

combined_plot <- p_quiet + p_noisy +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom")

combined_plot

ggsave('/Users/marina-solo/Downloads/STAGE 2026 Solo/speech_mod_pavlovia/plot_quiet_noisy_sex.png',
       combined_plot, width = 12, height = 5, dpi = 300)
message("Plot saved!")

