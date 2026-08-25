---
status: partial
phase: 02-reproducible-builds
source: [02-VERIFICATION.md]
started: 2026-08-25
updated: 2026-08-25
---

## Current Test

[awaiting human testing]

## Tests

### 1. A real successful login exercising `sodium::password_verify()`

expected: HTTP 200 with a JWT, proving that `sodium::password_verify()` — not merely
`library(sodium)` — executes correctly against the pinned `sodium 1.4.0` in the new image.

result: [pending]

why this is still open: the live evidence obtained so far is a `POST /api/auth/login` with a
NONEXISTENT email returning a clean HTTP 401 and `{"error":["Invalid email or password"]}`. The
verifier read `backend/plumber.R` and confirmed the handler's `is.null(user) || !verify_password(...)`
short-circuits on the first clause, so `verify_password()` — and therefore
`sodium::password_verify()` — is never reached for a nonexistent user. The 401 proves the auth
module loaded (a missing `sodium` would fail to source it and surface as a 500 or a dead endpoint),
which is the failure mode criterion 2 targets. It does not prove the hash-verification call itself.

how to test: log in at https://dev.sites.idies.jhu.edu/comsa-dashboard with an existing account and
a correct password. A 200 + JWT closes this. A 500 would mean `sodium` resolves at load time but
fails in use — report it rather than working around it.

does this block the phase: No. ROADMAP criterion 2 is worded about the install mechanism
("`sodium` is installed explicitly rather than arriving transitively via `plumber`"), and that is
fully verified from source: an explicit `install.packages(c(..., 'sodium'))`, a build-time
`stopifnot('sodium' %in% pkgs$Package, ...)` guard that fails the image build if it is absent, and
`sodium,1.4.0` recorded in `backend/package-manifest.csv`. This item is the residual end-to-end
inch, tracked so it is not silently dropped.

## Summary

total: 1
passed: 0
issues: 0
pending: 1
skipped: 0
blocked: 0

## Gaps
