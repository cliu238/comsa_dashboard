# COMSA Dashboard — Verbal Autopsy Calibration Platform

**Type:** Brownfield. Mature, deployed, actively used by researchers.
**Initialized into GSD:** 2026-08-18 (codebase map first — see `.planning/codebase/`)

## What it is

A web platform for processing verbal autopsy (VA) data and calibrating cause-of-death
classifications. Researchers upload VA data or launch bundled demos, the platform runs
the `openVA` and `vacalibration` R packages as long-running async jobs, and returns
calibrated cause-specific mortality fractions (CSMF) with credible intervals,
misclassification matrices, and downloadable artifacts.

## Why calibration matters here

A VA algorithm (InterVA / InSilicoVA / EAVA) infers cause of death from a symptom
questionnaire, and it makes systematic mistakes. The CHAMPS study measured those
mistakes as a misclassification matrix. Calibration uses that matrix to recover the
underlying cause distribution. So a calibrated estimate carries **two** sources of
uncertainty — sampling error plus uncertainty in the misclassification matrix — while
an uncalibrated one carries only the first. Any UI that reports these must not conflate
them; getting this wrong is the substance of issue #101.

## Stack

- **Backend:** R + plumber (`backend/run.R`, `backend/plumber.R`). Async jobs via a
  detached `Rscript backend/jobs/run_job.R <id>` per job — no queue or worker pool.
- **Frontend:** React + Vite (`frontend/`), plain CSS.
- **Persistence:** externally hosted PostgreSQL (SSH tunnel locally, k8s Secrets in prod).
- **Deploy:** GitHub Actions → GHCR → JHU IDIES k8s-dev (`dev.sites.idies.jhu.edu/comsa-dashboard`).

Details in `.planning/codebase/STACK.md` and `INTEGRATIONS.md`.

## Constraints that shape the work

- **The R packages are third-party and authoritative.** `vacalibration` is maintained by
  @sandy-pramanik, a collaborator on this repo's issues. When the dashboard and the
  package disagree, the package's methodology wins; the dashboard should not silently
  invent statistical behaviour. Methodological questions get asked, not patched around.
- **Two job paths duplicate their result assembly** (`backend/jobs/algorithms/vacalibration.R:206-296`
  vs `backend/jobs/processor.R:189-270`, near-verbatim). This is the structural reason
  fixes have repeatedly landed in only one path. Documented as an anti-pattern in
  `.planning/codebase/ARCHITECTURE.md`.
- **A cross-language JSON seam.** R `NULL` serialises as `{}`, `NA` as the string `"NA"`,
  and every scalar arrives boxed as `[x]`. `frontend/src/api/client.js` `unbox()`
  normalises all of it and is load-bearing — guards downstream must type-check, not
  null-check.
- **Unpinned R dependencies** (issue #123). An upstream `RcppParallel` release requiring
  `cmake` broke deploys for two days and the failure was initially misattributed to an
  unrelated PR.

## Working rules (from CLAUDE.md, binding)

- Simplest code and structure; no over-engineering; no feature creep.
- No unnecessary files; archive or delete superseded ones.
- **No silent test skips.** If a test needs the backend, start it or fail loudly.
- Write a unit test for each identified edge case **before** implementing.
- Do not trust documentation or assumptions for critical values — verify against source
  or runtime output.

## Current focus

Issue #101 — calibrated output identical to uncalibrated on data containing a broad
cause with zero deaths. Diagnosed jointly with the package author; his reply of
2026-08-17 settled the methodology. See `.planning/REQUIREMENTS.md`.
