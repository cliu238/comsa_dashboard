---
status: passed
phase: 02-reproducible-builds
source: [02-VERIFICATION.md]
started: 2026-08-25
updated: 2026-08-25
---

## Current Test

[none — all items resolved]

## Tests

### 1. A real successful login exercising `sodium::password_verify()`

expected: HTTP 200 with a JWT, proving that `sodium::password_verify()` — not merely
`library(sodium)` — executes correctly against the pinned `sodium 1.4.0` in the new image.

result: PASSED (2026-08-25) — closed WITHOUT a live login, by exercising the call
directly inside the shipped image, which is a stronger proof and touches no data:

    docker run --rm --platform linux/amd64 \
      ghcr.io/cliu238/comsa_dashboard-backend:latest R -q -e "..."

    sodium version in image: 1.4.0
    hash prefix: $7$C6..../..
    verify correct password -> TRUE
    verify wrong   password -> FALSE

Both directions asserted (a verifier that returns TRUE for everything would pass a
one-sided check). `$7$` is the Argon2/scrypt-family prefix `password_store()` emits,
so the hash really was produced by sodium rather than a stub.

This is better evidence than the suggested live login: it pins the result to the exact
published artifact (`:latest`, amd64, the image the cluster is running) instead of to
whatever the cluster happens to have rolled out, and it creates no account and writes
no row to the deployed database.

why this is still open: the live evidence obtained so far is a `POST /api/auth/login` with a
NONEXISTENT email returning a clean HTTP 401 and `{"error":["Invalid email or password"]}`. The
verifier read `backend/plumber.R` and confirmed the handler's `is.null(user) || !verify_password(...)`
short-circuits on the first clause, so `verify_password()` — and therefore
`sodium::password_verify()` — is never reached for a nonexistent user. The 401 proves the auth
module loaded (a missing `sodium` would fail to source it and surface as a 500 or a dead endpoint),
which is the failure mode criterion 2 targets. It does not prove the hash-verification call itself.

how it was tested: see result above. The originally suggested route — logging in at
https://dev.sites.idies.jhu.edu/comsa-dashboard with an existing account — would also close it,
and remains valid as a belt-and-braces check by whoever holds an account.

does this block the phase: No. ROADMAP criterion 2 is worded about the install mechanism
("`sodium` is installed explicitly rather than arriving transitively via `plumber`"), and that is
fully verified from source: an explicit `install.packages(c(..., 'sodium'))`, a build-time
`stopifnot('sodium' %in% pkgs$Package, ...)` guard that fails the image build if it is absent, and
`sodium,1.4.0` recorded in `backend/package-manifest.csv`. This item is the residual end-to-end
inch, tracked so it is not silently dropped.

## Summary

total: 1
passed: 1
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
