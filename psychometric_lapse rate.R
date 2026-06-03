install.packages("psyphy")

library(tidyverse)
library(psyphy)
library(lme4)

# ── 1. Load and prepare data ──────────────────────────────────────────────────

model_data <- read_csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/50_shallowest_noise.csv')

model_data <- model_data %>%
  mutate(
    cond = recode(cond, "Q" = "Quiet", "N" = "Noisy"),
    word_percentage_rescale = as.numeric(word_percentage_rescale),
    proc_label = ifelse(proc == "NV", "Noise Vocoded", "Locally Rotated"),
    bands_num  = as.numeric(str_remove(bands, "b")),
    log_bands  = log(bands_num)
  ) %>%
  mutate(word_proportion_M = str_trim(word_proportion_M)) %>%
  tidyr::separate(
    word_proportion_M,
    into    = c("n_correct", "n_total"),
    sep     = " of ",
    convert = TRUE
  )

original_bands <- sort(unique(model_data$bands_num))
log_band_vals  <- log(original_bands)

# ── 2. Fit glmer with fixed lapse rate per group ──────────────────────────────
# psyphy's logit.2asym(g, lam):
#   g   = guess rate (0 = no guessing)
#   lam = lapse rate, initialised from the data's upper tail

groups <- model_data %>%
  distinct(proc_label, cond) %>%
  arrange(proc_label, cond)

fit_group <- function(proc_l, cond_l) {
  d <- model_data %>%
    filter(proc_label == proc_l, cond == cond_l)
  
  lam_start <- 1 - mean(
    d$word_percentage_rescale[d$bands_num == max(d$bands_num)],
    na.rm = TRUE
  ) / 100
  lam_start <- max(0.001, min(0.2, lam_start))
  
  link <- logit.2asym(g = 0, lam = lam_start)
  
  m <- glmer(
    cbind(n_correct, n_total - n_correct) ~ log_bands + (1 | sid),
    data   = d,
    family = binomial(link = link)
  )
  
  list(model = m, proc_label = proc_l, cond = cond_l, lam = lam_start)
}

# Iterate row by row safely (avoids pmap/anonymous function issues)
fits <- vector("list", nrow(groups))
for (i in seq_len(nrow(groups))) {
  fits[[i]] <- fit_group(groups$proc_label[i], groups$cond[i])
}
names(fits) <- paste(groups$proc_label, groups$cond, sep = " | ")

# ── 3. Print model summaries ──────────────────────────────────────────────────

for (f in fits) {
  cat("\n══════════════════════════════════════════\n")
  cat(f$proc_label, "|", f$cond, "\n")
  cat("══════════════════════════════════════════\n")
  print(summary(f$model))
}

# ── 4. Generate predicted curves ──────────────────────────────────────────────

log_seq <- seq(min(log_band_vals), max(log_band_vals), length.out = 200)

pred_curves <- map_dfr(fits, function(f) {
  beta <- fixef(f$model)
  lp   <- beta["(Intercept)"] + beta["log_bands"] * log_seq
  p    <- (1 - f$lam) * plogis(lp)
  tibble(
    log_bands  = log_seq,
    bands_num  = exp(log_seq),
    pred_pct   = p * 100,
    proc_label = f$proc_label,
    cond       = f$cond
  )
})

# ── 5. Observed means per band x group ───────────────────────────────────────

obs <- model_data %>%
  group_by(log_bands, bands_num, proc_label, cond) %>%
  summarise(
    mean_pct = mean(word_percentage_rescale, na.rm = TRUE),
    .groups  = "drop"
  )

# ── 6. 50% thresholds ────────────────────────────────────────────────────────

thresholds <- map_dfr(fits, function(f) {
  beta   <- fixef(f$model)
  target <- 0.5 / (1 - f$lam)
  target <- min(target, 0.9999)
  lp_50  <- qlogis(target)
  x_50   <- (lp_50 - beta["(Intercept)"]) / beta["log_bands"]
  tibble(
    proc_label   = f$proc_label,
    cond         = f$cond,
    log_thresh   = x_50,
    bands_thresh = exp(x_50)
  )
})

cat("\n── Thresholds (50% correct) ──\n")
print(thresholds)

# ── 7. Colour + linetype palette ──────────────────────────────────────────────

group_aes <- tribble(
  ~proc_label,       ~cond,    ~colour,   ~linetype,
  "Noise Vocoded",   "Quiet",  "#E66100", "solid",
  "Noise Vocoded",   "Noisy",  "#E66100", "dashed",
  "Locally Rotated", "Quiet",  "#5D3A9B", "solid",
  "Locally Rotated", "Noisy",  "#5D3A9B", "dashed"
)

pred_curves <- left_join(pred_curves, group_aes, by = c("proc_label", "cond")) %>%
  mutate(group = paste(proc_label, cond))
obs         <- left_join(obs,         group_aes, by = c("proc_label", "cond")) %>%
  mutate(group = paste(proc_label, cond))
thresholds  <- left_join(thresholds,  group_aes, by = c("proc_label", "cond")) %>%
  mutate(group = paste(proc_label, cond))

colour_map   <- setNames(group_aes$colour,   paste(group_aes$proc_label, group_aes$cond))
linetype_map <- setNames(group_aes$linetype, paste(group_aes$proc_label, group_aes$cond))

# ── 8. Single 4-line plot ─────────────────────────────────────────────────────

p <- ggplot() +
  geom_line(
    data = pred_curves,
    aes(x = log_bands, y = pred_pct, colour = group, linetype = group),
    linewidth = 0.8
  ) +
  geom_point(
    data = obs,
    aes(x = log_bands, y = mean_pct, colour = group, shape = cond),
    size = 2.5, alpha = 0.8
  ) +
  geom_vline(
    data = thresholds,
    aes(xintercept = log_thresh, colour = group, linetype = group),
    linewidth = 0.4, alpha = 0.6
  ) +
  scale_colour_manual(values = colour_map,   name = NULL) +
  scale_linetype_manual(values = linetype_map, name = NULL) +
  scale_shape_manual(values = c("Quiet" = 16, "Noisy" = 17), name = "Condition") +
  scale_x_continuous(breaks = log_band_vals, labels = original_bands) +
  scale_y_continuous(limits = c(0, 100), breaks = seq(0, 100, 20)) +
  labs(
    title = "Psychometric functions — free lapse rate",
    x     = "Number of bands (log scale)",
    y     = "% words correct"
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position  = "bottom",
    legend.key.width = unit(1.5, "cm"),
    panel.grid.minor = element_blank(),
    plot.title       = element_text(hjust = 0.5, face = "bold")
  ) +
  guides(
    colour   = guide_legend(nrow = 2),
    linetype = guide_legend(nrow = 2),
    shape    = guide_legend(nrow = 2)
  )

print(p)

ggsave(
  '/Users/marina-solo/Downloads/STAGE 2026 Solo/speech_mod_pavlovia/plot_probit_lapse_4lines_worst50.png',
  p, width = 9, height = 6, dpi = 300
)
message("Plot saved!")

