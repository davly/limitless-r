# R151 KAT-1 cross-substrate firewall + L43 Mirror-Mark sign/verify tests.
#
# Cohort canonical KAT-1 anchor (byte-identical across every cohort substrate):
#   239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca
# Reproducible offline via:
#   printf '\x01' > /tmp/kat1.bin; printf '\x00%.0s' {1..32} >> /tmp/kat1.bin
#   openssl dgst -sha256 -mac hmac -macopt key: /tmp/kat1.bin

# --- KAT-1 cohort cross-substrate firewall (R151) ---

test_that("KAT1_DIGEST_HEX literal is the cohort firewall pin", {
  expect_identical(
    KAT1_DIGEST_HEX,
    "239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca"
  )
})

test_that("KAT1_MARK is byte-identical across cohort", {
  expect_identical(
    KAT1_MARK,
    "lore@v1:AAAAAAAAAAAjmn0NPxu-Opiu3gHirYGMLbYLcXfALi8BUDWytbfbyg"
  )
})

test_that("kat1_input returns 33 bytes with leading 0x01", {
  buf <- kat1_input()
  expect_true(is.raw(buf))
  expect_equal(length(buf), 33L)
  expect_identical(buf[1], as.raw(0x01))
  expect_true(all(buf[2:33] == as.raw(0L)))
})

test_that("assert_kat1_parity does not stop (cohort firewall holds)", {
  expect_silent(assert_kat1_parity())
})

test_that("kat1_compute reproduces KAT1_DIGEST_HEX", {
  expect_identical(kat1_compute(), KAT1_DIGEST_HEX)
})

test_that("mm_sign with KAT-1 inputs reproduces KAT1_MARK", {
  corpus <- raw(32)         # 32 zero bytes
  payload <- raw(0L)
  key <- raw(0L)
  expect_identical(mm_sign(corpus, payload, key), KAT1_MARK)
})

test_that("mm_verify accepts KAT1_MARK with KAT-1 inputs", {
  corpus <- raw(32)
  expect_silent(mm_verify(KAT1_MARK, corpus, raw(0L), raw(0L)))
})

test_that("mm_verify_bool returns TRUE for KAT-1 round-trip", {
  corpus <- raw(32)
  expect_true(mm_verify_bool(KAT1_MARK, corpus, raw(0L), raw(0L)))
})

# --- sign + verify round-trip ---

test_that("mm_sign + mm_verify round-trip with non-zero corpus + payload + key", {
  corpus <- as.raw(seq.int(1L, 32L))
  payload <- charToRaw("hello world")
  key <- charToRaw("my-secret-key")
  mark <- mm_sign(corpus, payload, key)
  expect_silent(mm_verify(mark, corpus, payload, key))
  expect_true(mm_verify_bool(mark, corpus, payload, key))
})

test_that("mm_verify rejects tampered payload", {
  corpus <- as.raw(seq.int(0L, 31L))
  mark <- mm_sign(corpus, charToRaw("original"), charToRaw("k"))
  expect_error(
    mm_verify(mark, corpus, charToRaw("tampered"), charToRaw("k")),
    "HMAC signature mismatch"
  )
  expect_false(mm_verify_bool(mark, corpus, charToRaw("tampered"), charToRaw("k")))
})

test_that("mm_verify rejects wrong key", {
  corpus <- raw(32)
  mark <- mm_sign(corpus, charToRaw("data"), charToRaw("key1"))
  expect_error(
    mm_verify(mark, corpus, charToRaw("data"), charToRaw("key2")),
    "HMAC signature mismatch"
  )
})

test_that("mm_verify rejects wrong corpus", {
  corpus1 <- as.raw(seq.int(0L, 31L))
  corpus2 <- as.raw(seq.int(100L, 131L))
  mark <- mm_sign(corpus1, charToRaw("x"), charToRaw("k"))
  expect_error(
    mm_verify(mark, corpus2, charToRaw("x"), charToRaw("k")),
    "corpus prefix mismatch"
  )
})

test_that("mm_verify rejects mark missing 'lore@v1:' prefix", {
  corpus <- raw(32)
  expect_error(
    mm_verify("not-a-mark", corpus, raw(0L), raw(0L)),
    "unknown mark version"
  )
})

test_that("mm_sign rejects wrong-length corpus", {
  expect_error(mm_sign(raw(31L), raw(0L), raw(0L)), "must be 32 bytes")
  expect_error(mm_sign(raw(33L), raw(0L), raw(0L)), "must be 32 bytes")
})

# --- hex + base64url helpers ---

test_that("bytes_to_hex + hex_to_bytes round-trip", {
  data <- as.raw(c(0x00, 0x01, 0x10, 0xff, 0xab, 0xcd))
  hex <- bytes_to_hex(data)
  # as.character(raw) in R is lowercase 2-digit hex; 6 bytes -> 12 chars.
  expect_equal(nchar(hex), 12L)
  expect_identical(hex, "000110ffabcd")
  expect_identical(hex_to_bytes(hex), data)
})

test_that("base64url_encode + base64url_decode round-trip on KAT-1 body", {
  body <- c(raw(8L), .hmac_sha256(raw(0L), kat1_input()))
  encoded <- base64url_encode(body)
  expect_identical(encoded, "AAAAAAAAAAAjmn0NPxu-Opiu3gHirYGMLbYLcXfALi8BUDWytbfbyg")
  decoded <- base64url_decode(encoded)
  expect_identical(decoded, body)
})

test_that("base64url_decode returns NULL on invalid input", {
  expect_null(base64url_decode("====="))  # remainder 1 => invalid
})

test_that("base64url_decode rejects out-of-alphabet characters (no openssl skip)", {
  # OpenSSL's base64 decoder silently ignores whitespace/newlines; the strict
  # alphabet guard must reject them so a malleable mark cannot decode to a
  # canonical body. '+' and '/' are std-base64, not url-safe -> also rejected.
  expect_null(base64url_decode("AAAA\nAAAA"))
  expect_null(base64url_decode("AAAA AAAA"))
  expect_null(base64url_decode("AB+/"))
  expect_null(base64url_decode("AB=="))   # '=' padding is not part of the unpadded alphabet
})

test_that("mm_verify rejects a non-canonical mark with embedded whitespace (malleability)", {
  corpus <- raw(32)
  # Splice a newline into the canonical KAT-1 body; without the alphabet guard
  # openssl would skip the '\n' and the tampered string would verify TRUE.
  body_b64 <- substr(KAT1_MARK, nchar(MARK_PREFIX) + 1L, nchar(KAT1_MARK))
  tampered <- paste0(MARK_PREFIX, substr(body_b64, 1L, 10L), "\n",
                     substr(body_b64, 11L, nchar(body_b64)))
  expect_error(mm_verify(tampered, corpus, raw(0L), raw(0L)),
               "malformed mark")
  expect_false(mm_verify_bool(tampered, corpus, raw(0L), raw(0L)))
})

# --- Marker class ---

test_that("mm_marker constructs + signs/verifies", {
  corpus <- as.raw(seq.int(1L, 32L))
  key <- charToRaw("real-key")
  m <- mm_marker(corpus, key)
  mark <- mm_marker_mark(m, charToRaw("payload"))
  expect_silent(mm_marker_verify(m, charToRaw("payload"), mark))
})

test_that("mm_marker refuses empty key", {
  expect_error(mm_marker(raw(32L), raw(0L)), "refuses empty HMAC key")
})

test_that("mm_marker_using_placeholders flags all-zero corpus + key", {
  m <- mm_marker(raw(32L), charToRaw("k"), on_warn = function(c, k) invisible(NULL))
  ph <- mm_marker_using_placeholders(m)
  expect_true(ph["corpus"])
  expect_false(ph["key"])
})
