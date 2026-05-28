#' limitless: Cohort-canonical R SDK for the Limitless ecosystem.
#'
#' Ships four cohort-canonical primitives:
#'
#' \itemize{
#'   \item L43 Mirror-Mark v1 sign / verify (`mm_sign`, `mm_verify`).
#'   \item R143 LOUD-ONCE-WARNING-FLAG (`loud_once`, `advisory`).
#'   \item R166 LIABILITY-FOOTER-CONST + UK GDPR refs (`DEFAULT_PLACEHOLDER_ALERT`).
#'   \item R151 KAT-AS-COHORT-INVARIANT-CROSS-SUBSTRATE-PIN (`assert_kat1_parity`).
#' }
#'
#' R151 KAT-1 anchor (cross-substrate firewall):
#' `239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca`
#'
#' All literals are byte-aligned with the Go canonical foundation +
#' lore-mark-verify CLI + the limitless-{py, ts, rs, beam-otp, c-crypto,
#' crystal, fortran, d, jvm} cohort siblings. Drift = parity fail.
#'
#' @docType package
#' @name limitless
#' @keywords internal
"_PACKAGE"
