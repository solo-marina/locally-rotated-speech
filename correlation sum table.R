library(tidyverse)

# Load the table
results <- read.csv('/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/Correlation table extra.csv')

# Extract number of bands
results <- results %>%
  mutate(Nbands = as.numeric(str_extract(sentence, '\\d+(?=bands)')))

# Paired t-test per band condition
pvalues <- results %>%
  group_by(Nbands) %>%
  summarise(
    mean_NV = mean(NV_vs_Original),
    mean_LR = mean(LR_vs_Original),
    p_NV_vs_LR = t.test(NV_vs_Original, LR_vs_Original, paired = TRUE)$p.value
  )

print(pvalues, digits = 6)
write.csv(pvalues, '/Users/marina-solo/Downloads/STAGE 2026 Solo/audio simulation/Correlation summary extra.csv', row.names = FALSE)
