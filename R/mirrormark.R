#' limitless::mirrormark -- L43 Mirror-Mark v1 stamping (cohort-canonical R SDK).
#'
#' R 4.0+ port of the L43 Mirror-Mark v1 HMAC-SHA256-over-canonical-bytes
#' algorithm shipped across the Go cohort (pulse / baseline / foundry / oracle /
#' iris / nexus / folio) + the lore-mark-verify CLI (stdlib Go) +
#' foundation/pkg/mirrormark (canonical Go package) + the Python / C++ / .NET /
#' Solidity / Rust / Erlang/OTP / C99 / Gleam / Racket / Idris / Fortran /
#' Crystal / D cohort siblings.
#'
#' Mark format:
#'     "lore@v1:" + base64url(corpusSHA[0..7] + HMAC-SHA256(0x01 + corpusSHA + payload, key))
#'
#' R151 KAT-1 anchor:
#'     239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca
#'
#' Reproducible offline (no R toolchain involved):
#'
#'     printf '\x01' > /tmp/kat1.bin
#'     printf '\x00%.0s' {1..32} >> /tmp/kat1.bin
#'     openssl dgst -sha256 -mac hmac -macopt key: /tmp/kat1.bin
#'
#' R-rule alignment:
#'   - R151 KAT-AS-COHORT-INVARIANT-CROSS-SUBSTRATE-PIN -- KAT-1 hex anchor
#'   - R143 LOUD-ONCE-WARNING-FLAG                      -- placeholder warning hooks
#'   - R145.B SIBLING-NOT-STACKED                       -- pure primitive
#'   - R157 SUBSTRATE-NATIVE-IDIOM-OVER-LITERAL-TRANSLATION -- R raw vectors + environments
#'
#' Single external dependency: openssl (CRAN package; wraps libcrypto).

# ---------------------------------------------------------------------------
# Cohort-canonical constants (R151 KAT-1 cross-substrate pin)
# ---------------------------------------------------------------------------

#' L43 Mirror-Mark v1 version tag (1 byte, prepended to HMAC input).
#' @export
MARK_VERSION <- as.raw(0x01)

#' Mirror-Mark v1 header-value prefix. Byte-identical to
#' foundation/pkg/mirrormark.MarkPrefix.
#' @export
MARK_PREFIX <- "lore@v1:"

#' Corpus-SHA prefix length embedded in the mark body.
#' @export
MARK_CORPUS_PREFIX_LEN <- 8L

#' SHA-256 digest size in bytes.
#' @export
SHA256_DIGEST_LEN <- 32L

#' Unencoded mark body length (8 bytes corpusSHA prefix + 32 bytes HMAC).
#' @export
MARK_BODY_LEN <- MARK_CORPUS_PREFIX_LEN + SHA256_DIGEST_LEN

# ---------------------------------------------------------------------------
# R151 KAT-1 anchor (cohort cross-substrate firewall)
# ---------------------------------------------------------------------------

#' KAT-1 HMAC-SHA256 digest, hex-encoded. THIS IS THE COHORT CROSS-SUBSTRATE
#' FIREWALL: byte-identical to foundation/pkg/mirrormark.KAT1Digest +
#' pulse/baseline/foundry/oracle/iris cohort + every substrate adopter.
#'
#' Reproducible offline via OpenSSL (recipe in module header).
#' @export
KAT1_DIGEST_HEX <- "239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca"

#' KAT-1 mark string. Byte-identical to foundation/pkg/mirrormark.KAT1Mark.
#' @export
KAT1_MARK <- "lore@v1:AAAAAAAAAAAjmn0NPxu-Opiu3gHirYGMLbYLcXfALi8BUDWytbfbyg"

#' KAT-1 canonical input bytes: 0x01 followed by 32 x 0x00 (33 bytes total).
#'
#' @return A `raw` vector of length 33.
#' @export
kat1_input <- function() {
  buf <- raw(33)
  buf[1] <- as.raw(0x01)
  buf
}

# ---------------------------------------------------------------------------
# Internal: hex encode / decode
# ---------------------------------------------------------------------------

#' Lowercase hex-encode a raw vector with no separator.
#' @param data A `raw` vector.
#' @return Hex-encoded string.
#' @export
bytes_to_hex <- function(data) {
  if (!is.raw(data)) stop("bytes_to_hex: input must be raw vector")
  paste0(as.character(data), collapse = "")
}

#' Hex-decode a lowercase hex string to a raw vector.
#' @param hex A character scalar of even length, characters 0-9a-fA-F only.
#' @return A `raw` vector.
#' @export
hex_to_bytes <- function(hex) {
  if (!is.character(hex) || length(hex) != 1L) stop("hex_to_bytes: input must be a single string")
  if (nchar(hex) %% 2L != 0L) stop(sprintf("hex_to_bytes: odd-length input (%d)", nchar(hex)))
  if (!grepl("^[0-9a-fA-F]*$", hex)) stop("hex_to_bytes: invalid hex character in input")
  if (nchar(hex) == 0L) return(raw(0L))
  pairs <- substring(hex, seq(1L, nchar(hex), 2L), seq(2L, nchar(hex), 2L))
  as.raw(strtoi(pairs, base = 16L))
}

# ---------------------------------------------------------------------------
# Internal: base64url encode / decode (RFC 4648 unpadded)
# ---------------------------------------------------------------------------

#' Base64url-encode (RFC 4648 section 5, no padding) a raw vector.
#' @param data A `raw` vector.
#' @return Encoded character scalar.
#' @export
base64url_encode <- function(data) {
  if (!is.raw(data)) stop("base64url_encode: input must be raw vector")
  if (length(data) == 0L) return("")
  std <- openssl::base64_encode(data)
  # Convert std -> url: '+' -> '-', '/' -> '_', strip '=' padding.
  out <- gsub("=+$", "", std)
  out <- chartr("+/", "-_", out)
  out
}

#' Base64url-decode (RFC 4648 section 5) a character scalar to raw.
#' Returns NULL on malformed input.
#'
#' Strict alphabet: only `[A-Za-z0-9_-]` are accepted (RFC 4648 section 5,
#' unpadded). Any other character -- including whitespace, embedded newlines,
#' `'='` padding, or std-base64 `'+' / '/'` -- yields NULL. This is a security
#' boundary, not a nicety: `openssl::base64_decode` silently *ignores*
#' characters outside the base64 alphabet (OpenSSL's PEM-heritage decoder
#' skips newlines/whitespace), so without this guard a peer could submit a
#' non-canonical mark string (e.g. with an embedded `\n`) that decodes to the
#' SAME 40-byte body and PASSES `mm_verify`, breaking the cohort
#' "byte-identical mark" invariant. Mirrors the alphabet check that
#' `hex_to_bytes()` already enforces.
#' @param s Encoded character scalar.
#' @return A `raw` vector, or NULL on invalid input.
#' @export
base64url_decode <- function(s) {
  if (!is.character(s) || length(s) != 1L) return(NULL)
  if (nchar(s) == 0L) return(raw(0L))
  # Reject any character outside the RFC 4648 section 5 base64url alphabet
  # BEFORE decoding. openssl::base64_decode tolerates (skips) stray bytes,
  # which would let a malleable/non-canonical mark verify true.
  if (!grepl("^[A-Za-z0-9_-]*$", s)) return(NULL)
  # Convert url -> std: '-' -> '+', '_' -> '/'. Re-pad to multiple of 4.
  std <- chartr("-_", "+/", s)
  pad_needed <- (4L - (nchar(std) %% 4L)) %% 4L
  if (pad_needed == 3L) return(NULL)  # invalid base64 length
  std <- paste0(std, strrep("=", pad_needed))
  out <- tryCatch(openssl::base64_decode(std), error = function(e) NULL)
  if (is.null(out)) return(NULL)
  out
}

# ---------------------------------------------------------------------------
# Internal: HMAC-SHA256
# ---------------------------------------------------------------------------

# `openssl::sha256(data, key=)` computes HMAC-SHA256 when key is supplied.
# Returns a raw vector with class c("hash", "sha256", "hmac"). We strip the
# class with unclass() to get a bare raw vector for downstream concatenation
# + base64url encoding.
.hmac_sha256 <- function(key, data) {
  if (!is.raw(key)) stop(".hmac_sha256: key must be raw")
  if (!is.raw(data)) stop(".hmac_sha256: data must be raw")
  h <- openssl::sha256(data, key = key)
  # unclass() returns the underlying raw vector without class attributes.
  unclass(h)
}

# ---------------------------------------------------------------------------
# Internal: constant-time equal
# ---------------------------------------------------------------------------

.constant_time_equal <- function(a, b) {
  if (!is.raw(a) || !is.raw(b)) return(FALSE)
  if (length(a) != length(b)) return(FALSE)
  if (length(a) == 0L) return(TRUE)
  # Vectorised: xor() on raw vectors returns element-wise bitwise XOR.
  # Reduce by bitwise OR; result is raw(0x00) iff every byte matched.
  diffs <- xor(a, b)
  identical(Reduce(`|`, diffs, accumulate = FALSE), as.raw(0L))
}

# ---------------------------------------------------------------------------
# Internal: build canonical HMAC input
# ---------------------------------------------------------------------------

.build_hmac_input <- function(corpus_sha, payload) {
  if (!is.raw(corpus_sha)) stop("corpus_sha must be raw")
  if (!is.raw(payload)) stop("payload must be raw")
  if (length(corpus_sha) != SHA256_DIGEST_LEN) {
    stop(sprintf("mirrormark: corpus_sha must be %d bytes, got %d",
                 SHA256_DIGEST_LEN, length(corpus_sha)))
  }
  c(MARK_VERSION, corpus_sha, payload)
}

.assemble_mark <- function(corpus_sha, digest) {
  if (length(digest) != SHA256_DIGEST_LEN) {
    stop(sprintf("digest length must be %d, got %d", SHA256_DIGEST_LEN, length(digest)))
  }
  body <- c(corpus_sha[seq_len(MARK_CORPUS_PREFIX_LEN)], digest)
  paste0(MARK_PREFIX, base64url_encode(body))
}

# ---------------------------------------------------------------------------
# Public API: sign / verify
# ---------------------------------------------------------------------------

#' Compute the canonical Mirror-Mark v1 string.
#'
#' Mark format:
#'     "lore@v1:" + base64url(corpusSHA[0..7] + HMAC-SHA256(0x01 + corpusSHA + payload, key))
#'
#' Pure function. Safe to call from a cold-verify regulator binary holding
#' only (corpus_sha, payload, key).
#'
#' @param corpus_sha 32-byte raw vector: SHA-256 of the lore-corpus snapshot.
#' @param payload Raw vector: the bytes being attested.
#' @param key Raw vector: HMAC key (may be zero-length for KAT-1 vectors).
#' @return Character scalar: the canonical mark string.
#' @export
mm_sign <- function(corpus_sha, payload, key) {
  input <- .build_hmac_input(corpus_sha, payload)
  digest <- .hmac_sha256(key, input)
  .assemble_mark(corpus_sha, digest)
}

#' Verify a Mirror-Mark v1 string against (corpus_sha, payload, key).
#'
#' Returns invisibly on match; calls `stop()` on any failure with a stable
#' message prefix `"mirrormark: ..."` so callers can `tryCatch()` on it.
#'
#' @param mark Character scalar: the mark to verify.
#' @param corpus_sha 32-byte raw vector.
#' @param payload Raw vector.
#' @param key Raw vector.
#' @return invisible(TRUE) on match.
#' @export
mm_verify <- function(mark, corpus_sha, payload, key) {
  if (!is.character(mark) || length(mark) != 1L) {
    stop("mirrormark: mark must be a single string")
  }
  if (!is.raw(corpus_sha) || length(corpus_sha) != SHA256_DIGEST_LEN) {
    stop(sprintf("mirrormark: corpus_sha must be %d bytes, got %d",
                 SHA256_DIGEST_LEN,
                 if (is.raw(corpus_sha)) length(corpus_sha) else NA))
  }
  if (!startsWith(mark, MARK_PREFIX)) {
    stop("mirrormark: unknown mark version (missing 'lore@v1:' prefix)")
  }
  body_b64 <- substr(mark, nchar(MARK_PREFIX) + 1L, nchar(mark))
  body <- base64url_decode(body_b64)
  if (is.null(body)) {
    stop("mirrormark: malformed mark (base64url decode failed)")
  }
  if (length(body) != MARK_BODY_LEN) {
    stop(sprintf("mirrormark: malformed mark (body wrong length: got %d, want %d)",
                 length(body), MARK_BODY_LEN))
  }
  embedded_corpus <- body[seq_len(MARK_CORPUS_PREFIX_LEN)]
  embedded_digest <- body[(MARK_CORPUS_PREFIX_LEN + 1L):MARK_BODY_LEN]
  if (!.constant_time_equal(embedded_corpus, corpus_sha[seq_len(MARK_CORPUS_PREFIX_LEN)])) {
    stop("mirrormark: corpus prefix mismatch (mark signed by different corpus)")
  }
  expected_digest <- .hmac_sha256(key, .build_hmac_input(corpus_sha, payload))
  if (!.constant_time_equal(embedded_digest, expected_digest)) {
    stop("mirrormark: HMAC signature mismatch (payload tampered or wrong key)")
  }
  invisible(TRUE)
}

#' Boolean form of mm_verify. Returns TRUE iff the mark matches.
#' @inheritParams mm_verify
#' @return Logical scalar.
#' @export
mm_verify_bool <- function(mark, corpus_sha, payload, key) {
  tryCatch({
    mm_verify(mark, corpus_sha, payload, key)
    TRUE
  }, error = function(e) FALSE)
}

# ---------------------------------------------------------------------------
# Marker class (placeholder-tracking + LoudOnce surface)
# ---------------------------------------------------------------------------

.all_zero <- function(buf) {
  if (length(buf) == 0L) return(TRUE)
  all(buf == as.raw(0L))
}

#' Construct a long-lived Mirror-Mark signer.
#'
#' Stores (corpus_sha, key) immutably (R semantics: function closure over
#' defensively-copied raw vectors). Calling `mm_marker_mark(marker, payload)`
#' returns a canonical mark; `mm_marker_verify(marker, mark, payload)` runs
#' the verify path; placeholder-corpus or placeholder-key triggers a single
#' stderr WARNING on first use (LoudOnce-style).
#'
#' Refuses an empty key at construction time to keep production paths
#' fail-closed against accidental key-loss. KAT-1 vectors (empty key) must
#' use the module-level `mm_sign` directly.
#'
#' @param corpus_sha 32-byte raw vector.
#' @param key Raw vector (must be non-empty).
#' @param on_warn Optional function(placeholder_corpus, placeholder_key); if
#'   NULL the default stderr emission is used.
#' @return An environment with class "limitless_marker".
#' @export
mm_marker <- function(corpus_sha, key, on_warn = NULL) {
  if (!is.raw(corpus_sha) || length(corpus_sha) != SHA256_DIGEST_LEN) {
    stop(sprintf("mirrormark: corpus_sha must be %d bytes", SHA256_DIGEST_LEN))
  }
  if (!is.raw(key)) stop("mirrormark: key must be raw")
  if (length(key) == 0L) {
    stop("mirrormark: Marker refuses empty HMAC key; use mm_sign() for KAT-1 vectors")
  }
  env <- new.env(parent = emptyenv())
  env$corpus_sha <- corpus_sha            # defensive: R-passes-by-value semantics
  env$key <- key
  env$using_placeholder_corpus <- .all_zero(corpus_sha)
  env$using_placeholder_key <- .all_zero(key)
  env$warned_once <- FALSE
  env$on_warn <- on_warn
  class(env) <- "limitless_marker"
  env
}

.marker_maybe_warn <- function(m) {
  if (m$warned_once) return(invisible(NULL))
  if (!m$using_placeholder_corpus && !m$using_placeholder_key) return(invisible(NULL))
  m$warned_once <- TRUE
  if (!is.null(m$on_warn)) {
    m$on_warn(m$using_placeholder_corpus, m$using_placeholder_key)
    return(invisible(NULL))
  }
  parts <- character(0)
  if (m$using_placeholder_corpus) parts <- c(parts, "corpus")
  if (m$using_placeholder_key) parts <- c(parts, "key")
  msg <- sprintf(paste0("mirrormark: WARNING -- signing with placeholder %s; ",
                        "emitted marks will NOT pass cold-verify against a real ",
                        "lore corpus / production key\n"),
                 paste(parts, collapse = " "))
  cat(msg, file = stderr())
  invisible(NULL)
}

#' Compute a mark using a long-lived marker.
#' @param marker A `limitless_marker` object from `mm_marker`.
#' @param payload Raw vector.
#' @return Character scalar mark.
#' @export
mm_marker_mark <- function(marker, payload) {
  if (!inherits(marker, "limitless_marker")) stop("mm_marker_mark: marker must be a limitless_marker")
  .marker_maybe_warn(marker)
  mm_sign(marker$corpus_sha, payload, marker$key)
}

#' Verify a mark using a long-lived marker.
#' @param marker A `limitless_marker` object from `mm_marker`.
#' @param payload Raw vector.
#' @param mark_str Character scalar mark to verify.
#' @return invisible(TRUE) on match; stops on failure.
#' @export
mm_marker_verify <- function(marker, payload, mark_str) {
  if (!inherits(marker, "limitless_marker")) stop("mm_marker_verify: marker must be a limitless_marker")
  mm_verify(mark_str, marker$corpus_sha, payload, marker$key)
}

#' Returns the (placeholder_corpus, placeholder_key) pair for a marker.
#' @param marker A `limitless_marker` object.
#' @return A named logical vector: c(corpus = ..., key = ...).
#' @export
mm_marker_using_placeholders <- function(marker) {
  if (!inherits(marker, "limitless_marker")) stop("mm_marker_using_placeholders: marker must be a limitless_marker")
  c(corpus = marker$using_placeholder_corpus, key = marker$using_placeholder_key)
}

# ---------------------------------------------------------------------------
# KAT-1 self-test (R151 cohort firewall)
# ---------------------------------------------------------------------------

#' Verify the KAT-1 anchor reproduces. Stops on drift.
#'
#' Callable from a host's boot phase as a startup parity assertion. Any drift
#' in the HMAC-SHA256 or base64url implementation surfaces here, not at the
#' next cross-substrate verification round-trip.
#' @return invisible(TRUE) on match; stops with drift detail on mismatch.
#' @export
assert_kat1_parity <- function() {
  digest <- .hmac_sha256(raw(0L), kat1_input())
  hex <- bytes_to_hex(digest)
  if (!identical(hex, KAT1_DIGEST_HEX)) {
    stop(sprintf(paste0("L43 Mirror-Mark KAT-1 drift detected: got %s, expected %s. ",
                        "This breaks cohort parity with pulse / baseline / foundry / oracle / iris."),
                 hex, KAT1_DIGEST_HEX))
  }
  invisible(TRUE)
}
