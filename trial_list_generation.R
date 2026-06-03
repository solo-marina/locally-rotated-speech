# =============================================================================
# generate_trial_lists.R
# Generates 200 randomised trial lists from a directory of .wav stimuli.
#
# File naming convention:
#   ID01_L9_S6_LR_20b_LBR.wav
#   Fields: speaker_id, list, sentence, processing, bands, babble
#
# Trial list constraints (100 sentences per list):
#   - 10 speakers x 10 sentences each
#   - 20 conditions (2 proc x 2 babble x 5 bands) x 5 repetitions each
#   - No (speaker, list, sentence) triple repeated within a list
#   - Across lists: cycling — each (speaker x sentence) slot used as evenly
#     as possible, minimising repeats
# =============================================================================

library(dplyr)
library(tidyr)
library(readr)
library(stringr)

# -----------------------------------------------------------------------------
# CONFIGURATION — edit these paths/values as needed
# -----------------------------------------------------------------------------
AUDIO_DIR    <- "/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/audio"
OUTPUT_DIR   <- "/Users/marina-solo/Downloads/STAGE 2026 Solo/Experiment 2/trial_lists"
N_LISTS      <- 200
N_SENTENCES  <- 100   # per list
N_SPEAKERS   <- 10
SENT_PER_SPK <- 10    # sentences per speaker per list
COND_REPS    <- 5     # repetitions of each condition per list (20 conds x 5 = 100)

# -----------------------------------------------------------------------------
# STEP 1 — Enumerate all wav files and parse filenames
# -----------------------------------------------------------------------------
cat("Scanning audio directory...\n")

all_files <- list.files(AUDIO_DIR, pattern = "\\.wav$", full.names = FALSE)
cat(sprintf("Found %d .wav files.\n", length(all_files)))

# Parse filename fields
parse_filename <- function(fname) {
  # Remove .wav extension
  base <- sub("\\.wav$", "", fname)
  parts <- str_split(base, "_")[[1]]
  # Expected: ID01 L9 S6 LR 20b LBR  (6 parts)
  if (length(parts) != 6) return(NULL)
  data.frame(
    stimulus_path = paste0("audio/", fname),
    sid_full      = parts[1],                          # e.g. ID01
    speaker_id    = as.integer(sub("ID", "", parts[1])), # numeric speaker id
    list_num      = as.integer(sub("L", "", parts[2])), # numeric list
    sent_num      = as.integer(sub("S", "", parts[3])), # numeric sentence
    proc          = parts[4],                          # e.g. LR, NV
    bands         = parts[5],                          # e.g. 20b
    babble        = parts[6],                          # e.g. LBR
    sent_id       = paste0(parts[2], "_", parts[3]),   # e.g. L9_S6
    stringsAsFactors = FALSE
  )
}

parsed_list <- lapply(all_files, parse_filename)
parsed_list <- Filter(Negate(is.null), parsed_list)
master      <- bind_rows(parsed_list)

cat(sprintf("Parsed %d files successfully.\n", nrow(master)))

# Validate expected speakers
valid_speakers <- c(1, 3, 4, 6, 7, 8, 9, 10, 11, 12)  # ID01-ID12 skipping 02,05
master <- master %>% filter(speaker_id %in% valid_speakers)
cat(sprintf("After speaker filter: %d files.\n", nrow(master)))

# All 20 conditions (proc x babble x bands)
all_conditions <- master %>%
  distinct(proc, bands, babble) %>%
  arrange(proc, bands, babble)

n_conditions <- nrow(all_conditions)
cat(sprintf("Detected %d unique conditions.\n", n_conditions))

if (n_conditions != 20) {
  warning(sprintf("Expected 20 conditions but found %d — check your data!", n_conditions))
}

# -----------------------------------------------------------------------------
# DIAGNOSTIC — report any missing (speaker x sentence x condition) combinations
# -----------------------------------------------------------------------------
cat("\nChecking for missing (speaker x sentence x condition) combinations...\n")

all_sent_ids    <- unique(master$sent_id)
expected_combos <- expand.grid(
  speaker_id = valid_speakers,
  sent_id    = all_sent_ids,
  proc       = all_conditions$proc,
  bands      = all_conditions$bands,
  babble     = all_conditions$babble,
  stringsAsFactors = FALSE
)

actual_combos <- master %>%
  select(speaker_id, sent_id, proc, bands, babble) %>%
  distinct()

missing <- anti_join(expected_combos, actual_combos,
                     by = c("speaker_id", "sent_id", "proc", "bands", "babble"))

if (nrow(missing) == 0) {
  cat("No missing combinations — stimulus set is complete. ✓\n\n")
} else {
  cat(sprintf("WARNING: %d missing (speaker x sentence x condition) combinations found!\n", nrow(missing)))
  cat("These will trigger sentence substitutions during list generation.\n")
  dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)
  missing_file <- file.path(OUTPUT_DIR, "missing_stimuli.csv")
  write_csv(missing, missing_file)
  cat(sprintf("Full list written to: %s\n", missing_file))
  cat("Check your audio folder for these files before proceeding.\n\n")
}

# Condition slots per list: COND_REPS copies of each condition spread across
# the 10 speaker slots. We need to assign one condition per (speaker x sentence)
# slot such that across 10 speakers x 10 sentences = 100 slots, each of the 20
# conditions appears exactly COND_REPS (5) times.

# Pre-build the condition assignment template for one list:
# 100 condition slots = 20 conditions * 5 reps, shuffled
make_condition_template <- function() {
  conds <- do.call(rbind, replicate(COND_REPS, all_conditions, simplify = FALSE))
  conds[sample(nrow(conds)), ]  # random shuffle
}

# -----------------------------------------------------------------------------
# STEP 2 — Build per-speaker sentence pools with usage counters
# -----------------------------------------------------------------------------
# For each speaker, get all unique sent_ids and their available condition rows.
# We track usage counts so we can cycle through least-used sentences first.

speaker_ids <- sort(unique(master$speaker_id))
stopifnot(length(speaker_ids) == N_SPEAKERS)

# Pool: for each (speaker, sent_id) pair, list all available stimulus rows
speaker_pools <- list()
for (spk in speaker_ids) {
  spk_data <- master %>% filter(speaker_id == spk)
  sent_ids  <- unique(spk_data$sent_id)
  pool <- list(
    sent_ids  = sent_ids,
    usage     = setNames(integer(length(sent_ids)), sent_ids),  # usage counter
    data      = spk_data
  )
  speaker_pools[[as.character(spk)]] <- pool
}

# Helper: pick the SENT_PER_SPK least-used sent_ids for a speaker,
# avoiding any sent_id already in 'used_sents' for this list
pick_sentences_for_speaker <- function(pool, used_sents, n = SENT_PER_SPK) {
  available <- setdiff(pool$sent_ids, used_sents)
  if (length(available) < n) {
    # Cycle: reset to all sent_ids (still excluding within-list used ones)
    # This should rarely happen but handles edge cases gracefully
    available <- pool$sent_ids[!(pool$sent_ids %in% used_sents)]
    if (length(available) < n) {
      stop("Not enough unique sentences available for speaker — check data.")
    }
  }
  # Sort by usage count ascending, then shuffle within ties
  usage_avail <- pool$usage[available]
  # Add tiny random jitter to break ties randomly
  jitter      <- runif(length(usage_avail))
  order_idx   <- order(usage_avail + jitter * 0.01)
  chosen      <- available[order_idx[1:n]]
  return(chosen)
}

# -----------------------------------------------------------------------------
# STEP 3 — Generate 200 trial lists
# -----------------------------------------------------------------------------
dir.create(OUTPUT_DIR, showWarnings = FALSE, recursive = TRUE)

set.seed(42)  # for reproducibility — change or remove if you want fresh randomness

cat(sprintf("\nGenerating %d trial lists...\n", N_LISTS))

for (list_idx in 1:N_LISTS) {
  
  used_sents_this_list <- character(0)  # sent_ids used in this list
  trial_rows <- list()
  
  # --- Assign conditions for this list ---
  cond_template <- make_condition_template()  # 100 rows, shuffled conditions
  cond_row_idx  <- 1  # pointer into condition template
  
  # --- Per-speaker sentence selection ---
  for (spk in speaker_ids) {
    spk_key  <- as.character(spk)
    pool     <- speaker_pools[[spk_key]]
    
    # Pick SENT_PER_SPK sentences, cycling by least usage, avoiding within-list repeats
    chosen_sents <- pick_sentences_for_speaker(pool, used_sents_this_list)
    
    # Update usage counters
    speaker_pools[[spk_key]]$usage[chosen_sents] <-
      speaker_pools[[spk_key]]$usage[chosen_sents] + 1
    
    # Add chosen sent_ids to this list's used set
    used_sents_this_list <- c(used_sents_this_list, chosen_sents)
    
    # For each chosen sentence, pick a stimulus matching the assigned condition
    for (sent in chosen_sents) {
      # Get next condition from template
      cond_row <- cond_template[cond_row_idx, ]
      cond_row_idx <- cond_row_idx + 1
      
      # Find matching stimulus row for this speaker x sent_id x condition
      candidate <- pool$data %>%
        filter(
          sent_id == sent,
          proc    == cond_row$proc,
          bands   == cond_row$bands,
          babble  == cond_row$babble
        )
      
      if (nrow(candidate) == 0) {
        # Required condition missing for this sentence — find a substitute sentence
        # for this speaker that (a) has the required condition, and (b) is not
        # already used in this list.
        substitute <- pool$data %>%
          filter(
            proc   == cond_row$proc,
            bands  == cond_row$bands,
            babble == cond_row$babble,
            !(sent_id %in% used_sents_this_list)
          )
        if (nrow(substitute) == 0) {
          stop(sprintf(
            "List %03d: cannot find any substitute sentence for spk %d, cond %s_%s_%s not already used in this list. Check your stimulus set.",
            list_idx, spk, cond_row$proc, cond_row$bands, cond_row$babble
          ))
        }
        # Pick least-used substitute (by usage counter), break ties randomly
        sub_sents   <- unique(substitute$sent_id)
        sub_usage   <- pool$usage[sub_sents]
        sub_jitter  <- runif(length(sub_usage))
        best_sent   <- sub_sents[which.min(sub_usage + sub_jitter * 0.01)]
        candidate   <- substitute %>% filter(sent_id == best_sent)
        candidate   <- candidate[sample(nrow(candidate), 1), ]
        
        # Replace the originally chosen sent in the used set and usage counter
        used_sents_this_list <- c(used_sents_this_list, best_sent)
        speaker_pools[[spk_key]]$usage[best_sent] <-
          speaker_pools[[spk_key]]$usage[best_sent] + 1
        
        warning(sprintf(
          "List %03d: spk %d, sent %s missing cond %s_%s_%s — substituted with %s.",
          list_idx, spk, sent, cond_row$proc, cond_row$bands, cond_row$babble,
          best_sent
        ))
      } else {
        candidate <- candidate[sample(nrow(candidate), 1), ]  # pick one if duplicates
      }
      
      trial_rows[[length(trial_rows) + 1]] <- data.frame(
        proc           = candidate$proc,
        bands          = candidate$bands,
        cond           = candidate$babble,
        ID             = sprintf("%02d", candidate$speaker_id),
        list           = candidate$list_num,
        sent           = candidate$sent_num,
        sid            = candidate$sent_id,
        stimulus_path  = candidate$stimulus_path,
        stringsAsFactors = FALSE
      )
    }
  }
  
  # Combine and shuffle rows
  trial_df <- bind_rows(trial_rows)
  trial_df <- trial_df[sample(nrow(trial_df)), ]
  
  # Write CSV
  out_file <- file.path(OUTPUT_DIR, sprintf("trial_%03d.csv", list_idx))
  write_csv(trial_df, out_file)
  
  if (list_idx %% 10 == 0) cat(sprintf("  Generated list %d / %d\n", list_idx, N_LISTS))
}

cat("\nDone! All trial lists written to:\n")
cat(OUTPUT_DIR, "\n")

# -----------------------------------------------------------------------------
# STEP 4 — Sanity checks on generated lists
# -----------------------------------------------------------------------------
cat("\nRunning sanity checks on all generated lists...\n")

check_results <- data.frame(
  list_num          = integer(N_LISTS),
  n_rows            = integer(N_LISTS),
  n_unique_sents    = integer(N_LISTS),
  n_unique_speakers = integer(N_LISTS),
  cond_balance_ok   = logical(N_LISTS),
  stringsAsFactors  = FALSE
)

for (list_idx in 1:N_LISTS) {
  f  <- file.path(OUTPUT_DIR, sprintf("trial_%03d.csv", list_idx))
  df <- read_csv(f, show_col_types = FALSE)
  
  # Check condition balance
  cond_counts <- df %>%
    count(proc, bands, cond) %>%
    pull(n)
  cond_ok <- all(cond_counts == COND_REPS) && length(cond_counts) == n_conditions
  
  check_results[list_idx, ] <- list(
    list_num          = list_idx,
    n_rows            = nrow(df),
    n_unique_sents    = length(unique(df$sid)),
    n_unique_speakers = length(unique(df$ID)),
    cond_balance_ok   = cond_ok
  )
}

cat("\n--- Sanity Check Summary ---\n")
cat(sprintf("Lists with correct row count (100):     %d / %d\n",
            sum(check_results$n_rows == N_SENTENCES), N_LISTS))
cat(sprintf("Lists with 100 unique sentences:        %d / %d\n",
            sum(check_results$n_unique_sents == N_SENTENCES), N_LISTS))
cat(sprintf("Lists with all 10 speakers:             %d / %d\n",
            sum(check_results$n_unique_speakers == N_SPEAKERS), N_LISTS))
cat(sprintf("Lists with balanced conditions (5x20):  %d / %d\n",
            sum(check_results$cond_balance_ok), N_LISTS))

# Flag any failures
failures <- check_results %>% filter(
  n_rows != N_SENTENCES |
    n_unique_sents != N_SENTENCES |
    n_unique_speakers != N_SPEAKERS |
    !cond_balance_ok
)
if (nrow(failures) > 0) {
  cat("\nWARNING — the following lists failed one or more checks:\n")
  print(failures)
} else {
  cat("\nAll lists passed all checks! ✓\n")
}
