#' limitless::honest -- R143 LOUD-ONCE-WARNING-FLAG primitive (cohort-canonical R SDK).
#'
#' R 4.0+ port of the R143 LOUD-ONCE-WARNING-FLAG pattern shipped across the
#' Go cohort (drift-native / garrison / dipstick / paradox / spark LoudOnce-
#' style boot-warning surfaces), every Python flagship adopter, the Erlang
#' `limitless_beam_loud_once`, the Rust `honest` module in `limitless-rs`, and
#' the TS / Crystal / Fortran / D cohort siblings.
#'
#' The R143 contract:
#'   - First emission for a given code: write the formatted advisory to stderr,
#'     return TRUE.
#'   - Subsequent emissions for the same code: silent, return FALSE.
#'   - `loud_once_reset()` re-arms emission (test-only).
#'
#' R143.A SEVERITY-LADDER-CONVENTION: closed-set severity vocabulary.
#'
#' R145.B SIBLING-NOT-STACKED design note:
#'   This SDK ships the LoudOnce primitive + Severity vocab + Advisory type.
#'   It does NOT ship per-flagship canonical advisories because those are
#'   host-specific. Each flagship's host module imports limitless and
#'   declares its own canonical advisory() instances.
#'
#' Cohort literal pin:
#'   The line prefix `[LOUD-ONCE-WARNING]` is byte-identical to every cohort
#'   adopter.

# ---------------------------------------------------------------------------
# Cohort-canonical line prefix
# ---------------------------------------------------------------------------

#' Cohort-canonical line prefix for every LoudOnce emission.
#' @export
LOUD_ONCE_PREFIX <- "[LOUD-ONCE-WARNING]"

# ---------------------------------------------------------------------------
# Severity vocabulary (R143.A SEVERITY-LADDER-CONVENTION)
# ---------------------------------------------------------------------------

#' Closed-enum severity ladder (lowest -> highest).
#'
#' The cohort-canonical 4-value ladder: INFO < WARN < ERROR < CRITICAL.
#' @export
SEVERITY_LADDER <- c("INFO", "WARN", "ERROR", "CRITICAL")

#' Numeric ladder rank for a severity (higher = more severe).
#' Returns -1L for unknown severity strings.
#' @param severity Character scalar from `SEVERITY_LADDER`.
#' @return Integer rank in {0, 1, 2, 3}, or -1L if unknown.
#' @export
severity_rank <- function(severity) {
  if (!is.character(severity) || length(severity) != 1L) return(-1L)
  idx <- match(severity, SEVERITY_LADDER)
  if (is.na(idx)) return(-1L)
  as.integer(idx - 1L)
}

#' Canonical SCREAMING-form label for a severity. Validates membership.
#' @param severity Character scalar from `SEVERITY_LADDER`.
#' @return Character scalar.
#' @export
severity_label <- function(severity) {
  if (!is.character(severity) || length(severity) != 1L) {
    stop("severity_label: input must be a single character string")
  }
  if (!severity %in% SEVERITY_LADDER) {
    stop(sprintf("severity_label: unknown severity '%s' (closed-set: %s)",
                 severity, paste(SEVERITY_LADDER, collapse = ", ")))
  }
  severity
}

# ---------------------------------------------------------------------------
# Advisory type
# ---------------------------------------------------------------------------

#' Construct a single boot-time advisory.
#'
#' Fields:
#'   code:     short stable identifier; used as the LoudOnce dedupe key.
#'   severity: one of `SEVERITY_LADDER`.
#'   message:  human-readable message text.
#'   doc_link: file:line or URL pointing to the canonical source.
#'
#' @param code Character scalar.
#' @param severity Character scalar from `SEVERITY_LADDER`.
#' @param message Character scalar.
#' @param doc_link Character scalar.
#' @return A list with class "limitless_advisory".
#' @export
advisory <- function(code, severity, message, doc_link) {
  if (!is.character(code) || length(code) != 1L || nchar(code) == 0L) {
    stop("advisory: code must be a non-empty single string")
  }
  if (!severity %in% SEVERITY_LADDER) {
    stop(sprintf("advisory: severity '%s' not in closed-set (%s)",
                 severity, paste(SEVERITY_LADDER, collapse = ", ")))
  }
  if (!is.character(message) || length(message) != 1L) {
    stop("advisory: message must be a single string")
  }
  if (!is.character(doc_link) || length(doc_link) != 1L) {
    stop("advisory: doc_link must be a single string")
  }
  obj <- list(code = code, severity = severity, message = message, doc_link = doc_link)
  class(obj) <- "limitless_advisory"
  obj
}

# ---------------------------------------------------------------------------
# LoudOnce singleton (R143 primitive)
# ---------------------------------------------------------------------------

# Package-level state lives in a private environment. This is the canonical
# R idiom for module-singleton state (analogous to `@@` in Crystal or
# `__gshared` in D).
.honest_state <- new.env(parent = emptyenv())
.honest_state$seen <- character(0L)
.honest_state$host_prefix <- "limitless"

.format_line <- function(adv) {
  sprintf("%s %s %s %s: %s (see %s)",
          .honest_state$host_prefix, LOUD_ONCE_PREFIX, adv$severity,
          adv$code, adv$message, adv$doc_link)
}

#' Emit advisory iff this is the first call for its code.
#'
#' R143 LOUD-ONCE-WARNING-FLAG canonical primitive. First call with a given
#' code writes the formatted advisory line to `con` (default stderr) and
#' returns TRUE. Subsequent calls with the same code are silent and return
#' FALSE.
#'
#' @param adv An advisory list from `advisory()`.
#' @param con Connection to write to (default stderr()).
#' @return Logical scalar: TRUE iff this was the first emission for `adv$code`.
#' @export
loud_once <- function(adv, con = stderr()) {
  if (!inherits(adv, "limitless_advisory")) {
    stop("loud_once: adv must be a limitless_advisory (use advisory() to construct)")
  }
  if (adv$code %in% .honest_state$seen) return(FALSE)
  .honest_state$seen <- c(.honest_state$seen, adv$code)
  cat(.format_line(adv), "\n", sep = "", file = con)
  TRUE
}

#' Reset the LoudOnce registry. TEST-ONLY.
#' @return invisible(NULL)
#' @export
loud_once_reset <- function() {
  .honest_state$seen <- character(0L)
  .honest_state$host_prefix <- "limitless"
  invisible(NULL)
}

#' Emit every advisory in the input once. Returns the count newly-emitted
#' (i.e. excluding advisories whose code was already seen).
#' @param advisories A list of advisory objects.
#' @param con Connection to write to (default stderr()).
#' @return Integer count emitted-fresh.
#' @export
loud_once_emit_all <- function(advisories, con = stderr()) {
  if (!is.list(advisories)) stop("loud_once_emit_all: advisories must be a list")
  emitted_fresh <- 0L
  for (adv in advisories) {
    if (loud_once(adv, con = con)) emitted_fresh <- emitted_fresh + 1L
  }
  emitted_fresh
}

#' Has an advisory with this code been emitted in this session?
#' @param code Character scalar.
#' @return Logical scalar.
#' @export
loud_once_has_emitted <- function(code) {
  if (!is.character(code) || length(code) != 1L) return(FALSE)
  code %in% .honest_state$seen
}

#' Number of distinct codes emitted in this session.
#' @return Integer count.
#' @export
loud_once_cardinality <- function() {
  length(.honest_state$seen)
}

#' Override the host prefix for LoudOnce line emissions.
#'
#' Default is `"limitless"`. Host applications may set this to their own
#' name (e.g. `"folio"`, `"nexus"`) for clearer multi-process log streams.
#' @param prefix Character scalar.
#' @return invisible(NULL)
#' @export
loud_once_set_host_prefix <- function(prefix) {
  if (!is.character(prefix) || length(prefix) != 1L) {
    stop("loud_once_set_host_prefix: prefix must be a single string")
  }
  .honest_state$host_prefix <- prefix
  invisible(NULL)
}
