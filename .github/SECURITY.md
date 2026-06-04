# limitless-r — Security model

*Drafted 2026-06-04. Source of truth for the trust boundaries this R SDK
defends, the cryptographic primitives it relies on, and the residual gaps a
host application must own. Written against the source at commit `c2d094e`
(`R/mirrormark.R`, `R/honest.R`, `R/legal.R`, `R/kat.R`). Companion to the Go
reference and the `sdk/limitless-py` Python model, narrowed to this
substrate's much smaller surface.*

`limitless` (R) is the **R 4.0+ SDK** that R-based analytical / actuarial
consumer apps import to participate in the cohort-canonical Mirror-Mark
(L43 / R151), LOUD-ONCE advisory (R143) and UK-GDPR legal-footer (R166)
surfaces. It is a **thick library, not a service**: there is no HTTP
listener, no network egress, no filesystem access, and no credential store.
Every secret it touches (an HMAC key, a corpus digest) is passed in by the
caller for the duration of a single function call or marker object.

The SDK is therefore a **library-shaped trust surface**. Its security
posture is the union of (a) the correctness and integrity of its one
cryptographic dependency, (b) how a long-lived `mm_marker` holds the key the
caller hands it, (c) the timing characteristics of its verification path,
and (d) what it leaks back to the host through error messages and stderr.

## Attack surface at a glance

| Vector | Present in this SDK? | Notes |
|---|---|---|
| Network listener / inbound RPC | No | No server, no socket. |
| Outbound network calls | No | No HTTP client; no `openssl` network use. |
| Filesystem reads/writes | No | Pure in-memory; `loud_once` writes only to a caller-supplied connection (default `stderr()`). |
| Environment-variable reads | No | No `Sys.getenv` anywhere in `R/`. |
| Credential storage | Transient only | Keys live only inside a function call or an `mm_marker` environment for that object's lifetime. |
| External dependency | One | `openssl` (CRAN) — see Trust Boundary 1. |
| Untrusted input parsing | Yes | `mm_verify` / `base64url_decode` parse caller- or peer-supplied mark strings — see Trust Boundary 3. |

## Data the SDK handles

- **HMAC keys** (`raw` vectors) passed to `mm_sign`, `mm_verify`, and stored
  inside an `mm_marker` environment. These are secrets.
- **Corpus SHA-256 digests** (`raw`, 32 bytes) — not secret, but integrity-
  bearing: a wrong corpus produces a non-verifying mark.
- **Payloads** (`raw`) being attested — supplied by the caller; the SDK does
  not interpret them.
- **Legal-document metadata** (operator name, ICO number, contact email) via
  `legal_config()` — non-sensitive operator identity, never transmitted.

No personal data, no payment data, and no third-party credentials transit
this library.

## Trust boundaries

The SDK has **three** trust boundaries.

### 1. The `openssl` CRAN dependency — sole cryptographic root of trust

Every cryptographic operation in this SDK delegates to the
[`openssl`](https://cran.r-project.org/package=openssl) CRAN package, which
wraps libcrypto:

- `.hmac_sha256()` (`R/mirrormark.R:151-157`) calls
  `openssl::sha256(data, key = key)`. The `openssl` package computes
  **HMAC-SHA256** when a non-NULL `key` is supplied. This is the documented
  runtime behaviour of the package, but the `key=` argument's HMAC semantics
  are **not surfaced in the CRAN function-signature documentation** for
  `sha256` — they are an established but lightly-documented behaviour of the
  package. The entire Mirror-Mark sign/verify path depends on it.
- `compute_body_hash()` (`R/legal.R:195-201`) calls `openssl::sha256()` with
  no key for the plain SHA-256 body digest used in `new_page()`.
- `base64url_encode()` / `base64url_decode()` (`R/mirrormark.R:115-141`) call
  `openssl::base64_encode` / `base64_decode`, then perform the std↔url
  alphabet swap and padding handling in pure R.

**Residual risk.** If a future `openssl` release changes the meaning of the
`key=` argument to `sha256` (e.g. treats it as a salt rather than an HMAC
key), every mark this SDK produces would silently stop matching the cohort
canonical — a **silent cross-substrate parity break**, not a crash.

**Mitigation already in code.** `assert_kat1_parity()`
(`R/mirrormark.R:380-389`) is a boot-time tripwire: it recomputes the KAT-1
HMAC-SHA256 over `kat1_input()` and `stop()`s if the result is not the
cohort-canonical hex
`239a7d0d3f1bbe3a98aede01e2ad818c2db60b7177c02e2f015035b2b5b7dbca`. Hosts
**SHOULD call `assert_kat1_parity()` during startup** so a drifted or
behaviour-changed `openssl` fails loudly at boot rather than at the next
cross-substrate verification round-trip. The same anchor is independently
reproducible with no R toolchain via the OpenSSL CLI recipe in `README.md`,
so the literal can be re-verified out-of-band.

**Recommendation for hosts.** Pin `openssl (>= 2.0.0)` (the version floor in
`DESCRIPTION`) in your renv/packrat lockfile and re-run the package test
suite (which includes `assert_kat1_parity()` and the KAT-1 mark vector)
after any `openssl` upgrade.

### 2. HMAC key lifecycle inside `mm_marker`

`mm_sign` / `mm_verify` are stateless — the key exists only on the call
stack. The long-lived signer `mm_marker()` (`R/mirrormark.R:300-317`) is the
only construct that **retains** a key:

- The key is stored in an R environment created with
  `new.env(parent = emptyenv())` and the object is classed
  `"limitless_marker"`. R's copy-on-modify semantics mean the stored `raw`
  vector is an independent copy of the caller's input.
- `mm_marker()` **refuses an empty key at construction**
  (`R/mirrormark.R:305-307`): this is a deliberate fail-closed guard against
  accidental key loss. KAT-1 / empty-key vectors must use `mm_sign()`
  directly.
- A placeholder (all-zero) corpus or key is detected at construction
  (`using_placeholder_corpus` / `using_placeholder_key`) and triggers a
  single LOUD stderr warning on first use via `.marker_maybe_warn()`
  (`R/mirrormark.R:319-336`), so marks signed with a placeholder key cannot
  silently masquerade as production-verifiable.

**Residual risk — no key zeroization.** R offers no reliable way to wipe a
`raw` vector's backing memory. Once an `mm_marker` is created, the key
persists in the R heap until the object is unreferenced **and** the garbage
collector reclaims it; it may also survive in copies made by the R
interpreter. A host whose threat model includes **process-memory
introspection or a core dump** cannot rely on this SDK to scrub the key —
that is the host's responsibility (OS-level memory protection, short-lived
worker processes, avoiding swap). This is the same fundamental constraint the
Python SDK documents for interned strings; it applies to R `raw` vectors
too.

**Recommendation for hosts.** Construct `mm_marker` objects with the
narrowest possible lifetime, do not log marker objects, and do not embed
production HMAC keys in saved `.RData` workspaces (note `.RData` is already
git-ignored in this repo, but workspace persistence is a host concern).

### 3. Untrusted mark parsing — `mm_verify` / `base64url_decode`

`mm_verify()` (`R/mirrormark.R:229-260`) and the `mm_marker_verify` path
accept a **mark string that may originate from an untrusted peer** (the whole
point of a cross-substrate verifier). The parsing is defensive:

- Type/shape checks reject non-scalar marks and wrong-length corpus digests
  before any crypto runs.
- The `"lore@v1:"` prefix is required (`R/mirrormark.R:238`); unknown
  versions `stop()` with a stable message.
- `base64url_decode()` (`R/mirrormark.R:130-141`) returns `NULL` (not an
  error, not a partial buffer) on malformed input, including the
  impossible-length case (remainder-1 → `NULL`), and wraps
  `openssl::base64_decode` in `tryCatch`. `mm_verify` converts a `NULL`
  decode into a `stop()` ("malformed mark").
- Body length is validated to be exactly 40 bytes (8 corpus-prefix + 32 HMAC)
  before the digest is compared.
- All failure paths use a stable `"mirrormark: ..."` message prefix so hosts
  can `tryCatch()` deterministically; `mm_verify_bool()` collapses every
  failure to `FALSE`.

**Timing characteristic — important.** Digest comparison uses
`.constant_time_equal()` (`R/mirrormark.R:163-171`), which XORs the two `raw`
vectors element-wise and folds with `Reduce(\`|\`)` so that **it does not
short-circuit on the first differing byte** — a deliberate choice over a
naïve early-return loop. However, this is **not a hardware/cryptographic
constant-time primitive**: it runs in the R interpreter over allocated R
vectors, and the *length-mismatch* path (`length(a) != length(b)`) returns
early. A host that exposes `mm_verify` in a **timing-observable context**
(for example a Plumber/`httr2` HTTP endpoint that returns verify results to
remote callers) should treat the comparison as **best-effort, not
timing-attack-proof**, and add its own mitigations (constant-time response
delay, rate limiting, or verifying out of the request hot-path). For
local/offline cold-verify use (the primary intended use) this is not a
concern.

## What the SDK leaks (host-facing surface)

- **Through errors:** all errors are `stop()` with a `"mirrormark: ..."`,
  `"advisory: ..."`, `"legal: ..."`-style stable prefix and **never include
  key material**. Error messages may include lengths and the offending
  severity/slug string (caller-supplied), never secrets.
- **Through stderr:** `loud_once()` (`R/honest.R:137-145`) and the
  `mm_marker` placeholder warning write a formatted advisory line to a
  caller-supplied connection (default `stderr()`). The line contains the
  advisory `code`, `severity`, `message`, and `doc_link` — all host-authored
  — plus the `host_prefix`. **No key or corpus bytes are ever written.**
- **Through return values:** marks are public artefacts (a corpus-prefix plus
  an HMAC tag) and are safe to transmit. They do **not** reveal the key.
- **No logging framework, no traces, no telemetry** are configured by this
  library.

## Cryptographic primitives

| Use | Primitive | Notes |
|---|---|---|
| Mirror-Mark sign/verify | HMAC-SHA256 via `openssl::sha256(data, key=)` | Cryptographic. Root of trust = the `openssl` CRAN package (Trust Boundary 1). Version byte `0x01` prepended to `corpusSHA + payload`. |
| Legal body hash (`compute_body_hash`) | SHA-256 via `openssl::sha256()` | Integrity digest of document body; not a secret. |
| Mark digest comparison | `.constant_time_equal` (XOR + `Reduce("|")` over `raw`) | Non-short-circuiting, but **not** a hardened constant-time primitive (Trust Boundary 3). R has no stdlib `memcmp`-equivalent. |
| base64url transport encoding | `openssl::base64_encode/decode` + pure-R alphabet swap | Not cryptographic — RFC 4648 §5 unpadded encoding of the mark body. |

## Cohort-invariant integrity

The KAT-1 anchor is the cohort cross-substrate firewall and is pinned in
three independent places in this repo, any of which failing indicates drift:

- `KAT1_DIGEST_HEX` constant (`R/mirrormark.R:65`).
- `assert_kat1_parity()` recomputation (`R/mirrormark.R:380`) and
  `kat1_compute()` (`R/kat.R:32`).
- The dedicated test files `tests/testthat/test_kat.R` and
  `tests/testthat/test_mirrormark.R`, which also pin `KAT1_MARK`
  (`lore@v1:AAAAAAAAAAAjmn0NPxu-Opiu3gHirYGMLbYLcXfALi8BUDWytbfbyg`).

Both the hex digest and the mark string are reproducible offline with no R
toolchain (OpenSSL CLI recipe in `README.md`). Drift on either literal is a
parity failure across the entire Limitless cohort, by design.

## Known gaps (host responsibilities, not library bugs)

1. **No HMAC-key zeroization** (Trust Boundary 2). R cannot wipe a `raw`
   vector's backing store. Hosts with a memory-introspection threat model
   must use OS-level protections and short-lived processes.
2. **`.constant_time_equal` is not timing-attack-hardened** (Trust Boundary
   3). Hosts exposing `mm_verify` over a network must add their own
   timing/rate mitigations.
3. **Single dependency is the whole crypto root of trust** (Trust Boundary
   1). A behaviour change in `openssl`'s `key=` argument breaks parity
   silently; mitigated by calling `assert_kat1_parity()` at boot and pinning
   the dependency in a lockfile.
4. **R toolchain not confirmed on the original build host.** Per the
   `README.md` salvage note, `R CMD check` could not be run when the source
   was authored; the KAT-1 anchor was verified out-of-band via OpenSSL. Hosts
   adopting this SDK should run the bundled `testthat` suite once in their own
   environment to confirm the `openssl` build present there reproduces the
   cohort anchors.

## Reporting a vulnerability

Do **not** open a public issue for a security report. Email
`security@limitless.dev` (the Limitless ecosystem standard channel). Include
the affected function(s), R + `openssl` package versions, and a minimal
reproduction. As a thin cohort-firewall SDK, any issue that could break KAT-1
cross-substrate parity should expect a coordinated disclosure window with the
Go canonical foundation and the other cohort substrate SDKs.
