## ----setup, include=FALSE-----------------------------------------------------
knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(readmit)

## ----project------------------------------------------------------------------
project <- rrp_project_init(tempfile("rrp-getting-started-"), "example-rrp")
as_of_time <- as.POSIXct("2026-01-10 12:00:00", tz = "UTC")
discharge_time <- as.POSIXct(c(
  "2026-01-08 12:00:00", "2026-01-01 12:00:00",
  "2025-12-01 12:00:00", "2026-01-04 12:00:00"
), tz = "UTC")
episodes <- data.frame(
  episode_id = paste0("episode-", 1:4),
  patient_id = paste0("patient-", 1:4),
  index_encounter_id = paste0("encounter-", 1:4),
  admission_time = discharge_time - 2 * 86400,
  discharge_time = discharge_time
)
events <- data.frame(
  terminal_event_id = c("event-2", "event-4"),
  episode_id = c("episode-2", "episode-4"),
  event_type = c("readmission", "death"),
  occurred_at = as.POSIXct(c(
    "2026-01-06 12:00:00", "2026-01-07 12:00:00"
  ), tz = "UTC")
)
saveRDS(list(discharge_episode = episodes, terminal_event = events),
        file.path(project, "canonical.rds"))

## ----author-------------------------------------------------------------------
writeLines(c(
  "rrp_produce_canonical <- function(project_root, as_of_time) {",
  "  readRDS(file.path(project_root, 'canonical.rds'))",
  "}"
), file.path(project, "R", "produce-canonical.R"))
writeLines(c(
  "rrp_calculate_risk <- function(project_root, request) {",
  "  list(probability = 0.30 * request$remaining_seconds / (30 * 86400))",
  "}"
), file.path(project, "R", "calculate-risk.R"))
rrp_project_validate(project)
rrp_state_init(project)

## ----assess-------------------------------------------------------------------
assessment <- rrp_run(project, as_of_time)
assessment[c("episodes_processed", "accepted", "provider_failures", "ineligible")]

status <- rrp_project_status(project)
status[c("state_initialized", "run_count")]
history <- rrp_inspect_history(project)
history[c("episode_id", "disposition", "probability")]
stopifnot(assessment$accepted == 1L, assessment$ineligible == 3L,
          isTRUE(all.equal(history$probability[history$disposition == "accepted"],
                           0.28)))

## ----products-----------------------------------------------------------------
products <- rrp_refresh_products(project)
current_risk <- read.csv(products$files[["current_risk"]])
trajectory <- read.csv(products$files[["trajectory"]])
scope <- read.csv(products$files[["scope"]])

current_risk[c("episode_id", "disposition", "probability")]
trajectory[c("episode_id", "probability")]
scope[c("episodes_assessed", "eligible_count", "accepted_count",
        "known_readmission_count", "known_death_count", "window_closed_count")]
stopifnot(nrow(current_risk) == 1L, nrow(trajectory) == 1L,
          scope$episodes_assessed == 4L)

