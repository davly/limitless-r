# limitless-r

Cohort-canonical R 4.0+ SDK for the Limitless ecosystem.

## What it ships

- **`limitless::mm_sign` / `limitless::mm_verify`** — L43 Mirror-Mark v1 sign/verify
  with the cohort-canonical KAT-1 anchor.
- **`limitless::loud_once` + `limitless::advisory`** — R143 LOUD-ONCE-WARNING-FLAG
  primitive + the closed 4-value `SEVERITY_LADDER` vocab.
- **`limitless::DEFAULT_PLACEHOLDER_ALERT` + UK GDPR refs** — R166
  LIABILITY-FOOTER-CONST + `REF_UK_GDPR_ARTICLE_9..17` + `REF_FSMA_2000_SECTION_19`
  + `ICO_COMPLAINT_NOTICE` + `FCA_NOT_AUTHORISED_DISCLAIMER`.
- **`limitless::assert_kat1_parity`** — R151 KAT-1 cross-substrate parity assertion.

Single external dependency: the [`openssl`](https://cran.r-project.org/package=openssl)
CRAN package (wraps libcrypto for HMAC-SHA256 + base64).

## R151 KAT-1 cross-substrate firewall

```
239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca
```

Reproducible offline (no R toolchain involved):

```sh
printf '\x01' > /tmp/kat1.bin
printf '\x00%.0s' {1..32} >> /tmp/kat1.bin
openssl dgst -sha256 -mac hmac -macopt key: /tmp/kat1.bin
# HMAC-SHA256(/tmp/kat1.bin)= 239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca
```

Byte-identical to:

- `foundation/pkg/mirrormark.KAT1Digest` (Go canonical)
- the `lore-mark-verify` CLI (apps/lore-mark-verify)
- the `limitless-py / -ts / -rs / -cpp / -dotnet / -solidity / -beam-otp /
  -c-crypto / -crystal / -fortran / -d / -jvm` cohort sibling SDKs

Drift on this literal = parity fail across the entire cohort.

## Install

This package is not on CRAN. Install from GitHub:

```r
# install.packages("remotes")
remotes::install_github("davly/limitless-r")
```

## Use

```r
library(limitless)

# --- Mirror-Mark v1 ---
corpus  <- as.raw(seq.int(1L, 32L))         # your lore-corpus SHA-256
payload <- charToRaw("your payload")
key     <- charToRaw("your hmac key")
mark    <- mm_sign(corpus, payload, key)
mm_verify(mark, corpus, payload, key)        # stops() on tamper
mm_verify_bool(mark, corpus, payload, key)   # TRUE iff match

# Long-lived signer (R143 placeholder-warning surface attached):
m <- mm_marker(corpus, key)
mm_marker_mark(m, payload)

# --- KAT-1 boot-time self-test (R151 cohort firewall) ---
assert_kat1_parity()   # stops() on drift

# --- LoudOnce host-responsibility advisory (R143) ---
adv <- advisory(
  code     = "MY_HOST_NO_DSAR",
  severity = "WARN",
  message  = "DSAR endpoint not wired -- subject-access requests will fail",
  doc_link = "docs/dsar.md:42"
)
loud_once(adv)   # first call: writes to stderr, returns TRUE
loud_once(adv)   # second call: silent, returns FALSE

# --- Legal page surface (R166) ---
cfg <- legal_config(
  operator_name             = "Acme Ltd",
  registered_office_address = "1 Test Street, London EC1A 1AA",
  ico_registration_number   = "ZA000000",
  dpo_email                 = "dpo@acme.example",
  contact_email             = "legal@acme.example",
  jurisdiction              = "England and Wales",
  service_name              = "Acme Service"
)
page <- new_page("terms", "Terms of Service", "v1", "2026-05-28",
                 "Body text...", reviewed_by_counsel = FALSE, cfg)
cat(body_with_placeholder_alert(page))
# IMPORTANT: This document is structured boilerplate and has not been
# reviewed by qualified legal counsel...
```

## Test

```sh
R CMD check .
# or, from inside an R session at the package root:
# devtools::test()
# testthat::test_local()
```

## R-rule alignment

| Rule  | Surface                          | File             |
|-------|----------------------------------|------------------|
| L43   | Mirror-Mark v1 sign/verify       | `R/mirrormark.R` |
| R143  | LOUD-ONCE-WARNING-FLAG primitive | `R/honest.R`     |
| R143.A| SEVERITY-LADDER-CONVENTION       | `R/honest.R`     |
| R150  | reviewed_by_counsel honest-default | `R/legal.R`    |
| R151  | KAT-AS-COHORT-INVARIANT-CROSS-SUBSTRATE-PIN | `R/mirrormark.R` |
| R154  | ARTICLE-9-DSAR-AUDIT-CLASS-COHORT-EXTENSION | `R/legal.R` |
| R157  | SUBSTRATE-NATIVE-IDIOM-OVER-LITERAL-TRANSLATION | all |
| R166  | LIABILITY-FOOTER-CONST           | `R/legal.R`      |

## Catalogue links

- Go canonical foundation: `foundation/pkg/mirrormark`, `foundation/legal`
- Cross-substrate cohort: `limitless-{py, ts, rs, cpp, dotnet, solidity,
  beam-otp, c-crypto, crystal, fortran, d, jvm}`
- Cohort firewall doc: `LimitlessGodfather/reviews/IMPLEMENTATION_2026-05-22/IMP06_LORE_MARK_VERIFY_CLI.md`

## Salvage context

This package was created during the 2026-05-28 infrastructure marathon as a
metadata-only WIP (DESCRIPTION + NAMESPACE) and stranded at session-limit
before any source files were authored. The 2026-05-29 next-session salvage
authored the four `R/*.R` files + four `tests/testthat/*.R` files +
landed this README. The KAT-1 anchor was verified offline via the
documented OpenSSL recipe before authoring, so the cohort firewall is
byte-pinned even though R toolchain availability on the build host could
not be confirmed during the salvage.

## License

Apache-2.0. Cohort-canonical literals (KAT-1 hex,
`[LOUD-ONCE-WARNING]`, `IMPORTANT:` alert prefix, `lore@v1:` mark prefix)
are byte-aligned with the Go canonical foundation. Drift = parity fail.
