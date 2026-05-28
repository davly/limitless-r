#' limitless::legal -- UK GDPR + statutory cross-reference surface
#' (cohort-canonical R SDK).
#'
#' R 4.0+ port of foundation/legal/{refs.go, types.go, config.go, page.go}
#' (Go canonical) + the cohort siblings (Python / Crystal / Fortran / D / ...).
#'
#' R166 LIABILITY-FOOTER-CONST alignment:
#'   - `DEFAULT_PLACEHOLDER_ALERT` is the cohort-canonical liability-footer
#'     constant. Hosts that render un-reviewed legal documents MUST prepend
#'     this alert via `body_with_placeholder_alert()`.
#'   - `DEFAULT_REVIEWED_BY_COUNSEL = FALSE` is the cohort-canonical honest-
#'     default: every flagship's per-document reviewed-by-counsel constant
#'     SHOULD ship as FALSE until real legal review has happened.
#'
#' R-rule alignment:
#'   - R166 LIABILITY-FOOTER-CONST                          -- DEFAULT_PLACEHOLDER_ALERT
#'   - R154 ARTICLE-9-DSAR-AUDIT-CLASS-COHORT-EXTENSION     -- REF_UK_GDPR_ARTICLE_9
#'   - R150 PARALLEL-MAP-R144-REVIEW-METADATA               -- reviewed_by_counsel honest-default

# ---------------------------------------------------------------------------
# UK GDPR statutory references (cohort byte-aligned with foundation/legal/refs.go)
# ---------------------------------------------------------------------------

#' UK GDPR Article 9 (special category personal data).
#' @export
REF_UK_GDPR_ARTICLE_9 <- "UK GDPR Article 9"
#' UK GDPR Article 13 (information to be provided where data is collected from subject).
#' @export
REF_UK_GDPR_ARTICLE_13 <- "UK GDPR Article 13"
#' UK GDPR Article 14 (information where data is not collected from subject).
#' @export
REF_UK_GDPR_ARTICLE_14 <- "UK GDPR Article 14"
#' UK GDPR Article 15 (right of access).
#' @export
REF_UK_GDPR_ARTICLE_15 <- "UK GDPR Article 15"
#' UK GDPR Article 16 (right to rectification).
#' @export
REF_UK_GDPR_ARTICLE_16 <- "UK GDPR Article 16"
#' UK GDPR Article 17 (right to erasure / "right to be forgotten").
#' @export
REF_UK_GDPR_ARTICLE_17 <- "UK GDPR Article 17"

#' FSMA 2000 s19 (financial-promotion / regulated-activity general prohibition).
#' @export
REF_FSMA_2000_SECTION_19 <- "FSMA 2000 s19"

# ---------------------------------------------------------------------------
# Cohort-canonical legal text constants
# ---------------------------------------------------------------------------

#' R166 LIABILITY-FOOTER-CONST: honest-defaults LOUD banner emitted at the top
#' of any un-reviewed legal document. Byte-identical to the cohort canonical.
#' @export
DEFAULT_PLACEHOLDER_ALERT <- paste0(
  "IMPORTANT: This document is structured boilerplate and has not been ",
  "reviewed by qualified legal counsel. Do not rely on this text as a ",
  "substitute for a professionally-drafted document before processing ",
  "customer payments."
)

#' R150-aligned honest-default constant.
#' @export
DEFAULT_REVIEWED_BY_COUNSEL <- FALSE

#' Statutory notice of the ICO complaint right (UK GDPR Article 77).
#' @export
ICO_COMPLAINT_NOTICE <- paste0(
  "You have the right to lodge a complaint with the UK Information ",
  "Commissioner's Office (ICO) at any time. Visit ico.org.uk for contact ",
  "details."
)

#' FSMA 2000 s19 disclaimer for hosts shipping general personal-finance
#' information that is NOT regulated advice.
#' @export
FCA_NOT_AUTHORISED_DISCLAIMER <- paste0(
  "This service provides general personal-finance information only. It is NOT ",
  "regulated investment, mortgage, insurance, or pensions advice within the ",
  "meaning of FSMA 2000 s19. The operator is not authorised or regulated by ",
  "the Financial Conduct Authority. For regulated advice, consult an FCA-",
  "authorised independent financial adviser (see fca.org.uk/register)."
)

# ---------------------------------------------------------------------------
# DocumentID closed-set
# ---------------------------------------------------------------------------

#' Document slug for Terms of Service. @export
DOCUMENT_ID_TERMS <- "terms"
#' Document slug for Privacy Policy. @export
DOCUMENT_ID_PRIVACY <- "privacy"
#' Document slug for Cookies notice. @export
DOCUMENT_ID_COOKIES <- "cookies"
#' Document slug for GDPR statement. @export
DOCUMENT_ID_GDPR <- "gdpr"
#' Document slug for Community Guidelines. @export
DOCUMENT_ID_COMMUNITY_GUIDELINES <- "community-guidelines"

#' Cohort closed-set of valid document slugs.
#' @export
ALL_DOCUMENT_IDS <- c(
  DOCUMENT_ID_TERMS, DOCUMENT_ID_PRIVACY, DOCUMENT_ID_COOKIES,
  DOCUMENT_ID_GDPR, DOCUMENT_ID_COMMUNITY_GUIDELINES
)

#' Is `slug` one of the cohort-canonical document slugs?
#' @param slug Character scalar.
#' @return Logical scalar.
#' @export
valid_document_id <- function(slug) {
  if (!is.character(slug) || length(slug) != 1L) return(FALSE)
  slug %in% ALL_DOCUMENT_IDS
}

# ---------------------------------------------------------------------------
# LegalConfig (host-operator metadata)
# ---------------------------------------------------------------------------

#' Construct a host-operator LegalConfig.
#'
#' Fields are byte-aligned with foundation/legal/config.go.
#'
#' @param operator_name Trading name of the operator.
#' @param registered_office_address Registered office, single line.
#' @param ico_registration_number ICO registration number (e.g. "ZA000000").
#' @param dpo_email Data-protection-officer contact email.
#' @param contact_email General legal-contact email.
#' @param jurisdiction e.g. "England and Wales".
#' @param service_name Trading name of the service.
#' @param vat_number Optional VAT registration number.
#' @param company_number Optional Companies House number.
#' @return A list with class "legal_config".
#' @export
legal_config <- function(operator_name, registered_office_address,
                         ico_registration_number, dpo_email, contact_email,
                         jurisdiction, service_name,
                         vat_number = "", company_number = "") {
  obj <- list(
    operator_name = operator_name,
    registered_office_address = registered_office_address,
    ico_registration_number = ico_registration_number,
    dpo_email = dpo_email,
    contact_email = contact_email,
    jurisdiction = jurisdiction,
    service_name = service_name,
    vat_number = vat_number,
    company_number = company_number
  )
  class(obj) <- "legal_config"
  obj
}

#' Is the LegalConfig populated with the four cohort-required fields?
#'
#' Required: operator_name, registered_office_address, ico_registration_number,
#' contact_email. (vat_number / company_number / dpo_email may be empty.)
#' @param cfg A `legal_config` from `legal_config()`.
#' @return Logical scalar.
#' @export
legal_config_configured <- function(cfg) {
  if (!inherits(cfg, "legal_config")) return(FALSE)
  nzchar(cfg$operator_name) &&
    nzchar(cfg$registered_office_address) &&
    nzchar(cfg$ico_registration_number) &&
    nzchar(cfg$contact_email)
}

#' A LegalConfig populated with REPLACE-IN-PRODUCTION placeholders.
#'
#' Cohort-canonical placeholder shape; values match the Crystal / D / Go ports.
#' @return A `legal_config` list.
#' @export
legal_config_placeholder <- function() {
  legal_config(
    operator_name = "Operator (REPLACE-IN-PRODUCTION)",
    registered_office_address = "Address (REPLACE-IN-PRODUCTION)",
    ico_registration_number = "ZX0000000",
    dpo_email = "dpo@operator.example",
    contact_email = "legal@operator.example",
    jurisdiction = "England and Wales",
    service_name = "Service (REPLACE-IN-PRODUCTION)"
  )
}

# ---------------------------------------------------------------------------
# Page helpers
# ---------------------------------------------------------------------------

#' SHA-256 hex digest of a UTF-8-encoded string.
#'
#' Byte-identical algorithm to foundation/legal/page.ComputeBodyHash.
#' @param body Character scalar.
#' @return Lowercase hex string of length 64.
#' @export
compute_body_hash <- function(body) {
  if (!is.character(body) || length(body) != 1L) {
    stop("compute_body_hash: body must be a single string")
  }
  # openssl::sha256 returns an object with a hex print form; as.character coerces.
  as.character(openssl::sha256(charToRaw(enc2utf8(body))))
}

#' Construct a legal Page document with body_hash + fetched_at populated.
#'
#' @param id Document slug (must be in `ALL_DOCUMENT_IDS`).
#' @param title Display title.
#' @param version Document version identifier (e.g. "v1", "2026-05-28").
#' @param effective_date YYYY-MM-DD date string.
#' @param body Document body text.
#' @param reviewed_by_counsel Logical: TRUE iff counsel has reviewed.
#' @param cfg A `legal_config` for operator metadata.
#' @return A list with class "legal_page".
#' @export
new_page <- function(id, title, version, effective_date, body, reviewed_by_counsel, cfg) {
  if (!valid_document_id(id)) {
    stop(sprintf("new_page: id '%s' not in closed-set (%s)",
                 id, paste(ALL_DOCUMENT_IDS, collapse = ", ")))
  }
  if (!inherits(cfg, "legal_config")) {
    stop("new_page: cfg must be a legal_config (use legal_config())")
  }
  obj <- list(
    id = id,
    slug = id,
    title = title,
    version = version,
    effective_date = effective_date,
    body = body,
    body_hash = compute_body_hash(body),
    reviewed_by_counsel = isTRUE(reviewed_by_counsel),
    operator_name = cfg$operator_name,
    operator_jurisdiction = cfg$jurisdiction,
    operator_contact_email = cfg$contact_email,
    operator_ico_registration = cfg$ico_registration_number,
    fetched_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  )
  class(obj) <- "legal_page"
  obj
}

#' Project a `legal_page` to its slim index-entry form.
#' @param page A `legal_page` from `new_page()`.
#' @return A list with class "legal_index_entry".
#' @export
page_as_index_entry <- function(page) {
  if (!inherits(page, "legal_page")) {
    stop("page_as_index_entry: page must be a legal_page")
  }
  obj <- list(
    id = page$id,
    slug = page$slug,
    title = page$title,
    version = page$version,
    effective_date = page$effective_date,
    reviewed_by_counsel = page$reviewed_by_counsel
  )
  class(obj) <- "legal_index_entry"
  obj
}

#' Return the document body prefixed with `DEFAULT_PLACEHOLDER_ALERT` when un-reviewed.
#'
#' R166 LIABILITY-FOOTER-CONST: when `page$reviewed_by_counsel` is TRUE, returns
#' the body unchanged. When FALSE, prepends `DEFAULT_PLACEHOLDER_ALERT` + "\n\n"
#' (skipping double-prefix if the body already starts with the alert).
#' @param page A `legal_page` from `new_page()`.
#' @return Character scalar.
#' @export
body_with_placeholder_alert <- function(page) {
  if (!inherits(page, "legal_page")) {
    stop("body_with_placeholder_alert: page must be a legal_page")
  }
  if (isTRUE(page$reviewed_by_counsel)) return(page$body)
  if (startsWith(page$body, DEFAULT_PLACEHOLDER_ALERT)) return(page$body)
  paste0(DEFAULT_PLACEHOLDER_ALERT, "\n\n", page$body)
}

#' Render a plain-text version of the legal page (title + meta + body-with-alert).
#' @param page A `legal_page`.
#' @return Character scalar.
#' @export
render_baseline <- function(page) {
  if (!inherits(page, "legal_page")) {
    stop("render_baseline: page must be a legal_page")
  }
  paste0(page$title, "\n\n",
         "Version: ", page$version, "  Effective: ", page$effective_date, "\n\n",
         body_with_placeholder_alert(page))
}

#' Cohort-aligned canonical lookup key for an Acceptance record.
#'
#' Format: `"user_id|document_id|version"`.
#' @param user_id Character scalar.
#' @param document_id Character scalar.
#' @param version Character scalar.
#' @return Character scalar key.
#' @export
acceptance_key <- function(user_id, document_id, version) {
  if (!is.character(user_id) || length(user_id) != 1L ||
      !is.character(document_id) || length(document_id) != 1L ||
      !is.character(version) || length(version) != 1L) {
    stop("acceptance_key: all three arguments must be single strings")
  }
  paste(user_id, document_id, version, sep = "|")
}
