# Input Panel Presentation — Issue #73 Design

**Date:** 2026-06-02
**Issue:** [#73 — suggestion for input panel presentation](https://github.com/cliu238/comsa_dashboard/issues/73)
**Scope:** Frontend only (`frontend/src/components/JobForm.jsx`, `JobDetail.jsx`, `JobList.jsx`). Backend API is unchanged.

## Goal

Make the job submission form clearly communicate what inputs are required and what the
job will produce. The issue's framing: *"trying to cleanly separate all inputs so users
know what's required."* Every item below serves that goal — reduce ambiguity and noise.

## Key architectural decision

The proposed "Input Type" / "Output Type" split is a **pure frontend relabeling**. The
backend (`backend/plumber.R`) validates a `job_type` string of `openva`, `vacalibration`,
or `pipeline`. `JobForm` will derive that same `job_type` from the two new dropdowns and
keep sending it unchanged via `submitJob` / `submitDemoJob`. No backend edits.

Rejected alternative: renaming `job_type` through the API and backend — adds risk and
churn for no user-visible benefit, and violates the project's simplicity principle.

## Items

### A. Top-of-form restructure (issue item #7)

Replace the single "Job Type" `CustomSelect` with two cascading selects:

- **Input Type** *
  - `Individual VA Records`
  - `Output from CCVA`
- **Output Type** * — options depend on Input Type:
  - Input = `Individual VA Records`:
    - `Individual Top Cause of Death` → `job_type = "openva"`
    - `Cause Distribution` → `job_type = "pipeline"`
  - Input = `Output from CCVA`:
    - locked to `Cause Distribution` → `job_type = "vacalibration"`

Mapping table (the single source of truth for the derivation):

| Input Type            | Output Type                  | job_type        |
|-----------------------|------------------------------|-----------------|
| Individual VA Records | Individual Top Cause of Death | `openva`        |
| Individual VA Records | Cause Distribution           | `pipeline`      |
| Output from CCVA      | Cause Distribution (locked)  | `vacalibration` |

Behavior:
- Default state (proposed): preserve the current default `job_type = "vacalibration"`,
  which means Input Type defaults to `Output from CCVA` with Output Type locked to
  `Cause Distribution`. This keeps existing form behavior unchanged. See Open Questions
  if a different default landing state is preferred.
- Switching Input Type to `Output from CCVA` forces Output Type to `Cause Distribution`
  and renders it locked.
- Locked Output Type is shown as a disabled select displaying "Cause Distribution"
  (styling detail can be finalized in implementation; plain read-only text is acceptable).
- All existing conditional logic keyed on `jobType` (country visibility, algorithm
  selector shape, upload rows, MCMC panel, ensemble rules) continues to key on the
  derived `job_type` value, so downstream behavior is unchanged.

### B. Required-field markers (issue item #4)

- Add a red asterisk (`*`) next to each required field title, rendered only when that
  field is visible: **Input Type, Output Type, Country, Age Group, Algorithm(s), file upload.**
- Add a small `* Required fields` legend directly under the panel heading ("Submit Job").
- Use a reusable marker (e.g. `<span className="required">*</span>`) styled red.

### C. Label / text fixes

- Panel heading `Submit New Job` → `Submit Job` (issue item #1).
- Upload label `VA Data Files (one CSV per selected algorithm)` → `Upload VA Data`
  (issue item #6). The helper hint about required columns may remain.

### D. Timings and algorithm order (issue item #2)

- Remove **all** timing text:
  - per-algorithm hints — `(fastest, ~30sec)`, `(most accurate, ~2-3min)`,
    `(deterministic, ~1min)` — in every selector and checkbox group.
  - ensemble / multi-algorithm runtime estimates — the "Running N algorithms will take…"
    and "Estimated runtime: …" hints.
- Reorder algorithms everywhere to **EAVA, InSilicoVA, InterVA**: the openVA select, the
  pipeline select and checkbox group, the vacalibration checkbox group, and the
  sample-CSV download links (for consistency).
- Algorithm option labels become just the names: `EAVA`, `InSilicoVA`, `InterVA`.

### E. MCMC Specifics heading (issue item #3)

Restyle the collapsible "MCMC Specifics" toggle so its text matches the input-title font
(size / weight / color) used by labels like "Age Group". Collapse/expand behavior and the
▸/▾ affordance are retained.

### F. Uncertainty block (issue item #8, lesser priority)

Give the uncertainty control a title consistent with the other input titles:

- Title: `Uncertainty in CCVA misclassification`
- Below it: a checkbox labeled `Propagate` (bound to the existing
  `calibModelType === 'Mmatprior'` logic).
- Keep the existing explanatory hint and the link to the CCVA misclassification reference.

### G. Timestamps with timezone (issue item #5)

Job timestamps already render in the browser's local time but show no timezone, so it is
unclear which zone they represent. Add an explicit timezone label to the local-time
display in **both**:

- `JobDetail.jsx` — the Created / Started / Completed rows (`formatDate`).
- `JobList.jsx` — the created-at table column.

Implementation: include a timezone token in the formatted output (e.g. via
`toLocaleString` with `timeZoneName: 'short'`), producing output like
`Jun 2, 2026, 3:04 PM EDT`. Continue to correctly handle the R array timestamp format
(`[epoch_seconds]`) already supported by `formatDate`.

### H. Example script link (issue item #9)

Add an external link below "Upload VA Data" pointing to the vacalibration paper's example
code for preparing/running/saving input data. No file is committed to this repo.

- Link target: the vacalibration package repository
  <https://github.com/sandy-pramanik/vacalibration>.

## Testing

Write tests before/with implementation:

- **Mapping**: `(inputType, outputType) → job_type` for all three valid combinations plus
  the locked `Output from CCVA` case. This is the core new logic.
- **Timestamp formatter**: produces a timezone-labeled local-time string; still handles the
  R `[epoch_seconds]` array format.
- **Required markers**: required field titles render the `*` marker when visible.
- **Regression**: existing `JobForm`, `JobDetail`, `JobList` unit tests stay green
  (update any assertions tied to renamed labels or removed timing strings).

Run via `cd frontend && npm test`.

## Out of scope

- No backend / `plumber.R` changes.
- No change to job execution, algorithms, or result rendering.
- Committing the example `.R` script into this repo (issue #9 resolved as an external link).

## Resolved decisions

1. **Default selection** on form load: keep the current `vacalibration` default
   (Input Type = `Output from CCVA`, Output Type locked to `Cause Distribution`),
   preserving existing behavior.
2. **Example-script URL** (item H): link to
   <https://github.com/sandy-pramanik/vacalibration>.
