#' limitless::kat -- KAT-1 cross-substrate parity assertion (cohort-canonical R SDK).
#'
#' Re-binds the KAT-1 anchor + `assert_kat1_parity()` for callers that want a
#' single `kat::` namespace surface for parity-test wiring. The actual literals
#' + the parity-check implementation live in `R/mirrormark.R`; this file
#' exists for convenience + cohort-shape parity with the Crystal / D / Fortran
#' sibling SDKs.
#'
#' R151 KAT-AS-COHORT-INVARIANT-CROSS-SUBSTRATE-PIN: the KAT-1 hex
#' 239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca is the
#' cohort firewall. `assert_kat1_parity()` stops on drift.

# Note: the canonical bindings are exported from R/mirrormark.R:
#   - KAT1_DIGEST_HEX
#   - KAT1_MARK
#   - kat1_input()
#   - assert_kat1_parity()
# No re-export wrapper is needed — they all live in the same package namespace
# and are exported via NAMESPACE.

#' Compute the KAT-1 HMAC-SHA256 hex from canonical inputs.
#'
#' Convenience wrapper around the canonical algorithm: HMAC-SHA256 with
#' empty key over `kat1_input()`. Returned hex MUST equal `KAT1_DIGEST_HEX`
#' or the cohort cross-substrate firewall (R151) has drifted.
#'
#' This is the "compute it freshly to check" surface; for the assertion
#' contract use `assert_kat1_parity()`.
#'
#' @return Lowercase hex string of length 64.
#' @export
kat1_compute <- function() {
  bytes_to_hex(.hmac_sha256(raw(0L), kat1_input()))
}
