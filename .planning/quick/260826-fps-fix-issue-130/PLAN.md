---
phase: quick/260826-fps-fix-issue-130
plan: 01
type: execute
wave: 1
depends_on: []
files_modified:
  - frontend/src/components/CSMFChart.js
  - frontend/src/components/CSMFChart.test.js
  - frontend/src/utils/export.test.js
autonomous: true
requirements: ["#130"]

must_haves:
  truths:
    - "A cause whose credible interval is real but sub-1% never renders as `0% (0–0)` in the CSMF comparison table."
    - "A percent at or above 1% still renders as a bare integer — `22%` stays `22%`, never `22.0%`."
    - "The displayed mean and its bounds share ONE precision rule, so a mean can never print outside its own printed interval."
    - "A genuine point-mass interval (raw lower == upper) is still suppressed entirely — no bounds printed."
    - "The exported CSV carries the same non-zero bound; a cell for a real interval is never `0 (0, 0)`."
    - "A non-zero value too small for 2dp prints as `<0.01`, never as an unqualified `0`."
  artifacts:
    - path: "frontend/src/components/CSMFChart.js"
      provides: "adaptive-precision `pct()` used by all five existing call sites"
      contains: "'<0.01'"
    - path: "frontend/src/components/CSMFChart.test.js"
      provides: "issue #130 regression describe block"
      contains: "issue #130"
    - path: "frontend/src/utils/export.test.js"
      provides: "CSV on-disk regression for the same case"
      contains: "exportConsolidatedCSMF"
  key_links:
    - from: "frontend/src/components/JobDetail.jsx:430-433"
      to: "cell.mean / cell.lower / cell.upper"
      via: "template interpolation — UNCHANGED, inherits the fix"
    - from: "frontend/src/utils/export.js:161-166"
      to: "cell.mean / cell.lower / cell.upper"
      via: "template interpolation — UNCHANGED, inherits the fix"
---

<objective>
GitHub #130: the CSMF comparison table rounds every value with
`Math.round(v * 100)`, so a real credible interval like `lower = 0, upper = 0.0049`
prints as `0% (0–0)` — visually identical to a genuine point mass. The chart draws the
same interval correctly and its tooltip uses `.toFixed(1)`, so chart and table disagree
about the same number.

Purpose: make the table's display precision honest without adding decimal noise to
ordinary values.
Output: one adaptive formatter in `CSMFChart.js`, plus regression tests in the view-model
and on the CSV export path.
</objective>

<decisions>
These are decided here. The executor implements them; it does not re-choose.

**D-01 — One formatter, not two.** Keep the existing function name `pct` and change only
its body. All five current call sites (calibrated mean, uncalibrated mean, lower, upper)
keep calling `pct` — zero call-site churn.

**D-02 — Precision is adaptive, and only kicks in below 1%.** Exact rule, in order:
1. `v == null` → `null` (unchanged, the degenerate/missing path depends on it)
2. `p = v * 100`
3. `p === 0` → `'0'` (an exact zero is exactly zero; no false decimals)
4. `p >= 1` → `String(Math.round(p))` (so `0.22` → `'22'`, `0.42` → `'42'` — identical to
   today's output for every value the user currently sees)
5. `p < 0.01` → `'<0.01'` (a non-zero too small for 2dp must never print as `0`)
6. otherwise → `p.toFixed(2)` (so `0.0049` → `'0.49'`)

This is why the "mean gets noise" objection does not apply: above 1% the new formatter is
byte-identical to `Math.round`. `22%` stays `22%`.

**D-03 — The mean uses the same rule as the bounds. This is mandatory, not optional.**
Fixing only the bounds creates a NEW defect: a mean of `0.0035` would print `0%` beside an
interval of `(0.11–0.49)`, i.e. the point estimate rendered outside its own credible
interval. One rule for mean and bounds makes that impossible.

**D-04 — Return type becomes `string` (or `null`), consistently.** Never a number, never
mixed. Both consumers interpolate into text; a mixed number|string return is the kind of
thing that rots. This is what makes `'<0.01'` expressible at all. Cost: 10 existing
assertions change from `toBe(20)` to `toBe('20')` — they are enumerated in Task 1.

**D-05 — The CSV export keeps its current one-cell `"mean (lower, upper)"` format and
carries the display string, NOT raw fractions.** Reasons: (a) `exportConsolidatedCSMF`
already interpolates `cell.mean/lower/upper` verbatim, so it inherits the fix with zero
code change — the on-disk `0 (0, 0)` defect disappears by construction; (b) switching that
cell to raw fractions would silently change its units from percent to fraction and break
any existing downstream parsing; (c) researchers who need full precision already have it —
the backend writes `calibration_summary.csv` with unrounded values. Do NOT add raw
lower/upper columns; that is feature creep.

**D-06 — `JobDetail.jsx` and `export.js` are NOT edited.** Both already interpolate the
cell fields into a template string, which works unchanged with string values, and both
already null-check with `!= null`. If you find yourself editing either file, stop — the
design is wrong.
</decisions>

<do_not_touch>
Out of scope and already correct — any diff here is a defect:
- `csmfWhisker` and the whisker geometry.
- The degenerate/point-mass suppression rule. The decision stays on the RAW bounds
  (`const degenerate = rawLo == null || rawHi == null || !(rawHi > rawLo)`). Do not move it
  onto formatted/rounded values, and do not weaken it — suppressing a true
  `lower == upper` is deliberate behaviour from the issue #101 R2 work, and the comment
  above it explains why.
- The backend payload and `calibration_summary.csv`.
- `JobDetail.jsx`, `export.js` (see D-06).
</do_not_touch>

<context>
@frontend/src/components/CSMFChart.js
@frontend/src/components/CSMFChart.test.js
@frontend/src/utils/export.test.js
@CLAUDE.md
</context>

<interfaces>
Current shape the executor is changing, from `frontend/src/components/CSMFChart.js:93`:
- `const pct = v => (v == null ? null : Math.round(v * 100))` — 5 call sites, all inside
  `buildCsmfTableRows`.
- Cell shape produced: `{ cause, mean, lower, upper }`. `lower`/`upper` are `null` when the
  raw interval is degenerate.

Consumers (unchanged):
- `frontend/src/components/JobDetail.jsx:430-433` renders
  `cell.mean == null ? '-' : cell.lower != null && cell.upper != null ? mean% (lower–upper) : mean%`
  (note: en dash `–` between bounds).
- `frontend/src/utils/export.js:161-166` writes
  `"mean (lower, upper)"` when both bounds exist, else bare `mean`.

Test environment: vitest, `environment: 'node'` (see `frontend/vite.config.js`) — there is
no jsdom. `export.test.js` already uses `vi.stubGlobal` / `vi.unstubAllGlobals` for
browser-only globals; follow that existing pattern.
</interfaces>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Write the failing #130 tests and restate the existing assertions as strings</name>

  <read_first>
    - frontend/src/components/CSMFChart.test.js (whole file — match its comment style:
      each regression block opens with a `// issue #NNN:` comment saying what broke)
    - frontend/src/components/CSMFChart.js (the `pct` line and `buildCsmfTableRows`)
    - frontend/src/utils/export.test.js (lines 1-20 for the mock style, 133-142 for the
      `vi.stubGlobal` + `afterEach(vi.unstubAllGlobals)` pattern)
    - frontend/src/utils/export.js (`exportConsolidatedCSMF`, `exportToCSV`, `downloadBlob`)
  </read_first>

  <behavior>
    New `describe` in CSMFChart.test.js, named for issue #130, over one fixture built from
    the issue's own UAT case (`prematurity`: lower 0, upper 0.0049), with `pneumonia` as the
    ordinary-value control and `other` as the point-mass control:
    - mean/uncalibrated `prematurity` 0.0021, `pneumonia` 0.30/0.42, `other` 0.013
    - ci_lower: prematurity 0, pneumonia 0.35, other 0.013
    - ci_upper: prematurity 0.0049, pneumonia 0.49, other 0.013

    1. Sub-1% bounds survive: `prem.lower` is `'0'`, `prem.upper` is `'0.49'`,
       `prem.mean` is `'0.21'`.
    2. The rendered composite is not the defect: the JobDetail template
       `${mean}% (${lower}–${upper})` for prematurity equals `'0.21% (0–0.49)'`, and
       `.not.toBe('0% (0–0)')`.
    3. No decimal noise on ordinary values: `pneu.mean` is `'42'`, `pneu.lower` is `'35'`,
       `pneu.upper` is `'49'`, and `expect(pneu.mean).not.toContain('.')`.
    4. Mean and bounds share the rule (the D-03 hazard): the uncalibrated-row prematurity
       mean is also `'0.21'`, not `'0'`.
    5. A bound below 0.01% is disclosed, not zeroed: same fixture with prematurity
       ci_lower `0.00005` yields `lower` === `'<0.01'` (and stays non-degenerate, since
       0.0049 > 0.00005).
    6. Point mass is still suppressed: `other.lower` and `other.upper` are `null`,
       `other.mean` is `'1'`.
    7. Chart and table agree on this case: `csmfWhisker(0.0021, 0, 0.0049)` is not null.

    New `describe` in export.test.js, named for issue #130:
    8. `exportConsolidatedCSMF(buildCsmfTableRows(fixture), 'job1234', 'InterVA')` produces
       CSV text containing `"0.21 (0, 0.49)"` and NOT containing `"0 (0, 0)"`.
  </behavior>

  <action>
    Add the two `describe` blocks above. In export.test.js, import `exportConsolidatedCSMF`
    from `./export.js` and `buildCsmfTableRows` from `../components/CSMFChart.js`, and
    capture the CSV by stubbing the three browser globals `downloadBlob` touches, inside a
    `beforeEach`, with `afterEach(() => vi.unstubAllGlobals())`: stub `Blob` with a plain
    function (invoked with `new`) that records `String(parts[0])` into a module-scope
    variable; stub `URL` with no-op `createObjectURL`/`revokeObjectURL`; stub `document`
    with `createElement` returning an object carrying a no-op `click`, plus a `body` with
    no-op `appendChild`/`removeChild`. Assert on the recorded string.

    Then restate the ten existing assertions in CSMFChart.test.js as strings (D-04) —
    values are unchanged, only the type:
    L80 `40`, L82 `30`, L83 `20`, L84 `42`, L223 `30`, L237 `20`, L238 `42`, L428 `1`,
    L437 `35`, L438 `49` — each becomes the same digits inside single quotes.
    Also rename the test at L78 whose title claims "formats values as integer percents" to
    say integer percents at or above 1% and finer precision below — the old title becomes
    wrong in Task 2.
    Leave every `toBeNull()` / `c.lower !== null` assertion alone: nulls do not change.
  </action>

  <acceptance_criteria>
    - `cd frontend && npx vitest run src/components/CSMFChart.test.js src/utils/export.test.js`
      exits non-zero, with failures ONLY in the new #130 blocks and in the ten restated
      assertions. No other test file is edited.
    - The new CSMFChart.test.js block contains the literal string `'0.21% (0–0.49)'` and the
      literal `'0% (0–0)'` (as the `.not.toBe` argument), using the en dash `–`.
    - The new export.test.js block contains the literal `'"0.21 (0, 0.49)"'`.
    - `git diff --stat` shows exactly two files changed:
      `frontend/src/components/CSMFChart.test.js`, `frontend/src/utils/export.test.js`.
  </acceptance_criteria>

  <verify>
    <automated>cd frontend &amp;&amp; npx vitest run src/components/CSMFChart.test.js src/utils/export.test.js; test $? -ne 0</automated>
  </verify>

  <done>Tests are RED for the #130 case and for the ten restated assertions; no production file touched yet.</done>
</task>

<task type="auto">
  <name>Task 2: Make pct() adaptive so sub-1% values keep their precision</name>

  <read_first>
    - frontend/src/components/CSMFChart.js (lines 93-155: the `pct` definition, the
      `buildCsmfTableRows` JSDoc, and the raw-bounds `degenerate` guard with its comment)
    - frontend/src/components/CSMFChart.test.js (lines 560-586: the retraction guard — it
      scans this file's source, comments included, for forbidden phrases)
  </read_first>

  <action>
    Replace the body of `pct` at CSMFChart.js:93 with the D-02 rule, in that exact order:
    null passthrough; `p = v * 100`; `p === 0` returns `'0'`; `p >= 1` returns
    `String(Math.round(p))`; `p < 0.01` returns `'<0.01'`; otherwise `p.toFixed(2)`.
    Keep the name `pct` and do not touch any of its five call sites.

    Add a short comment above it citing issue #130: integer percent hid a real sub-1%
    interval behind `0% (0–0)`, so precision is added only below 1% (above it the output is
    identical to `Math.round`, so ordinary values gain no decimals), and the mean shares the
    rule so a point estimate can never print outside its own printed interval.

    Update the JSDoc line on `buildCsmfTableRows` that currently reads "All values are
    integer percents." to state the new rule and the string return type.

    Comment-wording constraint: the retraction guard in CSMFChart.test.js lowercases this
    file's source and asserts it contains none of `ci_unreliable`, `ciunreliable`,
    `implausibly`, `not meaningful`, `falsely`, `intervals omitted`, `7x`. Do not use any of
    those substrings — in particular write "false precision", never "falsely".

    Change nothing else in this file. The `degenerate` guard and its comment stay exactly
    as they are (it decides on RAW bounds; `pct` remains display-only).
  </action>

  <acceptance_criteria>
    - `cd frontend && npm test` → 0 failed, 0 skipped; the previously-passing files all
      still pass (do not quote a fixed total; assert zero failures).
    - `cd frontend && npm run build` exits 0.
    - `cd frontend && npm run lint` reports exactly 4 errors, all in
      `frontend/src/auth/AuthContext.jsx` (the documented pre-existing baseline). Any error
      in `CSMFChart.js` is a regression.
    - `grep -n "Math.round" frontend/src/components/CSMFChart.js` returns exactly one hit,
      inside `pct`.
    - `git diff --name-only` does not list `frontend/src/components/JobDetail.jsx` or
      `frontend/src/utils/export.js` (D-06).
    - `git diff frontend/src/components/CSMFChart.js` shows no change to the line
      `const degenerate = rawLo == null || rawHi == null || !(rawHi > rawLo);` nor to the
      comment block above it.
  </acceptance_criteria>

  <verify>
    <automated>cd frontend &amp;&amp; npm test &amp;&amp; npm run build</automated>
  </verify>

  <done>The table prints `0.21% (0–0.49)` for the issue's case, `22%` still prints as `22%`, point masses still print no interval, and the CSV carries `"0.21 (0, 0.49)"`.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| backend JSON → frontend view-model | Already crossed upstream by `api/client.js unbox()`; this change adds no new boundary. |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-130-01 | Information disclosure | `pct()` output rendered into the DOM and CSV | accept | Output is a formatted numeric string derived from values already displayed; no new data is surfaced and no user input is echoed. |
| T-130-02 | Tampering | `pct()` receives a non-number from the wire | accept | Values reach `pct` only via `calibrated_csmf`/`calibrated_ci_*`; a non-number yields `NaN`-derived text at worst, never code execution. The existing `== null` guard is retained unchanged. |
</threat_model>

<verification>
1. `cd frontend && npm test` → 0 failed, 0 skipped.
2. `cd frontend && npm run build` → exit 0.
3. `cd frontend && npm run lint` → 4 errors, all in `src/auth/AuthContext.jsx`.
4. `git diff --name-only` lists exactly: `frontend/src/components/CSMFChart.js`,
   `frontend/src/components/CSMFChart.test.js`, `frontend/src/utils/export.test.js`.
5. Backend R suite is untouched by this change; do not run it.
</verification>

<success_criteria>
- A real sub-1% credible interval renders as `0.21% (0–0.49)`, never `0% (0–0)`.
- Values at or above 1% render byte-identically to before (`22%`, not `22.0%`).
- A non-zero value below 0.01% renders `<0.01`, never `0`.
- A raw point-mass interval still renders with no bounds at all.
- The exported CSV cell for the same case reads `"0.21 (0, 0.49)"`.
- Nothing in `<do_not_touch>` has a diff.
</success_criteria>

<output>
After completion, create
`.planning/quick/260826-fps-fix-issue-130/SUMMARY.md`.
</output>
