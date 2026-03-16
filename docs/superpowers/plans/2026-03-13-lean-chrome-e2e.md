# Lean Chrome E2E Protocol Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rewrite Chrome E2E test documentation to use a lean protocol (fewer screenshots, structured tool checks) and add pre-flight context awareness, preventing the 20MB API request limit error.

**Architecture:** Documentation-only changes across 3 files in `.claude/skills/test/`. No code changes.

**Tech Stack:** Markdown documentation

**Spec:** `docs/superpowers/specs/2026-03-13-lean-chrome-e2e-design.md`

---

## Chunk 1: Implementation

### Task 1: Rewrite `chrome_e2e.md` with lean protocol

**Files:**
- Modify: `.claude/skills/test/references/chrome_e2e.md` (full rewrite)

- [ ] **Step 1: Rewrite chrome_e2e.md**

Replace the entire file with the lean protocol version. Key changes:
- Add "Tool Selection Hierarchy" section at top
- Add "Pre-flight Context Check" section
- Keep existing file upload script and test data table unchanged
- Rewrite Tests A-D with explicit tool choices per step (max 2 screenshots each)

New content:

```markdown
# Chrome E2E Browser Tests (Manual)

Manual E2E testing via Chrome browser automation (`mcp__claude-in-chrome__*` tools). Requires the app running locally or deployed. Use Playwright (SKILL.md section 7) for reproducible tests; use Chrome E2E for exploratory or visual testing.

## Tool Selection Hierarchy

For each verification step, use the lightest tool that gets the job done:

| Priority | Tool | Use when | Response size |
|----------|------|----------|---------------|
| 1st | `find` | Checking if a specific element exists (button, label, message) | ~1KB |
| 2nd | `read_page` | Checking page structure or multiple elements at once | ~5-20KB |
| 3rd | `javascript_tool` | Reading specific DOM values (text content, input values, row counts) | ~1KB |
| 4th | `computer(screenshot)` | Visual layout verification that cannot be checked structurally | ~300-800KB |

**Hard cap: max 2 screenshots per test.** Use `find`/`read_page` for all other checks.

## Pre-flight Context Check

Before starting Chrome E2E, assess the session's context load:

- If this session has already made **>10 tool calls** (Bash, Edit, Read, etc.), warn the user:
  > "This session has substantial prior context. Chrome E2E tests add ~1-2MB per test. Recommend starting a fresh session to avoid the 20MB API request limit."
- This is a **warning, not a hard block** — the user decides whether to continue or start fresh.

## File Upload Script

Browser security prevents setting file inputs programmatically. Use JavaScript to fetch the CSV from the public URL and attach via DataTransfer API:

```js
(async () => {
  const resp = await fetch('/comsa-dashboard/sample_interva_neonate.csv');
  const blob = await resp.blob();
  const file = new File([blob], 'sample_interva_neonate.csv', { type: 'text/csv' });
  const dt = new DataTransfer();
  dt.items.add(file);
  document.querySelector('input[type="file"]').files = dt.files;
  document.querySelector('input[type="file"]').dispatchEvent(new Event('change', { bubbles: true }));
})();
```

Adjust the filename in both `fetch()` and `new File()` for other sample files.

## Test Data (all in `frontend/public/`)

| File | Format | Used by modes |
|------|--------|---------------|
| `sample_openva_neonate.csv` | WHO2016 (350+ indicator columns, y/n/.) | pipeline, openva |
| `sample_openva_child.csv` | WHO2016 (350+ indicator columns, y/n/.) | pipeline, openva |
| `sample_interva_neonate.csv` | ID + cause (1190 records) | vacalibration |
| `sample_insilicova_neonate.csv` | ID + cause (1190 records) | vacalibration |
| `sample_eava_neonate.csv` | ID + cause (1190 records) | vacalibration |

## Test A — vacalibration mode (fastest, no openVA)

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/` (or deployed URL)
2. **Verify app loaded**: `find` → look for "Submit Job" tab
3. **Set form**: Select "Calibration Only", algorithm "InterVA", age group "Neonate", country "Mozambique"
4. **Upload file**: `javascript_tool` → run the file upload script (with `sample_interva_neonate.csv`)
5. **Verify file attached**: `find` → look for filename next to file input
6. **Submit**: Click "Calibrate" button
7. **Verify job created**: `find` → look for job ID or status indicator
8. **Poll until complete**: `find` or `javascript_tool` → check job status text until "completed"
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of CSMF chart + results layout
10. **Verify result values**: `read_page` → check CSMF table has expected columns (Uncalibrated, Calibrated, 95% CI)
11. **Test CSV export**: `javascript_tool` → trigger export, verify response

## Test B — pipeline mode (openVA + vacalibration)

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Submit Job" tab
3. **Set form**: Select "Pipeline", algorithm "InterVA"
4. **Upload file**: `javascript_tool` → file upload script (with `sample_openva_neonate.csv`)
5. **Verify file attached**: `find` → filename visible
6. **Submit**: Click "Calibrate"
7. **Verify job created**: `find` → job ID visible
8. **Poll until complete**: `find` or `javascript_tool` → status shows "completed" (longer wait — includes openVA)
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of results page
10. **Verify results**: `read_page` → check both openVA CSMF and calibrated CSMF sections present

## Test C — openva mode (classification only)

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Submit Job" tab
3. **Set form**: Select "OpenVA Only", algorithm "InterVA"
4. **Upload file**: `javascript_tool` → file upload script (with `sample_openva_neonate.csv`)
5. **Verify file attached**: `find` → filename visible
6. **Submit**: Click submit button
7. **Verify job created**: `find` → job ID visible
8. **Poll until complete**: `find` or `javascript_tool` → status shows "completed"
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of openVA CSMF results
10. **Verify results**: `read_page` → openVA CSMF present, no calibration results

## Test D — Demo Gallery flow

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Demo Gallery" tab
3. **Click Demo Gallery tab**: `find` → click the tab
4. **Select a demo**: `find` → pick a scenario, click "Launch"
5. **Verify job created**: `find` → job appears in job list
6. **Poll until complete**: `find` or `javascript_tool` → status shows "completed"
7. **Screenshot #1** (results): `computer(screenshot)` → visual check of demo results
```

- [ ] **Step 2: Review the rewritten file**

Read back `.claude/skills/test/references/chrome_e2e.md` and verify:
- Tool hierarchy table is present at top
- Pre-flight check section is present
- File upload script and test data table are preserved
- Each test has explicit tool annotations per step
- No test has more than 2 `computer(screenshot)` steps

- [ ] **Step 3: Commit**

```bash
git add .claude/skills/test/references/chrome_e2e.md
git commit -m "docs: rewrite Chrome E2E tests with lean protocol

Use find/read_page instead of screenshots for most verifications.
Hard cap of 2 screenshots per test. Add pre-flight context check
to warn when session has >10 prior tool calls.

Ref: docs/superpowers/specs/2026-03-13-lean-chrome-e2e-design.md"
```

### Task 2: Update `SKILL.md` Section 8 and debugging table

**Files:**
- Modify: `.claude/skills/test/SKILL.md:142-146` (Section 8)
- Modify: `.claude/skills/test/SKILL.md:224` (debugging table row)

- [ ] **Step 4: Update Section 8 in SKILL.md**

Replace lines 142-146 (Section 8: Chrome E2E Browser Tests) with:

```markdown
### 8. Chrome E2E Browser Tests (Manual)

Manual E2E testing via Chrome browser automation (`mcp__claude-in-chrome__*` tools). Use Playwright (section 7) for reproducible tests; use Chrome E2E for exploratory or visual testing.

**Lean protocol**: Use `find`/`read_page` for most checks; screenshots only for visual layout verification (max 2 per test). If this session has >10 prior tool calls, warn before starting — context accumulation can hit the 20MB API limit.

For detailed test procedures (Tests A-D), tool selection hierarchy, file upload scripts, and test data reference, consult `references/chrome_e2e.md`.
```

- [ ] **Step 5: Update debugging table row in SKILL.md**

Replace line 224 (the "Request too large" row) with:

```markdown
| "Request too large (max 20MB)" | Context accumulation (screenshots + prior tool results) | Use lean protocol (find/read_page over screenshots); start fresh session if >10 prior tool calls |
```

- [ ] **Step 6: Review SKILL.md changes**

Read back `.claude/skills/test/SKILL.md` lines 142-146 and line 224. Verify:
- Section 8 mentions the lean protocol and the >10 tool call heuristic
- Debugging table row has updated cause and fix text
- No other sections were accidentally modified

- [ ] **Step 7: Commit**

```bash
git add .claude/skills/test/SKILL.md
git commit -m "docs: update SKILL.md with lean Chrome E2E protocol refs

Section 8 now references lean protocol and pre-flight check.
Debugging table row for 20MB error updated with root cause."
```

### Task 3: Update `common_failures.md` with root cause and prevention

**Files:**
- Modify: `.claude/skills/test/references/common_failures.md` (add new section at end of Frontend Failures)

- [ ] **Step 8: Add Chrome E2E context limit section to common_failures.md**

Add the following section after the "MCMC Parameter Input Bugs" section (after line 106), before "## Debugging Strategies":

```markdown
### "Request too large (max 20MB)" (Chrome E2E)
- **Error**: `"Request too large (max 20MB). Double press esc to go back and try with a smaller file."`
- **Cause**: The Anthropic API rejects requests whose JSON body exceeds 20MB. During Chrome E2E tests, context accumulates from: (1) screenshots (~300-800KB each in base64), (2) prior tool results from earlier work in the same session (Bash output, file reads, edits). A session that ran other tests and edits before Chrome E2E can easily exceed 20MB after just 3-4 screenshots.
- **Prevention**:
  1. Follow the **lean protocol** in `references/chrome_e2e.md` — use `find`/`read_page` instead of screenshots for most verifications (max 2 screenshots per test)
  2. Check session context before starting: if >10 tool calls have already been made, warn and consider starting a fresh session
  3. Run at most one Chrome E2E test per session
- **Recovery**: Start a fresh Claude Code session and run the Chrome E2E test as the first (or only) task
```

- [ ] **Step 9: Review common_failures.md changes**

Read back `.claude/skills/test/references/common_failures.md` lines 107-120. Verify:
- New section is properly placed between "MCMC Parameter Input Bugs" and "Debugging Strategies"
- Root cause explanation mentions base64 sizes, prior tool results, and the 20MB limit
- Prevention steps reference the lean protocol
- No existing sections were modified

- [ ] **Step 10: Commit**

```bash
git add .claude/skills/test/references/common_failures.md
git commit -m "docs: add 20MB error root cause and prevention to common_failures

Explains context accumulation (screenshots + prior work) as root cause.
References lean protocol as prevention strategy."
```

### Task 4: Final verification

- [ ] **Step 11: Verify all three files are consistent**

Read these sections and confirm cross-references are correct:
- `chrome_e2e.md` → tool hierarchy + pre-flight check + lean test procedures
- `SKILL.md:142-146` → references `chrome_e2e.md` and mentions lean protocol
- `SKILL.md:224` → debugging table matches the root cause in `common_failures.md`
- `common_failures.md` → references `chrome_e2e.md` for the lean protocol

- [ ] **Step 12: Final commit (if any fixups needed)**

Only if step 11 found inconsistencies. Otherwise skip.
