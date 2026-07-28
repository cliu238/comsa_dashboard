# Cause-Mapping Preview Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show the user, before job submission, how their uploaded causes map to broad categories — which records are excluded, which causes are unrecognized (with suggestions), and the true calibrated denominator — using the same backend R helpers the real job uses.

**Architecture:** A backend R helper (`preview_cause_mapping`) classifies each unique uploaded cause by probing the existing mapping units, and returns a plain report. A thin `POST /jobs/preview` endpoint runs it per uploaded file (no job row, no MCMC). The frontend calls it on file attach and renders a per-algorithm preview panel that blocks Submit on unrecognized causes and warns on undetermined exclusions.

**Tech Stack:** R (plumber), React (vitest), existing helpers in `backend/jobs/utils.R`.

## Global Constraints

- Simplest code and structure; no over-engineering; no feature creep (per CLAUDE.md).
- The frontend must NOT re-implement cause mapping — all mapping comes from the backend.
- Never silently drop records: undetermined exclusions and unrecognized causes must both be surfaced.
- `UNDETERMINED_CAUSES <- c("unspecified")` (case-insensitive) is the undetermined label set.
- Neonate broad causes: `congenital_malformation, pneumonia, sepsis_meningitis_inf, ipre, other, prematurity`. Child: `malaria, pneumonia, diarrhea, severe_malnutrition, hiv, injury, other, other_infections, nn_causes`.

---

### Task 1: Backend cause classification + preview report

**Files:**
- Modify: `backend/jobs/utils.R` (add `classify_cause`, `preview_cause_mapping` near the other cause helpers)
- Test: `tests/test_vacalibration_backend.R` (new section "2e", runs in `--input-only`)

**Interfaces:**
- Consumes (existing): `UNDETERMINED_CAUSES`, `is_broad_format`, `build_broad_matrix`, `safe_cause_map`, `fix_causes_for_vacalibration`, `get_broad_causes`, `normalize_cause`, `suggest_closest`.
- Produces:
  - `classify_cause(cause, age_group)` → broad cause name (chr) or `NA_character_`.
  - `preview_cause_mapping(input_data, age_group)` → list with fields: `total_records` (int), `calibrated_denominator` (int), `excluded_undetermined` (list of `{cause, count}`), `unrecognized` (list of `{cause, count, suggestion}`; `suggestion` is chr or `NULL`), `mapping` (list of `{input_cause, broad_cause, count}`), `has_errors` (logical).

- [ ] **Step 1: Write the failing tests**

Add before the `# 3. INPUT DATA VALIDATION -- Backend RDS sample data` section header:

```r
# =============================================================================
# 2e. INPUT DATA VALIDATION -- preview_cause_mapping report
# =============================================================================
section("2e. preview_cause_mapping report")

# EAVA neonate package data: 250 Unspecified excluded, rest recognized.
eava_prev <- as.data.frame(comsamoz_CCVAoutput$neonate$eava)
eava_prev$ID <- as.character(eava_prev$ID)
rep_eava <- preview_cause_mapping(eava_prev, "neonate")
test("preview: total_records is full upload count", rep_eava$total_records == 1190)
test("preview: 250 Unspecified excluded",
     length(rep_eava$excluded_undetermined) == 1 &&
     rep_eava$excluded_undetermined[[1]]$cause == "Unspecified" &&
     rep_eava$excluded_undetermined[[1]]$count == 250)
test("preview: no unrecognized causes in clean package data",
     length(rep_eava$unrecognized) == 0 && isFALSE(rep_eava$has_errors))
test("preview: calibrated denominator excludes Unspecified (940)",
     rep_eava$calibrated_denominator == 940)
test("preview: mapping rows sum to the calibrated denominator",
     sum(vapply(rep_eava$mapping, function(m) m$count, integer(1))) == 940)

# A deliberately misspelled cause must be flagged unrecognized with a suggestion.
bad_df <- data.frame(ID = as.character(1:5),
                     cause = c("Prematurity", "Pnemonia", "Pnemonia", "Neonatal sepsis", "Birth asphyxia"),
                     stringsAsFactors = FALSE)
rep_bad <- preview_cause_mapping(bad_df, "neonate")
test("preview: misspelled cause is unrecognized and blocks (has_errors)",
     rep_bad$has_errors &&
     any(vapply(rep_bad$unrecognized, function(u) u$cause == "Pnemonia" && u$count == 2, logical(1))))
test("preview: unrecognized cause carries a spelling suggestion",
     any(vapply(rep_bad$unrecognized,
                function(u) u$cause == "Pnemonia" && !is.null(u$suggestion) && nzchar(u$suggestion),
                logical(1))))

# Consistency: preview's recognized denominator == job-path mapped rows, for
# every bundled dataset (both age groups, all algorithms). This is the anti-drift
# guarantee: the preview must agree with what the real job will calibrate.
for (age in c("neonate", "child")) {
  for (alg in c("interva", "insilicova", "eava")) {
    d <- as.data.frame(comsamoz_CCVAoutput[[age]][[alg]])
    if ("cause1" %in% names(d) && !"cause" %in% names(d)) names(d)[names(d) == "cause1"] <- "cause"
    d$ID <- as.character(d$ID)
    rep <- preview_cause_mapping(d, age)
    dropped <- drop_undetermined_causes(d)
    vb <- if (is_broad_format(dropped$cause, age)) build_broad_matrix(dropped, age)
          else safe_cause_map(fix_causes_for_vacalibration(dropped), age)
    job_denom <- sum(rowSums(vb) > 0)
    test(sprintf("preview denominator matches job path for %s/%s", age, alg),
         rep$calibrated_denominator == job_denom)
  }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd "$(git rev-parse --show-toplevel)" && Rscript tests/test_vacalibration_backend.R --input-only 2>&1 | grep -E "2e\.|preview|FAIL"`
Expected: FAIL — `could not find function "preview_cause_mapping"`.

- [ ] **Step 3: Implement the helpers**

In `backend/jobs/utils.R`, after `drop_undetermined_causes` (and before `safe_cause_map`), add:

```r
# Classify a single cause into its broad category by probing the SAME mapping
# units the job path uses. Returns the broad cause name, or NA if the cause maps
# to nothing (unrecognized). cause_map() throws on unrecognized causes, so this
# probes one cause at a time and treats a throw / all-zero row as unrecognized.
classify_cause <- function(cause, age_group) {
  df <- data.frame(ID = "__probe__", cause = cause, stringsAsFactors = FALSE)
  m <- tryCatch(
    if (is_broad_format(df$cause, age_group)) build_broad_matrix(df, age_group)
    else safe_cause_map(fix_causes_for_vacalibration(df), age_group),
    error = function(e) NULL)
  if (is.null(m) || !("__probe__" %in% rownames(m))) return(NA_character_)
  row <- m["__probe__", ]
  if (sum(row) == 0) return(NA_character_)
  colnames(m)[which(row == 1)[1]]
}

# Build a pre-submit mapping report for uploaded data, WITHOUT running MCMC.
# Mirrors the job path: undetermined causes are excluded (matching cause_map),
# each remaining unique cause is classified, and unrecognized causes are reported
# (never silently dropped). See docs/superpowers/specs/2026-07-22-cause-mapping-preview-design.md
preview_cause_mapping <- function(input_data, age_group) {
  if ("cause1" %in% names(input_data) && !"cause" %in% names(input_data)) {
    names(input_data)[names(input_data) == "cause1"] <- "cause"
  }
  if (!all(c("ID", "cause") %in% names(input_data))) {
    stop("Input must have 'ID' and 'cause' columns (or 'ID' and 'cause1').", call. = FALSE)
  }
  input_data$ID <- as.character(input_data$ID)
  total_records <- nrow(input_data)

  # Undetermined exclusions (dropped by vacalibration::cause_map by design)
  undet_mask <- tolower(trimws(input_data$cause)) %in% UNDETERMINED_CAUSES
  undet_tab <- table(input_data$cause[undet_mask])
  excluded_undetermined <- lapply(names(undet_tab), function(cn)
    list(cause = cn, count = as.integer(undet_tab[[cn]])))

  kept <- input_data[!undet_mask, , drop = FALSE]
  counts <- table(kept$cause)
  expected <- get_broad_causes(age_group)

  mapping <- list()
  unrecognized <- list()
  denom <- 0L
  for (cn in names(counts)) {
    broad <- classify_cause(cn, age_group)
    n <- as.integer(counts[[cn]])
    if (is.na(broad)) {
      s <- suggest_closest(normalize_cause(cn), expected)
      unrecognized[[length(unrecognized) + 1L]] <-
        list(cause = cn, count = n, suggestion = if (is.na(s)) NULL else s)
    } else {
      mapping[[length(mapping) + 1L]] <-
        list(input_cause = cn, broad_cause = broad, count = n)
      denom <- denom + n
    }
  }

  list(
    total_records = total_records,
    calibrated_denominator = denom,
    excluded_undetermined = excluded_undetermined,
    unrecognized = unrecognized,
    mapping = mapping,
    has_errors = length(unrecognized) > 0
  )
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd "$(git rev-parse --show-toplevel)" && Rscript tests/test_vacalibration_backend.R --input-only 2>&1 | grep -E "2e\.|preview|FAIL"; echo "---"; Rscript tests/test_vacalibration_backend.R --input-only 2>&1 | grep -E "Tests: "`
Expected: all `2e.` lines PASS; overall `Failed: 0`.

- [ ] **Step 5: Commit**

```bash
cd "$(git rev-parse --show-toplevel)"
git add backend/jobs/utils.R tests/test_vacalibration_backend.R
git commit -m "feat: preview_cause_mapping report helper for pre-submit cause preview"
```

---

### Task 2: Backend POST /jobs/preview endpoint

**Files:**
- Modify: `backend/plumber.R` (add endpoint after `POST /jobs`, before `GET /jobs/<job_id>/status`)

**Interfaces:**
- Consumes: `preview_cause_mapping` (Task 1), `save_uploaded_file` (existing, `backend/plumber.R:19`).
- Produces: `POST /jobs/preview` → JSON `{ reports: { <algo>: <report> } }`, or `{ error: <msg> }`. Files are multipart, exactly as `POST /jobs` takes them: `file` (single) or `file_interva`/`file_insilicova`/`file_eava` (multi). **CORRECTION (issue #105): `age_group` must go in the QUERY STRING, not multipart.** As written here it was sent as a multipart field, which plumber discards (a text part gets no Content-Type, so `parseQS` turns a bare `neonate` into an empty list) — the endpoint then defaulted to `neonate` and mis-scored every child upload.

- [ ] **Step 1: Add the endpoint**

In `backend/plumber.R`, immediately before the `#* Get job status` block, add:

```r
#* Preview cause mapping for uploaded file(s) without creating a job
#* @post /jobs/preview
function(req) {
  age_group <- req$args$age_group
  if (is.null(age_group) || length(age_group) == 0) age_group <- "neonate"

  # Collect uploaded files keyed by algorithm (mirror POST /jobs arg names)
  file_map <- list(
    interva     = req$args$file_interva,
    insilicova  = req$args$file_insilicova,
    eava        = req$args$file_eava
  )
  file_map <- file_map[!vapply(file_map, is.null, logical(1))]
  if (length(file_map) == 0 && !is.null(req$args$file)) {
    file_map <- list(uploaded = req$args$file)
  }
  if (length(file_map) == 0) {
    return(list(error = "No file provided for preview"))
  }

  tmp_dir <- file.path(tempdir(), paste0("preview_", uuid::UUIDgenerate()))
  dir.create(tmp_dir, recursive = TRUE, showWarnings = FALSE)
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  reports <- list()
  for (algo in names(file_map)) {
    path <- file.path(tmp_dir, paste0(algo, ".csv"))
    if (!save_uploaded_file(file_map[[algo]], path)) {
      return(list(error = paste("Failed to read uploaded file for:", algo)))
    }
    df <- tryCatch(read.csv(path, stringsAsFactors = FALSE),
                   error = function(e) NULL)
    if (is.null(df)) {
      return(list(error = paste("Could not parse CSV for:", algo)))
    }
    reports[[algo]] <- tryCatch(
      preview_cause_mapping(df, age_group),
      error = function(e) list(error = conditionMessage(e)))
  }
  list(reports = reports)
}
```

- [ ] **Step 2: Restart backend and verify with curl**

```bash
cd "$(git rev-parse --show-toplevel)"
lsof -ti:8000 | xargs kill 2>/dev/null; sleep 1
(cd backend && Rscript run.R > /tmp/comsa_backend.log 2>&1 &); sleep 6
curl -s -F "file=@frontend/public/sample_eava_neonate.csv" \
  "http://localhost:8000/jobs/preview?age_group=neonate" | head -c 600
```
Expected: JSON containing `"reports"` → `"uploaded"` → `total_records`, `calibrated_denominator`, `mapping`. (The frontend sample is already scrubbed of Unspecified, so `excluded_undetermined` is `[]` and `has_errors` is `false`.) If the response is `{"error":"Missing or invalid Authorization header"}`, the server has grace period off — re-run with a token from `POST /auth/login`.

- [ ] **Step 3: Verify undetermined exclusion path via curl**

```bash
cd "$(git rev-parse --show-toplevel)"
printf 'ID,cause\n1,Prematurity\n2,Unspecified\n3,Neonatal sepsis\n' > /tmp/prev_unspec.csv
curl -s -F "file=@/tmp/prev_unspec.csv" \
  "http://localhost:8000/jobs/preview?age_group=neonate"
```
Expected: `excluded_undetermined` lists `Unspecified` count 1; `calibrated_denominator` is 2; `has_errors` false.

- [ ] **Step 4: Commit**

```bash
cd "$(git rev-parse --show-toplevel)"
git add backend/plumber.R
git commit -m "feat: POST /jobs/preview endpoint for pre-submit cause mapping"
```

---

### Task 3: Frontend API client previewMapping

**Files:**
- Modify: `frontend/src/api/client.js` (add `previewMapping`)
- Test: `frontend/src/api/client.test.js` (add a case)

**Interfaces:**
- Consumes: `POST /jobs/preview`, existing `API_BASE`, `fetchJson` pattern, existing `submitJob` FormData convention (`file_<algo>` for multi, `file` for single).
- Produces: `previewMapping({ uploads, ageGroup })` → resolves to `{ reports: { <algo>: report } }`. `uploads` is the JobForm array `[{ algorithm, file }]`.

- [ ] **Step 1: Write the failing test**

In `frontend/src/api/client.test.js`, add:

```js
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { previewMapping } from './client';

describe('previewMapping', () => {
  beforeEach(() => { vi.restoreAllMocks(); });

  it('posts one file per algorithm and returns reports', async () => {
    const fetchMock = vi.spyOn(global, 'fetch').mockResolvedValue({
      ok: true,
      json: async () => ({ reports: { interva: { total_records: 3, has_errors: false } } }),
    });
    const file = new File(['ID,cause\n1,Prematurity\n'], 'interva.csv', { type: 'text/csv' });
    const res = await previewMapping({
      uploads: [{ algorithm: 'InterVA', file }],
      ageGroup: 'neonate',
    });
    expect(res.reports.interva.total_records).toBe(3);
    const [url, opts] = fetchMock.mock.calls[0];
    expect(url).toContain('/jobs/preview');
    expect(opts.method).toBe('POST');
    expect(opts.body.get('file_interva')).toBeInstanceOf(File);
    expect(opts.body.get('age_group')).toBe('neonate');
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && VITE_API_BASE=http://localhost:8001 npx vitest run src/api/client.test.js -t previewMapping`
Expected: FAIL — `previewMapping is not a function` / import error.

- [ ] **Step 3: Implement previewMapping**

In `frontend/src/api/client.js`, add (mirroring `submitJob`'s FormData convention):

```js
export async function previewMapping({ uploads, ageGroup }) {
  const formData = new FormData();
  formData.append('age_group', ageGroup);
  const withFiles = uploads.filter((u) => u.file && u.algorithm);
  if (withFiles.length === 1) {
    formData.append('file', withFiles[0].file);
    formData.append(`file_${withFiles[0].algorithm.toLowerCase()}`, withFiles[0].file);
  } else {
    withFiles.forEach((u) => {
      formData.append(`file_${u.algorithm.toLowerCase()}`, u.file);
    });
  }
  return fetchJson(`${API_BASE}/jobs/preview`, { method: 'POST', body: formData });
}
```

Note: the single-file branch appends BOTH `file` and `file_<algo>` so the endpoint keys the report by the algorithm name in both single and multi cases.

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && VITE_API_BASE=http://localhost:8001 npx vitest run src/api/client.test.js -t previewMapping`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
cd "$(git rev-parse --show-toplevel)"
git add frontend/src/api/client.js frontend/src/api/client.test.js
git commit -m "feat: previewMapping API client for cause preview"
```

---

### Task 4: Frontend CausePreview panel + JobForm integration

**Files:**
- Create: `frontend/src/components/CausePreview.jsx`
- Create: `frontend/src/components/CausePreview.test.jsx`
- Modify: `frontend/src/components/JobForm.jsx` (fetch preview on file attach; block Submit on `has_errors`)

**Interfaces:**
- Consumes: `previewMapping` (Task 3), report shape from Task 1.
- Produces: `CausePreview({ report, algorithmLabel })` React component. JobForm holds `previewReports` (map algo→report) and `previewHasErrors` (bool) state; Submit disabled when `previewHasErrors`.

- [ ] **Step 1: Write the failing test for CausePreview**

Create `frontend/src/components/CausePreview.test.jsx`:

```jsx
import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import CausePreview from './CausePreview';

describe('CausePreview', () => {
  it('shows denominator headline and excluded warning', () => {
    render(<CausePreview algorithmLabel="EAVA" report={{
      total_records: 1190, calibrated_denominator: 940,
      excluded_undetermined: [{ cause: 'Unspecified', count: 250 }],
      unrecognized: [], mapping: [{ input_cause: 'Preterm', broad_cause: 'prematurity', count: 164 }],
      has_errors: false,
    }} />);
    expect(screen.getByText(/940 of 1190/)).toBeInTheDocument();
    expect(screen.getByText(/250/)).toBeInTheDocument();
    expect(screen.getByText(/Unspecified/)).toBeInTheDocument();
  });

  it('shows unrecognized causes with suggestion as an error', () => {
    render(<CausePreview algorithmLabel="InterVA" report={{
      total_records: 5, calibrated_denominator: 3,
      excluded_undetermined: [],
      unrecognized: [{ cause: 'Pnemonia', count: 2, suggestion: 'pneumonia' }],
      mapping: [], has_errors: true,
    }} />);
    expect(screen.getByText(/Pnemonia/)).toBeInTheDocument();
    expect(screen.getByText(/pneumonia/)).toBeInTheDocument();
    expect(screen.getByText(/unrecognized/i)).toBeInTheDocument();
  });
});
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && VITE_API_BASE=http://localhost:8001 npx vitest run src/components/CausePreview.test.jsx`
Expected: FAIL — cannot resolve `./CausePreview`.

- [ ] **Step 3: Implement CausePreview**

Create `frontend/src/components/CausePreview.jsx`:

```jsx
// Renders the backend's cause-mapping report for one algorithm. Purely
// presentational — all mapping decisions come from the backend report.
export default function CausePreview({ report, algorithmLabel }) {
  if (!report) return null;
  if (report.error) {
    return <div className="cause-preview error" role="alert">{algorithmLabel}: {report.error}</div>;
  }
  const { total_records, calibrated_denominator, excluded_undetermined = [],
          unrecognized = [], mapping = [] } = report;
  return (
    <div className={`cause-preview${unrecognized.length ? ' has-errors' : ''}`}>
      <p className="cause-preview-headline">
        <strong>{algorithmLabel}:</strong> {calibrated_denominator} of {total_records} records will be calibrated.
      </p>

      {unrecognized.length > 0 && (
        <div className="cause-preview-unrecognized" role="alert">
          <p>{unrecognized.length} unrecognized cause(s) — fix these before submitting:</p>
          <ul>
            {unrecognized.map((u) => (
              <li key={u.cause}>
                “{u.cause}” ({u.count} records)
                {u.suggestion ? <> — did you mean <em>{u.suggestion}</em>?</> : <> — no close match; relabel to a supported cause.</>}
              </li>
            ))}
          </ul>
        </div>
      )}

      {excluded_undetermined.length > 0 && (
        <p className="cause-preview-excluded" role="status">
          Excluded (undetermined cause, per vacalibration methodology):{' '}
          {excluded_undetermined.map((e) => `${e.cause} (${e.count})`).join(', ')}.
        </p>
      )}

      {mapping.length > 0 && (
        <table className="cause-preview-table">
          <thead><tr><th>Your cause</th><th>Maps to</th><th>Records</th></tr></thead>
          <tbody>
            {mapping.map((m) => (
              <tr key={m.input_cause}>
                <td>{m.input_cause}</td><td>{m.broad_cause}</td><td>{m.count}</td>
              </tr>
            ))}
          </tbody>
        </table>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run the CausePreview test to verify it passes**

Run: `cd frontend && VITE_API_BASE=http://localhost:8001 npx vitest run src/components/CausePreview.test.jsx`
Expected: PASS (both cases).

- [ ] **Step 5: Write the failing JobForm integration test**

Create `frontend/src/components/JobForm.preview.behavior.test.jsx`:

```jsx
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';
import JobForm from './JobForm';
import * as client from '../api/client';

describe('JobForm cause preview', () => {
  beforeEach(() => { vi.restoreAllMocks(); });

  it('disables Submit when the preview reports unrecognized causes', async () => {
    vi.spyOn(client, 'previewMapping').mockResolvedValue({
      reports: { interva: {
        total_records: 5, calibrated_denominator: 3, excluded_undetermined: [],
        unrecognized: [{ cause: 'Pnemonia', count: 2, suggestion: 'pneumonia' }],
        mapping: [], has_errors: true,
      } },
    });
    render(<JobForm onJobCreated={() => {}} />);
    const file = new File(['ID,cause\n1,Pnemonia\n'], 'interva.csv', { type: 'text/csv' });
    const input = document.querySelector('input[type="file"]');
    fireEvent.change(input, { target: { files: [file] } });
    await waitFor(() => expect(screen.getByText(/Pnemonia/)).toBeInTheDocument());
    expect(screen.getByRole('button', { name: /submit|calibrat|run/i })).toBeDisabled();
  });
});
```

Adjust the Submit-button name regex to the actual button label in `JobForm.jsx` before running.

- [ ] **Step 6: Run it to verify it fails**

Run: `cd frontend && VITE_API_BASE=http://localhost:8001 npx vitest run src/components/JobForm.preview.behavior.test.jsx`
Expected: FAIL — preview not wired; Submit still enabled.

- [ ] **Step 7: Wire preview into JobForm**

In `frontend/src/components/JobForm.jsx`:

1. Import at top: `import CausePreview from './CausePreview';` and add `previewMapping` to the existing `../api/client` import.
2. Add state near the other `useState` calls (around line 44):

```jsx
  const [previewReports, setPreviewReports] = useState({});
  const previewHasErrors = Object.values(previewReports).some((r) => r && r.has_errors);
```

3. After `uploads`/`ageGroup` are defined, add an effect that fetches the preview whenever attached files or age group change:

```jsx
  useEffect(() => {
    const withFiles = uploads.filter((u) => u.file && u.algorithm);
    if (withFiles.length === 0) { setPreviewReports({}); return; }
    let cancelled = false;
    previewMapping({ uploads: withFiles, ageGroup })
      .then((res) => { if (!cancelled) setPreviewReports(res.reports || {}); })
      .catch(() => { if (!cancelled) setPreviewReports({}); });
    return () => { cancelled = true; };
  }, [uploads, ageGroup]);
```

4. Render the panels below the upload inputs (near the supported-causes hint, ~line 326):

```jsx
          {Object.entries(previewReports).map(([algo, report]) => (
            <CausePreview key={algo} report={report}
              algorithmLabel={algo.charAt(0).toUpperCase() + algo.slice(1)} />
          ))}
```

5. Disable Submit when the preview has errors. Find the submit `<button>` and add `previewHasErrors` to its `disabled` expression, e.g. `disabled={loading || algorithms.length === 0 || previewHasErrors}`.

- [ ] **Step 8: Run the JobForm test and the full frontend suite**

Run: `cd frontend && VITE_API_BASE=http://localhost:8001 npx vitest run src/components/JobForm.preview.behavior.test.jsx src/components/CausePreview.test.jsx`
Expected: PASS.
Then: `cd frontend && VITE_API_BASE=http://localhost:8001 npx vitest run`
Expected: whole suite green (no regressions in existing JobForm tests).

- [ ] **Step 9: Commit**

```bash
cd "$(git rev-parse --show-toplevel)"
git add frontend/src/components/CausePreview.jsx frontend/src/components/CausePreview.test.jsx \
        frontend/src/components/JobForm.jsx frontend/src/components/JobForm.preview.behavior.test.jsx
git commit -m "feat: pre-submit cause-mapping preview panel in JobForm"
```

---

## Self-Review

**Spec coverage:**
- Backend helper reusing existing units → Task 1 (`preview_cause_mapping`, `classify_cause`). ✓
- Report fields (`total_records`, `calibrated_denominator`, `excluded_undetermined`, `unrecognized`+suggestion, `mapping`, `has_errors`) → Task 1 return value + tests. ✓
- `POST /jobs/preview`, same multipart/auth, no job/DB/MCMC → Task 2. ✓
- Frontend `previewMapping` + auto-fetch on attach → Tasks 3, 4 (Step 7.3). ✓
- Block on unrecognized, warn on excluded → Task 4 (CausePreview + `previewHasErrors`). ✓
- Anti-drift consistency test → Task 1 Step 1 (preview denominator == job path). ✓
- Testing (backend report, misspelling, consistency; frontend render/block/warn) → Tasks 1, 4. ✓

**Placeholder scan:** none — all steps contain concrete code/commands. The two "adjust to actual" notes (Submit-button regex in Task 4 Step 5; auth token in Task 2 Step 2) are explicit verification adjustments, not deferred work.

**Type consistency:** report field names identical across Task 1 (producer), Task 4 (consumer), and all tests. `previewMapping({ uploads, ageGroup })` signature identical in Task 3 (def) and Task 4 (call). `classify_cause`/`preview_cause_mapping` names consistent throughout.

## Out of scope
- No client-side cause mapping.
- No change to calibration algorithm/result shape.
- No refactor of `run_vacalibration`'s mapping path.
- Deleting the frontend's hardcoded `SUPPORTED_CAUSES` list (deferred; the dynamic preview supersedes it visually once a file is chosen).
