# R151 KAT-AS-COHORT-INVARIANT-CROSS-SUBSTRATE-PIN dedicated test file.
#
# A second-level firewall: even if mirrormark tests are removed or refactored,
# this file MUST continue to reproduce the cohort canonical hex.

test_that("assert_kat1_parity is silent (cohort firewall holds)", {
  expect_silent(assert_kat1_parity())
})

test_that("kat1_compute returns the cohort-canonical hex literal", {
  expect_identical(
    kat1_compute(),
    "239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca"
  )
})

test_that("KAT1_DIGEST_HEX literal is exactly 64 lowercase hex chars", {
  expect_equal(nchar(KAT1_DIGEST_HEX), 64L)
  expect_true(grepl("^[0-9a-f]{64}$", KAT1_DIGEST_HEX))
})

test_that("kat1_input is exactly 0x01 followed by 32 zero bytes", {
  buf <- kat1_input()
  expect_equal(length(buf), 33L)
  expect_identical(buf[1], as.raw(0x01))
  for (i in 2:33) expect_identical(buf[i], as.raw(0x00))
})

test_that("KAT1_MARK base64url-decodes to 40 bytes (8 corpus prefix + 32 HMAC)", {
  body <- base64url_decode(substr(KAT1_MARK, nchar(MARK_PREFIX) + 1L, nchar(KAT1_MARK)))
  expect_equal(length(body), 40L)
  # First 8 bytes are the corpus prefix (all zero for KAT-1)
  expect_true(all(body[1:8] == as.raw(0L)))
  # Last 32 bytes are the HMAC digest -- should match KAT1_DIGEST_HEX
  expect_identical(bytes_to_hex(body[9:40]), KAT1_DIGEST_HEX)
})
