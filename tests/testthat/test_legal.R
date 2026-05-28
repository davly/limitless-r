# R166 LIABILITY-FOOTER-CONST + UK GDPR refs + Legal Page projection tests.

test_that("DEFAULT_PLACEHOLDER_ALERT is non-empty and starts 'IMPORTANT:'", {
  expect_true(nzchar(DEFAULT_PLACEHOLDER_ALERT))
  expect_true(startsWith(DEFAULT_PLACEHOLDER_ALERT, "IMPORTANT:"))
})

test_that("DEFAULT_REVIEWED_BY_COUNSEL is the honest-default FALSE", {
  expect_identical(DEFAULT_REVIEWED_BY_COUNSEL, FALSE)
})

test_that("UK GDPR ref strings are byte-aligned with cohort canonical", {
  expect_identical(REF_UK_GDPR_ARTICLE_9, "UK GDPR Article 9")
  expect_identical(REF_UK_GDPR_ARTICLE_13, "UK GDPR Article 13")
  expect_identical(REF_UK_GDPR_ARTICLE_14, "UK GDPR Article 14")
  expect_identical(REF_UK_GDPR_ARTICLE_15, "UK GDPR Article 15")
  expect_identical(REF_UK_GDPR_ARTICLE_16, "UK GDPR Article 16")
  expect_identical(REF_UK_GDPR_ARTICLE_17, "UK GDPR Article 17")
  expect_identical(REF_FSMA_2000_SECTION_19, "FSMA 2000 s19")
})

test_that("ICO_COMPLAINT_NOTICE + FCA_NOT_AUTHORISED_DISCLAIMER non-empty", {
  expect_true(nzchar(ICO_COMPLAINT_NOTICE))
  expect_true(nzchar(FCA_NOT_AUTHORISED_DISCLAIMER))
  expect_true(grepl("ICO", ICO_COMPLAINT_NOTICE))
  expect_true(grepl("FSMA 2000", FCA_NOT_AUTHORISED_DISCLAIMER))
})

test_that("ALL_DOCUMENT_IDS contains the 5 cohort slugs", {
  expect_setequal(
    ALL_DOCUMENT_IDS,
    c("terms", "privacy", "cookies", "gdpr", "community-guidelines")
  )
})

test_that("valid_document_id accepts canonical slugs + rejects others", {
  expect_true(valid_document_id("terms"))
  expect_true(valid_document_id("privacy"))
  expect_true(valid_document_id("cookies"))
  expect_true(valid_document_id("gdpr"))
  expect_true(valid_document_id("community-guidelines"))
  expect_false(valid_document_id("bogus-slug"))
  expect_false(valid_document_id(""))
  expect_false(valid_document_id(NA_character_))
})

test_that("legal_config_placeholder is configured-positive", {
  cfg <- legal_config_placeholder()
  expect_s3_class(cfg, "legal_config")
  expect_true(legal_config_configured(cfg))
})

test_that("legal_config_configured FALSE for empty config", {
  cfg <- legal_config(
    operator_name = "", registered_office_address = "",
    ico_registration_number = "", dpo_email = "", contact_email = "",
    jurisdiction = "", service_name = ""
  )
  expect_false(legal_config_configured(cfg))
})

test_that("compute_body_hash matches a known SHA-256 vector", {
  # SHA-256("") = e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855
  expect_identical(
    compute_body_hash(""),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
  )
  # SHA-256("abc") = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
  expect_identical(
    compute_body_hash("abc"),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
  )
})

test_that("new_page populates body_hash + fetched_at + accepts only valid slug", {
  cfg <- legal_config_placeholder()
  page <- new_page("terms", "Terms of Service", "v1", "2026-05-28",
                   "Body text here.", FALSE, cfg)
  expect_s3_class(page, "legal_page")
  expect_identical(page$id, "terms")
  expect_identical(page$slug, "terms")
  expect_identical(page$reviewed_by_counsel, FALSE)
  expect_identical(page$body_hash, compute_body_hash("Body text here."))
  expect_true(nzchar(page$fetched_at))
  expect_error(new_page("bogus", "T", "v1", "2026-05-28", "b", FALSE, cfg),
               "not in closed-set")
})

test_that("body_with_placeholder_alert prepends DEFAULT_PLACEHOLDER_ALERT when un-reviewed", {
  cfg <- legal_config_placeholder()
  page <- new_page("terms", "Terms", "v1", "2026-05-28", "body", FALSE, cfg)
  out <- body_with_placeholder_alert(page)
  expect_true(startsWith(out, DEFAULT_PLACEHOLDER_ALERT))
  expect_true(grepl("body", out, fixed = TRUE))
})

test_that("body_with_placeholder_alert returns body unchanged when reviewed", {
  cfg <- legal_config_placeholder()
  page <- new_page("terms", "Terms", "v1", "2026-05-28", "body", TRUE, cfg)
  expect_identical(body_with_placeholder_alert(page), "body")
})

test_that("body_with_placeholder_alert is idempotent on already-prefixed body", {
  cfg <- legal_config_placeholder()
  prefixed_body <- paste0(DEFAULT_PLACEHOLDER_ALERT, "\n\nactual body")
  page <- new_page("terms", "T", "v1", "2026-05-28", prefixed_body, FALSE, cfg)
  expect_identical(body_with_placeholder_alert(page), prefixed_body)
})

test_that("page_as_index_entry projects the slim fields", {
  cfg <- legal_config_placeholder()
  page <- new_page("privacy", "Privacy Policy", "v2", "2026-06-01",
                   "...", FALSE, cfg)
  entry <- page_as_index_entry(page)
  expect_s3_class(entry, "legal_index_entry")
  expect_identical(entry$id, "privacy")
  expect_identical(entry$version, "v2")
  expect_identical(entry$reviewed_by_counsel, FALSE)
})

test_that("render_baseline includes title + version + effective_date + body", {
  cfg <- legal_config_placeholder()
  page <- new_page("terms", "Terms of Service", "v1", "2026-05-28",
                   "Body text.", FALSE, cfg)
  rendered <- render_baseline(page)
  expect_true(grepl("Terms of Service", rendered, fixed = TRUE))
  expect_true(grepl("Version: v1", rendered, fixed = TRUE))
  expect_true(grepl("Effective: 2026-05-28", rendered, fixed = TRUE))
  expect_true(grepl("Body text.", rendered, fixed = TRUE))
})

test_that("acceptance_key uses cohort-canonical pipe-delimited format", {
  expect_identical(acceptance_key("user-1", "terms", "v1"), "user-1|terms|v1")
  expect_error(acceptance_key("a", "b", c("v1", "v2")), "single strings")
})
