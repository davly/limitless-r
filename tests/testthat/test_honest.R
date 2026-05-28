# R143 LOUD-ONCE-WARNING-FLAG primitive tests.

test_that("LOUD_ONCE_PREFIX is byte-identical across cohort", {
  expect_identical(LOUD_ONCE_PREFIX, "[LOUD-ONCE-WARNING]")
})

test_that("SEVERITY_LADDER is the closed 4-value cohort vocab", {
  expect_identical(SEVERITY_LADDER, c("INFO", "WARN", "ERROR", "CRITICAL"))
})

test_that("severity_rank returns expected integer ranks", {
  expect_identical(severity_rank("INFO"), 0L)
  expect_identical(severity_rank("WARN"), 1L)
  expect_identical(severity_rank("ERROR"), 2L)
  expect_identical(severity_rank("CRITICAL"), 3L)
  expect_identical(severity_rank("UNKNOWN"), -1L)
})

test_that("severity_label validates membership", {
  expect_identical(severity_label("WARN"), "WARN")
  expect_error(severity_label("BOGUS"), "unknown severity")
})

test_that("advisory constructor validates required fields", {
  adv <- advisory("CODE_A", "WARN", "msg", "docs/a.md")
  expect_s3_class(adv, "limitless_advisory")
  expect_identical(adv$code, "CODE_A")
  expect_identical(adv$severity, "WARN")
  expect_error(advisory("", "WARN", "msg", "docs"), "non-empty")
  expect_error(advisory("CODE_B", "NOPE", "msg", "docs"), "closed-set")
})

test_that("loud_once emits on first call and is silent on repeat", {
  loud_once_reset()
  adv <- advisory("CODE_FIRST", "WARN", "first test msg", "docs/test.md")
  # Capture stderr via a temp file connection.
  con <- file(tempfile(), open = "w+")
  on.exit(close(con), add = TRUE)
  expect_true(loud_once(adv, con = con))
  expect_false(loud_once(adv, con = con))
  # Cardinality is 1 after one distinct code.
  expect_equal(loud_once_cardinality(), 1L)
  expect_true(loud_once_has_emitted("CODE_FIRST"))
  expect_false(loud_once_has_emitted("CODE_NEVER"))
})

test_that("loud_once_reset re-arms the registry", {
  loud_once_reset()
  adv <- advisory("CODE_RESET", "INFO", "msg", "docs")
  con <- file(tempfile(), open = "w+")
  on.exit(close(con), add = TRUE)
  expect_true(loud_once(adv, con = con))
  expect_false(loud_once(adv, con = con))
  loud_once_reset()
  expect_true(loud_once(adv, con = con))
  expect_equal(loud_once_cardinality(), 1L)
})

test_that("loud_once_emit_all returns fresh-count, dedupes seen codes", {
  loud_once_reset()
  con <- file(tempfile(), open = "w+")
  on.exit(close(con), add = TRUE)
  advs <- list(
    advisory("A", "INFO", "a", "d"),
    advisory("B", "WARN", "b", "d"),
    advisory("A", "INFO", "a again", "d"),  # dup code, should be skipped
    advisory("C", "ERROR", "c", "d")
  )
  expect_equal(loud_once_emit_all(advs, con = con), 3L)
  expect_equal(loud_once_cardinality(), 3L)
})

test_that("loud_once_set_host_prefix overrides the line prefix", {
  loud_once_reset()
  loud_once_set_host_prefix("folio")
  tmp <- tempfile()
  con <- file(tmp, open = "w+")
  loud_once(advisory("HOST_CODE", "WARN", "msg", "d"), con = con)
  close(con)
  lines <- readLines(tmp)
  expect_true(any(grepl("^folio \\[LOUD-ONCE-WARNING\\] WARN HOST_CODE:", lines)))
  loud_once_reset()
})

test_that("loud_once rejects non-advisory inputs", {
  expect_error(loud_once(list(code = "X")), "must be a limitless_advisory")
})
