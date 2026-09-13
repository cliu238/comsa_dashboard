---
slug: issue-105-calibrate-disabled
status: resolved  # issue #105 CLOSED/COMPLETED on GitHub (PR #106 merged); archived 2026-07-28
trigger: "gh 检查一下 issue #105"
created: 2026-07-28
updated: 2026-07-28
---

# Debug: Calibrate button inactive (GitHub issue #105)

## Symptoms

**Source:** GitHub issue #105 "inactive Calibrate button" (author sandy-pramanik, opened 2026-07-28),
which blocks issue #101 "same results for uncalibrated and calibrated".

- **Expected behavior:** Uploading `sample_eava_1to59m.csv` (from issue #101) with Age Group =
  "Children (1–59 months)" and algorithm EAVA should map all causes cleanly and leave the
  **Calibrate** (submit) button enabled.
- **Actual behavior:** The cause-mapping preview reports 3 unrecognized causes, so
  `previewHasErrors` is true and the Calibrate button renders disabled. The user cannot submit.
- **Error messages:** No stack trace. The in-form preview panel shows:
  ```
  Eava: 1334 of 2383 records will be calibrated.
  3 unrecognized cause(s) — fix these before submitting:
    - "hiv" (162 records) — no close match; relabel to a supported cause.
    - "other_infections" (720 records) — no close match; relabel to a supported cause.
    - "severe_malnutrition" (167 records) — no close match; relabel to a supported cause.
  Your cause          Maps to                 Records
  diarrhea            sepsis_meningitis_inf   473
  malaria             sepsis_meningitis_inf   201
  other               other                   134
  pneumonia           pneumonia               526
  ```
- **Timeline:** Reported 2026-07-28, against the cause-mapping-preview feature added
  2026-07-22 (`docs/superpowers/specs/2026-07-22-cause-mapping-preview-design.md`, issue #92).
- **Reproduction:** Submit Job form → Age Group = Children (1–59 months) → algorithm EAVA →
  upload `sample_eava_1to59m.csv` → Calibrate button is greyed out.

## Artifacts

- Screenshot from the issue: `/private/tmp/claude-501/-Users-eric-projects6-comsa-dashboard/2cd9e2bd-f46b-4fe1-9b63-99045ea5ac5b/scratchpad/issue105.png`
- Reproduction CSV (downloaded from issue #101):
  `/private/tmp/claude-501/-Users-eric-projects6-comsa-dashboard/2cd9e2bd-f46b-4fe1-9b63-99045ea5ac5b/scratchpad/sample_eava_1to59m.csv` — 2383 data rows, columns `ID,cause`.
  Original URL: https://github.com/user-attachments/files/29755525/sample_eava_1to59m.csv

## Evidence

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: The uploaded CSV contains exactly 7 distinct cause values, and **all 7 are already
  canonical CHILD broad-cause names**, so nothing in it should be unrecognized for age_group=child.
  Counts: other_infections 720, pneumonia 526, diarrhea 473, malaria 201,
  severe_malnutrition 167, hiv 162, other 134 (total 2383).
  `get_broad_causes("child")` (backend/jobs/utils.R:395) =
  malaria, pneumonia, diarrhea, severe_malnutrition, hiv, injury, other, other_infections, nn_causes
  — a superset of the 7 values present.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: The preview output is **consistent, item for item, with the preview having run under
  `age_group = "neonate"` instead of `"child"`.**
  `get_broad_causes("neonate")` = congenital_malformation, pneumonia, sepsis_meningitis_inf,
  ipre, other, prematurity. Under that list:
    - pneumonia, other → present in the neonate broad list, so `is_broad_format()` is TRUE and
      `build_broad_matrix()` maps them 1:1. Matches the observed `pneumonia→pneumonia`,
      `other→other`.
    - diarrhea, malaria → NOT neonate broad names, so `classify_cause()` falls through to
      `safe_cause_map(..., "neonate")`, where vacalibration's neonate map folds them into
      `sepsis_meningitis_inf`. Matches the observed (otherwise nonsensical) mapping — note
      `sepsis_meningitis_inf` is not even a member of the child broad-cause list.
    - hiv, other_infections, severe_malnutrition → neither neonate broad names nor neonate
      specific-cause names, so they classify as NA → reported unrecognized. Matches exactly.
  Arithmetic corroborates: calibrated denominator 526+134+473+201 = **1334**, matching the
  reported "1334 of 2383"; unrecognized 720+167+162 = 1049; 1334+1049 = 2383.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: `POST /jobs/preview` (backend/plumber.R:390-392) silently defaults the age group:
  ```r
  age_group <- req$args$age_group
  if (is.null(age_group) || length(age_group) == 0) age_group <- "neonate"
  ```
  If the multipart text field does not surface on `req$args`, every preview runs as neonate with
  no warning. Recent commit 625110b "Fix multipart file upload handling in plumber API" touched
  this parsing path.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: The frontend side looks correct on inspection and is NOT yet ruled out only because it
  has not been exercised at runtime. `frontend/src/api/client.js:93-105` appends
  `age_group` to the FormData, and `JobForm.jsx:100-117` re-runs the preview whenever
  `uploads` or `ageGroup` change. `ageGroup` state defaults to `'neonate'`
  (`JobForm.jsx:33`) — so a failure to propagate the user's selection would produce exactly
  the observed neonate behavior.

- timestamp: 2026-07-28 (session-manager, LIVE DEPLOYED BACKEND)
  finding: **Root cause confirmed on the real deployment**, closing the debugger's stated caveat that
  HTTP verification had only used a local mirror. Target:
  `https://dev.sites.idies.jhu.edu/comsa-dashboard/api` (health endpoint returned
  `{"status":"ok"}`). This server runs the PRE-FIX code, so it reproduces the bug as users see it.
  Same CSV, same server, only the `age_group` transport varied:
    - **A. `-F age_group=child` (multipart, old frontend):** 1334/2383, unrecognized
      hiv=162, other_infections=720, severe_malnutrition=167, and
      diarrhea/malaria -> sepsis_meningitis_inf. This matches the issue #105 screenshot
      **item for item, count for count**.
    - **B. `?age_group=child` (query string, the fix):** 2383/2383, ZERO unrecognized, all 7 causes
      identity-mapped (diarrhea->diarrhea, hiv->hiv, malaria->malaria, other->other,
      other_infections->other_infections, pneumonia->pneumonia,
      severe_malnutrition->severe_malnutrition).
    - **C. `age_group` omitted entirely:** byte-identical to A.
  The **A == C identity is the decisive proof**: sending `age_group=child` as a multipart field is
  indistinguishable from not sending it at all, i.e. the value is *destroyed* by plumber's form
  parser, not merely mis-parsed. This is stronger than the mirror-based evidence.
  Corollary for deployment: **the frontend one-line transport change alone fixes issue #105 against
  the currently deployed, unpatched backend** (probe B ran green on it). The backend
  `resolve_age_group()` loud-failure change is defense-in-depth and does not gate the user-facing fix.

## Current Focus

status: FIX APPLIED AND SELF-VERIFIED. Awaiting human confirmation in a real browser.
next_action: user confirms the Calibrate button is enabled for the issue #101 child CSV

verification_summary:
  falsification_test_result: >
    PASSED as predicted. Live plumber, same file, only the transport changed:
    multipart `-F age_group=child` -> ran as neonate, 1334/2383, has_errors TRUE;
    query-string `?age_group=child` -> ran as child, 2383/2383, has_errors FALSE,
    all 7 causes 1:1. The mechanism is confirmed, not merely consistent.
  post_fix_http_matrix:
    - "?age_group=child + file  -> child, has_errors FALSE, 2383/2383, no unrecognized (Calibrate ENABLED)"
    - "-F age_group=child only  -> loud error 'Missing required parameter age_group...' (NOT a silent neonate report)"
    - "age_group omitted        -> loud error"
    - "?age_group=adult         -> loud error naming valid options (neonate, child)"
    - "?age_group=neonate       -> still the 1334/2383 neonate report (genuinely requested; unchanged behavior)"
    - "?age_group=Child         -> normalized to child, clean 2383/2383"
  regression_suites:
    - "frontend: 240 tests / 32 files pass (npm test, excluding the integration test that needs a live :8000)"
    - "frontend: eslint clean on all changed files; production build succeeds"
    - "backend: new section 2f 17/17 pass; R syntax check OK on utils.R, plumber.R, tests file"
  tests_proven_to_be_real_guards:
    - "client.issue105.test.js: 3 of 4 FAILED before the fix, all 4 pass after"
    - "test_vacalibration_backend.R 2f: 11 of 17 FAILED before the fix, 17/17 after (assertions match message CONTENT so a missing helper cannot pass them spuriously)"
    - "JobForm.preview.behavior.test.jsx new case: verified RED by stashing only JobForm.jsx, then GREEN once restored"

reasoning_checkpoint:

reasoning_checkpoint:
  hypothesis: >
    `POST /jobs/preview` runs `preview_cause_mapping()` with `age_group="neonate"` even when the
    form has "Children (1-59 months)" selected. Mechanism: `previewMapping()` sends `age_group`
    as a MULTIPART FORM FIELD. plumber 1.3.2 gives a multipart text part no Content-Type and no
    filename, so `parser_picker()` falls through to `parsers$alias$form` (`parseQS`). `parseQS`
    treats the raw part value as a URL-encoded query string; `"child"` contains no `=`, so it
    parses to `list()`. `combine_keys(type="multi")` then sets `req$args$age_group <- list()`.
    At plumber.R:392 `is.null()` is FALSE but `length() == 0` is TRUE, so the silent
    `"neonate"` fallback fires. Under neonate, hiv / other_infections / severe_malnutrition are
    unrecognized -> `has_errors=TRUE` -> `JobForm.jsx:468` disables Calibrate.
  confirming_evidence:
    - "Experiment A (direct R call on the issue CSV): preview_cause_mapping(df, 'neonate') reproduces the screenshot EXACTLY -- calibrated_denominator 1334 of 2383, has_errors TRUE, diarrhea->sepsis_meningitis_inf 473, malaria->sepsis_meningitis_inf 201, other->other 134, pneumonia->pneumonia 526, and unrecognized hiv 162 / other_infections 720 / severe_malnutrition 167. preview_cause_mapping(df, 'child') is clean: has_errors FALSE, denominator 2383, all 7 causes map 1:1."
    - "Experiment B (live plumber 1.3.2, minimal mirror of plumber.R:390-433, POST multipart -F age_group=child): req$args$age_group is class=list len=0 (EMPTY LIST), while req$body$age_group is the intact 4-field part [value, content_disposition, name, parsed]. names(req$args) DOES contain age_group, so the field arrives -- its parsed value is destroyed."
    - "Mechanism traced through plumber internals: parser_multi -> parse_raw -> parser_picker(content_type=NULL, first_byte='c', filename=NULL) -> parsers$alias$form -> parser_form == parser_text(parseQS). Direct simulation of parser_form: 'child'->list() len 0, 'neonate'->list() len 0, 'EAVA'->list() len 0, 'FALSE'->list() len 0, '5000'->list() len 0, but 'a=b'-> list(a='b') len 1. Any bare value with no '=' is annihilated."
    - "Asymmetry explains why job submission is unaffected: client.js submitJob (lines 71-86) sends every scalar via URLSearchParams in the QUERY STRING (req$argsQuery) and only files in FormData, whereas previewMapping (lines 93-105) appends age_group to FormData. Same backend read pattern, different transport -- only the multipart path is corrupted."
  falsification_test: >
    Sending age_group in the query string instead of the multipart body must make
    req$args$age_group == "child" and the report come back has_errors=FALSE with 7 mapped causes
    and denominator 2383. If the query-string form ALSO returned neonate output, the mechanism
    above would be wrong.
  fix_rationale: >
    Two independent defects, both fixed. (1) TRANSPORT: previewMapping must send age_group the way
    submitJob already proves works -- in the query string -- so the value survives plumber's
    multipart parser. This addresses the root cause, not the symptom, because the value is no
    longer routed through parseQS. (2) SILENT FALLBACK: plumber.R:392 converted a missing/destroyed
    required parameter into a plausible-but-wrong answer. Per the project's no-silent-fallback rule
    (CLAUDE.md, issues #77/#89) a missing or invalid age_group must fail loudly, so this class of
    bug can never again masquerade as a legitimate cause-mapping error.
  blind_spots:
    - "Verified against plumber 1.3.2 only; a future plumber may set a default Content-Type for text parts, which would change the parse but not invalidate the query-string fix."
    - "The full backend (Rscript run.R) cannot boot in this environment -- RPostgres and DBI are not installed -- so the endpoint was exercised through a byte-for-byte mirror of the endpoint body on the same plumber version rather than the real server. The DB is not on the preview code path (no DB call in the endpoint or in preview_cause_mapping), so this does not weaken the result."
    - "Issue #101 (same results uncalibrated vs calibrated) is NOT explained by this bug, since submitJob's query-string transport delivers age_group correctly. #101 needs separate investigation after #105 unblocks it."

next_action: write failing regression tests (frontend transport + backend loud-failure), then apply the two-part fix

## Eliminated

- hypothesis: The cause-mapping logic itself is wrong for child data (preview_cause_mapping,
    classify_cause, is_broad_format, build_broad_matrix, get_broad_causes).
  evidence: Experiment A called preview_cause_mapping(df, "child") directly on the exact CSV from
    the issue and got has_errors=FALSE, calibrated_denominator=2383/2383, all 7 causes mapped 1:1.
    The mapping units are correct; only the age_group argument reaching them was wrong.
  timestamp: 2026-07-28

- hypothesis: The multipart field never arrives at the backend at all (e.g. dropped by the
    frontend, or `age_group` missing from `names(req$args)`).
  evidence: Experiment B shows `names(req$args)` == "age_group, file_eava" and
    `req$body$age_group` holds the intact part with value/name/parsed. The field arrives; plumber's
    form parser empties its value.
  timestamp: 2026-07-28

- hypothesis: Commit 625110b ("Fix multipart file upload handling") broke age_group parsing.
  evidence: The behavior is inherent to plumber 1.3.2's parser_picker fallback for text parts with
    no Content-Type, reproduced in an isolated app containing none of that commit's code. The
    FILE parts parse correctly (filename present -> getContentType -> octet parser); only bare
    text parts are affected.
  timestamp: 2026-07-28

## Notes for the fix

- Two defects are likely in play and both should be considered: (1) the age group not reaching
  `preview_cause_mapping()`, and (2) the silent `"neonate"` default at plumber.R:392, which
  converts a missing required parameter into a plausible-but-wrong answer. Per the project's
  no-silent-fallback stance (CLAUDE.md, issues #77/#89), a missing/invalid `age_group` should
  fail loudly rather than guess.
- Regression test must cover a child-age-group preview of a broad-format child CSV asserting
  `has_errors == FALSE` and a 9-column child mapping, so this cannot silently regress.

## Specialist Review

Reviewer: project-local `plumber` skill (`.claude/skills/plumber/SKILL.md`), dispatched by the
session manager. Verdict: **SUGGEST_CHANGE** — the applied fix is correct and idiomatic, but the
identical defect remains unfixed on a more dangerous endpoint.

**Confirmed the fix is right.** Reviewer independently re-ran the R and frontend claims (23/23
frontend tests across the three touched files; child preview 0 unrecognized / 2383 of 2383 /
has_errors FALSE; same data as neonate -> 1334 with exactly hiv, other_infections,
severe_malnutrition).

**1. Query string is the correct idiomatic fix.** All alternatives were checked and are worse:
  - `@param age_group:str` + formal argument — NO FIX. plumber matches `req$args` onto formals and a
    default applies only when the name is ABSENT. A multipart-derived `list()` is present, so it is
    passed *in place of* the default. In-repo proof: `plumber.R:600-602` (`/jobs/demo`) uses exactly
    this style and is MORE exposed than the old preview code (no `length()==0` guard at all).
  - `@parser multi` / `@parser form` — NO FIX. Endpoint-level aliases don't change `parser_multi`'s
    per-part dispatch, which is where the wrong parser is chosen.
  - `req$body` instead of `req$args` — NO FIX. plumber parses the body once and merges into `args`;
    both read the identical already-emptied `list()`.
  - Explicit Content-Type via `new Blob([...], {type:'text/plain'})` — ACTIVELY WORSE. A Blob part
    gets `filename="blob"`, and `parser_picker` prefers filename-based dispatch, yielding raw bytes.
  - Optional tightening: read `req$argsQuery$age_group` instead of `req$args$age_group` at
    `plumber.R:395`, which would *enforce* the documented query-string contract rather than document it.

**2. HIGHEST-VALUE FINDING — the same defect is unfixed on `POST /jobs`.**
  `backend/plumber.R:221-246` has nine scalars with the identical `req$args$<scalar>` pattern,
  **including the same silent `age_group -> "neonate"` fallback at `:227-228`**. This is the WRITE
  path that creates the calibration job. It is masked today only because `client.js:71-86` happens to
  use `URLSearchParams`. A lost `age_group` there produces a **silently wrong calibration** rather
  than a merely disabled button — strictly worse than issue #105. Affected lines: job_type 221,
  algorithm 224, age_group 227, country 230, calib_model_type 233, ensemble 236, n_mcmc 239,
  n_burn 242, n_thin 245. Note the spec just corrected asserts the query-string contract for "every
  scalar POST /jobs takes" while the code still silently guesses.
  Also vulnerable (masked today): `:600-602` (`/jobs/demo`) and `:669` (`/demos/launch`) —
  formals-with-defaults, no length guard; masked because `DemoGallery.jsx:34` posts JSON.
  Same class but benign/loud: `:404-411` — `:408` filters only `is.null`, so a text part named
  `file_interva` passes as `list()` and yields "Failed to read uploaded file".
  SAFE: path params (`:445`, `:737`, `:825`) and JSON-body endpoints (`:86-202`, `:830`).

**Pre-existing unrelated bug spotted nearby:** the `return()` at `plumber.R:261` fires inside
  `tryCatch`'s error HANDLER, so it returns from the anonymous handler and the value is discarded;
  execution continues to `:265` with `job_type` unbound.

**3. `resolve_age_group()` is correct.** Reviewer exercised the real implementation against 22
  inputs: `list()`, `NULL`, `character(0)`, `"   "`, `NA`, `NA_character_`, `list("child")`,
  `list(list("child"))`, factor, data.frame, `"  Child "` all behave. Only environment/closure crash
  with "cannot coerce type", which HTTP cannot deliver.
  ONE REAL MINOR GAP (independently confirmed by the session manager): a repeated query param
  `?age_group=child&age_group=neonate` arrives as `c("child","neonate")` and `value[1]` is taken
  **silently**, contradicting the helper's own "never guess" principle. A
  `if (length(value) > 1) stop(...)` would make it consistent.

**4. `list(error=)` at HTTP 200 is the right convention here.** It matches the `/jobs` family
  exactly (`:265-358`, `:413`, `:449`, `:484`, `:502`, `:619`, `:674`, `:683`, `:742`); only
  auth/admin set `res$status` (`:95-107`, `:130-153`, `:161-168`, `:837`). Since `fetchJson`
  (`client.js:38-50`) throws only on `!res.ok`, the caller must check `result.error` — which
  `JobForm.jsx` already does at `:182`, `:208`, and now `:117`. No change needed.
  REAL WEAKNESS in that path: the message is THROWN AWAY. Both `:117` and `:124` render the same
  fixed string at `JobForm.jsx:359-362` ("Couldn't preview cause mapping (service unavailable)"),
  which is misleading for a rejected `age_group` (nothing is unavailable), and the carefully worded
  `resolve_age_group` message reaches no one — it is not logged server-side either.

**5. Doc fix is half-applied.** The SPEC was corrected but the paired PLAN doc still carries the
  contract that seeded the bug: `docs/superpowers/plans/2026-07-22-cause-mapping-preview.md:191`
  ("Accepts the same multipart args ... age_group"), and its verification commands at `:247` and
  `:258` are `curl -s -F "age_group=neonate"`, which post-fix now return the new error instead of a
  report. `:336` shows the pre-fix `client.js`. Low priority (historical artifact) but it is the doc
  that actually contains the wrong `curl`.

**Note for UAT:** the new error branch is effectively unreachable from the app, since
  `JobForm.jsx:33` always holds `'neonate'|'child'`. It is defense-in-depth for curl/third-party
  clients, so browser testing will not exercise it.

## Resolution

root_cause: >
  A transport mismatch, not a cause-mapping defect. `previewMapping()` sent `age_group` as a
  MULTIPART FORM FIELD. plumber 1.3.2 assigns a multipart text part no Content-Type (and it has no
  filename), so `parser_picker()` falls through to `parsers$alias$form` == `parser_text(parseQS)`.
  `parseQS` interprets the raw part value as a URL-encoded query string, and a bare value like
  `"child"` contains no `=`, so it parses to an EMPTY LIST. `combine_keys(type="multi")` therefore
  set `req$args$age_group <- list()`. At `plumber.R:392` `is.null()` was FALSE but
  `length() == 0` was TRUE, so the silent `age_group <- "neonate"` fallback fired. The child upload
  was then scored against the NEONATE broad-cause list, where `hiv`, `other_infections` and
  `severe_malnutrition` do not exist -> reported unrecognized, `has_errors = TRUE`, and
  `JobForm.jsx:468` disabled the Calibrate button. `submitJob` was never affected because it sends
  all scalars via `URLSearchParams` in the query string.
  A second, compounding defect: the silent `"neonate"` default converted a destroyed required
  parameter into a plausible-but-wrong report, which is exactly why the bug presented as a
  cause-mapping problem rather than a parameter-passing problem.

fix: >
  (1) `frontend/src/api/client.js` - `previewMapping()` now sends `age_group` in the QUERY STRING
  (`/jobs/preview?age_group=...`), matching the convention `submitJob` already proved works, and no
  longer appends it to FormData. This is the root-cause fix.
  (2) `backend/jobs/utils.R` - new `resolve_age_group()` helper: normalizes case/whitespace,
  validates against `neonate`/`child`, and throws a descriptive error on a missing, empty, or
  invalid value. It explicitly treats plumber's `list()` as missing.
  (3) `backend/plumber.R` - `POST /jobs/preview` uses `resolve_age_group()` and returns
  `list(error = ...)` instead of silently defaulting to `"neonate"`.
  (4) `frontend/src/components/JobForm.jsx` - a top-level `error` in the preview response now sets
  the "preview service unavailable" notice instead of being swallowed into an empty report set that
  would have looked like a clean preview.
  (5) Docs/tests updated: the design spec's endpoint contract (which wrongly documented `age_group`
  as a multipart arg and seeded the bug) now states the query-string requirement, and the stale
  assertion in `client.test.js` that enshrined the broken transport was corrected.

verification: >
  Root cause proven by differential experiment before fixing: on the exact issue CSV,
  `preview_cause_mapping(df, "neonate")` reproduces the issue screenshot item-for-item
  (1334/2383, same 3 unrecognized causes and counts, same nonsensical
  diarrhea/malaria -> sepsis_meningitis_inf folding) while `(df, "child")` is clean (2383/2383).
  Over live HTTP against a verbatim mirror of the endpoint on plumber 1.3.2, changing ONLY the
  transport flipped the result, confirming the mechanism.
  After the fix, all six HTTP scenarios behave correctly: query-string child -> clean 2383/2383
  (Calibrate enabled); multipart-only, omitted, and invalid age_group -> loud errors with no silent
  neonate substitution; genuinely-requested neonate -> unchanged; `Child` -> normalized.
  Regression: 240 frontend tests across 32 files pass, eslint clean, production build succeeds,
  backend section 2f 17/17 passes, R syntax checks pass. Every new test was confirmed RED before the
  fix and GREEN after (the JobForm case by stashing only that file).
  CAVEAT NOW CLOSED: the debugger could not boot `Rscript run.R` locally (`RPostgres`/`DBI` not
  installed) and so used a byte-for-byte mirror of the endpoint. The session manager subsequently
  confirmed the mechanism against the LIVE DEPLOYED backend
  (`https://dev.sites.idies.jhu.edu/comsa-dashboard/api`, pre-fix code): multipart `age_group=child`
  returns 1334/2383 matching the issue screenshot item-for-item and is BYTE-IDENTICAL to omitting the
  parameter, while `?age_group=child` returns a clean 2383/2383 with zero unrecognized causes. The
  diagnosis therefore rests on production evidence, not a mirror. Probe B also shows the frontend
  transport fix works against the unpatched deployed backend, so no backend redeploy is required to
  unblock users. Still awaiting browser/UI confirmation that the Calibrate button renders enabled.

files_changed:
  - backend/jobs/utils.R (new resolve_age_group helper)
  - backend/plumber.R (POST /jobs/preview: no silent neonate default)
  - frontend/src/api/client.js (previewMapping sends age_group in query string)
  - frontend/src/components/JobForm.jsx (surface top-level preview error)
  - frontend/src/api/client.issue105.test.js (new regression test)
  - frontend/src/api/client.test.js (corrected stale assertion)
  - frontend/src/components/JobForm.preview.behavior.test.jsx (new regression case)
  - tests/test_vacalibration_backend.R (new section 2f)
  - docs/superpowers/specs/2026-07-22-cause-mapping-preview-design.md (corrected endpoint contract)

## Orchestrator Re-verification (2026-07-28)

Independently re-ran everything rather than trusting the agent's report. All of it holds:

- **Root cause reproduced locally, exactly.** Sourced `backend/jobs/utils.R` and ran
  `preview_cause_mapping()` on the real issue #101 CSV (2383 rows). Scoring it as `child`
  gives 2383/2383 with zero unrecognized and 1:1 mapping; scoring the SAME data as `neonate`
  gives **1334/2383, unrecognized = hiv / other_infections / severe_malnutrition, and
  diarrhea→sepsis_meningitis_inf (473), malaria→sepsis_meningitis_inf (201),
  other→other (134), pneumonia→pneumonia (526)** — a line-for-line, count-for-count match to
  the issue #105 screenshot. 17/17 assertions passed.
- **Frontend suite:** 240 passed / 32 files, 3 skipped. The only failing suite is
  `src/api/integration.test.js` ("Backend failed to start within 30s"), which is environmental:
  `DBI` and `RPostgres` are genuinely not installed in this R library, so
  `backend/run.R` cannot boot. Unrelated to this fix.

### Gap 1 — the new backend regression tests never actually execute

Two independent reasons, both pre-existing and NOT caused by this fix:

1. `tests/test_vacalibration_backend.R` **halts at section 2b** with
   `Error: object 'comsamoz_CCVAoutput' not found`, long before the new section 2f. The installed
   `vacalibration` exposes only `Mmat_champs`, `comsamoz_public_broad`, and
   `comsamoz_public_openVAout` — there is no `comsamoz_CCVAoutput`. It is referenced at 8 sites
   (lines 181, 182, 230, 271, 320, 676, 680) with a nested `$neonate$eava` / `$child[[alg]]`
   shape, so this is a dataset-API migration, not a rename. Note the most recent merge was
   PR #102 "fix/vacalibration-package-datasets", which evidently did not cover this file.
2. `.github/workflows/test.yml` has **only a `frontend` job** — no R job at all — so nothing in
   `tests/` runs in CI regardless.

Consequence: the backend half of the regression guard is currently decorative. The frontend
guard (`client.issue105.test.js`) DOES run in CI (`npx vitest run --exclude
'**/api/integration.test.js'`) and covers the actual user-facing defect — the transport — so the
critical case is protected.

### Follow-up authorized by the user (2026-07-28): harden POST /jobs

The user asked for the same class of defect to be fixed on `POST /jobs`. The nine scalars were
NOT treated uniformly — making them all required would break nothing today but would be wrong,
because five of them are genuine tuning knobs with defensible defaults.

- **Required, never guessed** (they determine WHAT SCIENCE RAN, so a lost value yields a
  confidently wrong calibration): `job_type`, `algorithm`, `age_group`, `country`.
  `country` matters more than it looks — it selects the CHAMPS misclassification matrix stratum.
- **Default kept, value validated** (previously `as.integer("abc")` / `as.logical("yes")` both
  produced `NA` silently): `calib_model_type`, `ensemble`, `n_mcmc`, `n_burn`, `n_thin`.

New helpers in `backend/jobs/utils.R`: `param_scalar`, `require_enum`, `optional_enum`,
`optional_count`, `optional_flag`, `require_algorithms`, plus `VALID_JOB_TYPES`,
`VALID_ALGORITHMS`, `VALID_CALIB_MODEL_TYPES`, `CALIBRATION_COUNTRIES`. `resolve_age_group` now
delegates to `require_enum` (its 11 existing tests still pass unchanged).

Two extras found and fixed while in there:
1. **`param_scalar` rejects conflicting repeated values** instead of quietly taking the first —
   this closes the smaller item recorded above.
2. **The `tryCatch` error handling in `POST /jobs` never worked.** `return()` inside an
   `error = function(e)` handler exits only the handler, so a parse failure fell through and the
   endpoint kept running with unresolved parameters. It now returns the handler's result properly.

Also corrected the docs that *taught* this bug: `backend/README.md` showed
`-F "job_type=..." -F "algorithm=..." -F "age_group=..." -F "country=..."`, i.e. exactly the
multipart pattern plumber discards. It now documents query-string transport plus a
required-vs-optional split. Three stale `-F "age_group=..."` curl examples in
`docs/superpowers/plans/2026-07-22-cause-mapping-preview.md` were fixed too.
(`.claude/skills/test/references/api_reference.md` was already correct.)

Verification (all re-run by the orchestrator, nothing taken on trust):
- Section 2g: **38/38** — new parameter validation, including a drift guard asserting
  `CALIBRATION_COUNTRIES` still equals `names(Mmat_champs$neonate$eava$postmean)`.
- Live endpoint block: **20/20** — the `resolved <- tryCatch(...)` block is *extracted from
  plumber.R at runtime* and executed against fake requests, so the test cannot drift from the
  code. Confirms the exact payload `client.js submitJob` sends still works (single and ensemble),
  each required parameter now errors loudly when lost, and the five knobs still default.
- Issue #105 suite: **17/17** still green after the `resolve_age_group` refactor.
- Frontend, exactly as CI runs it: **240/240 across 32 files**.

Still deliberately NOT done: `POST /jobs/demo` keeps its plumber-signature defaults (a legitimate
pattern for a canned demo, and those DO populate reliably from the query string), but it still
coerces with bare `as.logical()` / `as.integer()`, so garbage there can still become `NA`.
Out of the requested scope; worth a follow-up.

### Gap 2 — browser confirmation needs credentials

`JobForm` sits behind `ProtectedRoute` (`frontend/src/App.jsx:184-189`), so the Submit Job form
requires login. A local backend cannot be started to register a user (`DBI`/`RPostgres` absent),
and the deployed site still serves the pre-fix bundle. So end-to-end browser confirmation is
genuinely blocked on either the user's login or a deploy of the fix — not on further analysis.
The HTTP-level evidence already covers the mechanism: the deployed backend returns
`has_errors: FALSE` for `?age_group=child`, and `has_errors` is the sole input to
`previewHasErrors`, which is what disables the button (`JobForm.jsx:468`).
