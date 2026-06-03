library(tidyverse)

# LOAD DATA
corr_data <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/Correlation table ENV_20.csv')

# PARSE
corr_data <- corr_data %>%
  mutate(
    bands_num   = as.integer(str_extract(sentence, "\\d+(?=bands)")),
    sentence_id = str_extract(sentence, ".+(?= - Version)"),
    talker_id   = str_sub(sentence, 3, 4),
    talker_sex  = ifelse(talker_id %in% c("01", "06", "10", "12"), "M", "F")
  ) %>%
  filter(!is.na(bands_num), !is.na(LR_vs_Original))

# MEAN per band
mean_data <- corr_data %>%
  group_by(bands_num) %>%
  summarise(mean_corr = mean(LR_vs_Original, na.rm = TRUE), .groups = "drop")

# COLOUR MAP - greens for M, pinks for F
# Check which talker IDs are actually in your data first
all_ids <- unique(corr_data$talker_id)
male_ids   <- c("01", "06", "10", "12")
female_ids <- setdiff(all_ids, male_ids)

# Shades of green for males, shades of pink for females
green_shades <- colorRampPalette(c("#06402B", "#90EE90"))(length(male_ids))
pink_shades  <- colorRampPalette(c("#FF007F", "#FFB6C1"))(length(female_ids))

names(green_shades) <- sort(male_ids)
names(pink_shades)  <- sort(female_ids)

talker_colours <- c(green_shades, pink_shades)

# PLOT
p <- ggplot() +
  geom_line(data = corr_data,
            aes(x = bands_num, y = LR_vs_Original, group = sentence_id, colour = talker_id),
            alpha = 0.9, linewidth = 0.6) +
  geom_point(data = corr_data,
             aes(x = bands_num, y = LR_vs_Original, group = sentence_id, colour = talker_id),
             alpha = 0.4, size = 0.5) +
  geom_line(data = mean_data,
            aes(x = bands_num, y = mean_corr),
            colour = "#E56717", linewidth = 1.5) +
  geom_point(data = mean_data,
             aes(x = bands_num, y = mean_corr),
             colour = "#E56717", size = 3) +
  scale_colour_manual(values = talker_colours, name = "Talker ID") +
  scale_x_continuous(breaks = sort(unique(corr_data$bands_num))) +
  scale_y_continuous(breaks = seq(-1, 1, 0.2)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
  labs(
    title = "LR Sentences - Correlation with Original (cutoff = 20)",
    x     = "Number of Bands",
    y     = "Correlation Score (LR vs Original)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(hjust = 0.5, face = "bold")
  )

p

ggsave('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/plot_LR_correlation_adaptive.png',
       p, width = 10, height = 6, dpi = 300)
message("Plot saved!")

scales::show_col(talker_colours)

cat("Male talkers:", sort(male_ids), "\n")
cat("Female talkers:", sort(female_ids), "\n")







# LOAD DATA
corr_data <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/Correlation table ENV_20.csv')

# PARSE
corr_data <- corr_data %>%
  mutate(
    bands_num   = as.integer(str_extract(sentence, "\\d+(?=bands)")),
    sentence_id = str_extract(sentence, ".+(?= - Version)"),
    talker_id   = str_sub(sentence, 3, 4),
    talker_sex  = if(talker_id %in% c("01", "06", "10", "12"), "M", "F"),
    if 
  ) %>%
  filter(!is.na(bands_num), !is.na(LR_vs_Original))

# MEAN per band
mean_data <- corr_data %>%
  group_by(bands_num) %>%
  summarise(mean_corr = mean(LR_vs_Original, na.rm = TRUE), .groups = "drop")

# PLOT
p <- ggplot() +
  geom_line(data = corr_data,
            aes(x = bands_num, y = LR_vs_Original, group = sentence_id, colour = talker_sex),
            alpha = 0.2, linewidth = 0.6) +
  geom_point(data = corr_data,
             aes(x = bands_num, y = LR_vs_Original, group = sentence_id, colour = talker_sex),
             alpha = 0.2, size = 0.5) +
  geom_line(data = mean_data,
            aes(x = bands_num, y = mean_corr),
            colour = "#E56717", linewidth = 1.5) +
  geom_point(data = mean_data,
             aes(x = bands_num, y = mean_corr),
             colour = "#E56717", size = 3) +
  scale_colour_manual(values = c("M" = "#5D3A9B", "F" = "#FF00FF"),
                      name = "Talker sex") +
  scale_x_continuous(breaks = sort(unique(corr_data$bands_num))) +
  scale_y_continuous(breaks = seq(-1, 1, 0.2)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
  labs(
    title = "LR Sentences - Correlation with Original (cuttoff = 20)",
    x     = "Number of Bands",
    y     = "Correlation Score (LR vs Original)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(hjust = 0.5, face = "bold")
  )

p

ggsave('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/plot_LR_correlation_adaptive.png',
       p, width = 10, height = 6, dpi = 300)
message("Plot saved!")








# LOAD DATA
corr_data <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/Correlation table ENV_20.csv')

# PARSE sentence column to extract number of bands
corr_data <- corr_data %>%
  mutate(
    bands_num = as.integer(str_extract(sentence, "\\d+(?=bands)")),
    sentence_id = str_extract(sentence, ".+(?= - Version)"),
    talker_id  = str_sub(sentence, 3, 4),
    talker_sex = ifelse(talker_id %in% c("01", "06", "10", "12"), "M", "F")
    )
  filter(!is.na(bands_num), !is.na(LR_vs_Original))

# MEAN per band
mean_data <- corr_data %>%
  group_by(bands_num) %>%
  summarise(mean_corr = mean(LR_vs_Original, na.rm = TRUE), .groups = "drop")

# PLOT
p <- ggplot() +
  # individual sentence lines
  geom_line(data = corr_data,
            aes(x = bands_num, y = LR_vs_Original, group = sentence_id),
            colour = ifelse(talker_sex "M", "#5D3A9B", "#FF00FF"), alpha = 0.2, linewidth = 0.4) +
  # individual sentence points
  geom_point(data = corr_data,
             aes(x = bands_num, y = LR_vs_Original, group = sentence_id),
             colour = ifelse(talker_sex "M", "#5D3A9B", "#FF00FF"), alpha = 0.2, size = 0.5) +
  # mean line
  geom_line(data = mean_data,
            aes(x = bands_num, y = mean_corr),
            colour = "#E56717", linewidth = 1.5) +
  geom_point(data = mean_data,
             aes(x = bands_num, y = mean_corr),
             colour = "#E56717", size = 3) +
  scale_x_continuous(breaks = sort(unique(corr_data$bands_num))) +
  scale_y_continuous(breaks = seq(-1, 1, 0.2)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
  labs(
    title = "LR Sentences - Correlation with Original (adaptive threshold)",
    x     = "Number of Bands",
    y     = "Correlation Score (LR vs Original)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(hjust = 0.5, face = "bold")
  )

p

ggsave('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/plot_LR_correlation_adaptive.png',
       p, width = 10, height = 6, dpi = 300)
message("Plot saved!")

# ________ NOISE VOCODED ________

# LOAD DATA
corr_data <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/Correlation table 5.csv')

# PARSE sentence column to extract number of bands
corr_data <- corr_data %>%
  mutate(
    bands_num = as.integer(str_extract(sentence, "\\d+(?=bands)")),
    sentence_id = str_extract(sentence, ".+(?= - Version)")
  ) %>%
  filter(!is.na(bands_num), !is.na(NV_vs_Original))

# MEAN per band
mean_data <- corr_data %>%
  group_by(bands_num) %>%
  summarise(mean_corr = mean(NV_vs_Original, na.rm = TRUE), .groups = "drop")

# PLOT
p <- ggplot() +
  # individual sentence lines
  geom_line(data = corr_data,
            aes(x = bands_num, y = NV_vs_Original, group = sentence_id),
            colour = "#5D3A9B", alpha = 0.2, linewidth = 0.4) +
  # individual sentence points
  geom_point(data = corr_data,
             aes(x = bands_num, y = NV_vs_Original, group = sentence_id),
             colour = "#5D3A9B", alpha = 0.2, size = 0.5) +
  # mean line
  geom_line(data = mean_data,
            aes(x = bands_num, y = mean_corr),
            colour = "#E56717", linewidth = 1.5) +
  geom_point(data = mean_data,
             aes(x = bands_num, y = mean_corr),
             colour = "#E56717", size = 3) +
  scale_x_continuous(breaks = sort(unique(corr_data$bands_num))) +
  scale_y_continuous(breaks = seq(-1, 1, 0.2)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey40") +
  labs(
    title = "NV Sentences - Correlation with Original (adaptive threshold)",
    x     = "Number of Bands",
    y     = "Correlation Score (NV vs Original)"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    panel.grid.minor = element_blank(),
    plot.title       = element_text(hjust = 0.5, face = "bold")
  )

p

ggsave('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/plot_NV_correlation_adaptive.png',
       p, width = 10, height = 6, dpi = 300)
message("Plot saved!")