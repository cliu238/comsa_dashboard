# Issue #69 — Resource & Acknowledgment Tabs + Running Credit

**Date:** 2026-05-26
**Issue:** [#69 — credit and links to source code and related papers](https://github.com/cliu238/comsa_dashboard/issues/69)
**Related:** #68 (title rename + "VA-Calibration" naming — out of scope here)

## Goal

Acknowledge the project's contributors and surface its source code and related
papers, keeping that material separate from the job-submission frame. Concretely:

1. Add a **Resource** tab and an **Acknowledgment** tab to the left menu.
2. Add a short "running credit" line under the page title on every page.
3. Move the sample-data **Source** citation out of the input form.

## Decisions (issue takes precedence over earlier preferences)

The user initially answered some clarifying questions, then directed: *"if my
decision doesn't match, follow the instruction of the issue."* The decisions
below reflect the issue's wording where the two conflicted.

| Topic | Decision | Source |
|---|---|---|
| Investigator photos | Cards **support photos** (shown when a headshot is supplied; text/initials fallback otherwise). No external hotlinking. | Issue ("pictures possible? … as much as possible") overrides earlier "text-only" |
| Title rename | **Deferred** to #68. Credit line sits under the *current* title. | Issue itself says "(see issue #68)" |
| Credit scope | Renders on **all pages** (it's a "running credit"). | Issue ("short/running credit at the top") |
| Credit wording | Use the issue's example verbatim. | Issue |
| Videos | **Move** Introduction Videos into the Resource tab. | Issue ("potentially move") + user |
| Page architecture | Two dedicated page components, mirroring `AdminPage`. | Approach A (approved) |

## Architecture

Follows the existing flat route + sidebar pattern in `frontend/src/App.jsx`:
each menu item is a `navItems` entry paired with a `<Route>`, wrapped in
`ProtectedRoute` + `PageHeader`.

```
Sidebar order:  Calibrate → Demo Gallery → Resource → Acknowledgment → (Users, admin only)
Routes added:   /resource        → pages/ResourcePage.jsx
                /acknowledgment   → pages/AcknowledgmentPage.jsx
```

### New / changed files

| File | Change |
|---|---|
| `frontend/src/App.jsx` | Add 2 `navItems` entries + 2 icons; add 2 routes; extend `PageHeader` with the credit line; remove `VideosSection` from the Calibrate route. |
| `frontend/src/components/VideosSection.jsx` | **New.** Extract the existing `VideosSection` from `App.jsx` into its own component so it can be reused on the Resource page. |
| `frontend/src/pages/ResourcePage.jsx` | **New.** References, package links, sample-data source, videos. |
| `frontend/src/pages/AcknowledgmentPage.jsx` | **New.** Award, investigators, contributors. |
| `frontend/src/components/JobForm.jsx` | Remove the `.sample-source` citation at line ~497. |
| `frontend/src/App.css` | Styles for `.page-credit`, resource/ack page sections, investigator cards. |

## Component: PageHeader (credit line)

Extend the existing `PageHeader` to render a third line below the subtitle,
rendered on every page:

> Designed and maintained by **[DSAI](https://ai.jhu.edu/)**, Dept of Biostat,
> Dept of International Health at Johns Hopkins

- Wording matches the issue's example exactly ("Dept of Biostat", not expanded).
- "DSAI" links to `https://ai.jhu.edu/`. The two department names link to their
  JHU Bloomberg School pages (**URLs to confirm** — not fabricated here).
- The "Powered by … DSAI" footer in `App.jsx` is left untouched.

## Page: ResourcePage

Three sections:

### vacalibration R package
- GitHub: **verify canonical repo** — CRAN manual lists
  `github.com/sandy-pramanik/vacalibration`; the app currently links
  `github.com/VA-calibration/vacalibration` (`JobForm.jsx:497`). Use whichever the
  CRAN page lists as the official URL; reconcile the existing citation to match.
- CRAN: `https://cran.r-project.org/package=vacalibration`

### References (pg. 17 of the vacalibration manual, links verified from the PDF)
1. Pramanik S, et al. (2026). Country-Specific Estimates of Misclassification
   Rates of Computer-Coded Verbal Autopsy Algorithms. *BMJ Global Health.*
   → https://doi.org/10.1136/bmjgh-2025-021747
2. Pramanik S, et al. (2025). Modeling structure and country-specific
   heterogeneity in misclassification matrices of verbal autopsy-based cause of
   death classifiers. *Annals of Applied Statistics.*
   → https://doi.org/10.1214/24-AOAS2006
3. Fiksel J, et al. (2022). Generalized Bayes Quantification Learning under
   Dataset Shift. *Journal of the American Statistical Association.*
   → https://www.tandfonline.com/doi/full/10.1080/01621459.2021.1909599
4. Datta A, et al. (2021). Regularized Bayesian transfer learning for
   population-level etiological distributions. *Biostatistics.*
   → https://doi.org/10.1093/biostatistics/kxaa001

### Sample data source (moved from the form)
The citation currently at `JobForm.jsx:497`:
> Source: Pramanik S, Wilson E, Fiksel J, Gilbert B, Datta A (2025).
> *vacalibration: Calibration of Computer-Coded Verbal Autopsy Algorithm.*
> R package version 2.0. COMSA Mozambique data.

### Introduction Videos
The existing `VideosSection` (Platform Overview + Methodology Details videos),
moved here from the Calibrate page.

## Page: AcknowledgmentPage

Acknowledges the project separately from job submission. Hyperlinks the award,
DSAI, the departments, and individuals "as much as possible" (per the issue).

### Award
"2024 Data Science and AI Institute Demonstration Projects Award", linked to:
`https://ai.jhu.edu/news/data-science-and-ai-institute-announces-inaugural-demonstration-projects-award-recipients-2024/`

### Investigators
The personnel listed as investigators in the award. Rendered as a card list,
each card showing name / role / affiliation, an outbound hyperlink where a URL is
provided, and an **optional headshot** (graceful text/initials fallback when no
photo is supplied). DSAI and the two department names are hyperlinked here too.

> **Content to be provided by the user** (from the award image): investigator
> names, affiliations, profile links, and optional headshot files. Headshots, if
> provided, live in `frontend/public/acknowledgment/` (or `src/assets/`).

### Contributors
DSAI team members who built the platform, plus an explicit "Platform development"
credit highlighting the contributors who designed and developed it (the issue
asks to "highlight yourself … you contributed significantly").

> **Content to be provided by the user:** DSAI contributor names + links.

## Error handling / edge cases

- Investigator/contributor cards render from a local data array; an empty array
  shows nothing (no crash). Missing photo → initials avatar. Missing link → plain
  text (no dead anchor).
- All outbound links use `target="_blank" rel="noopener noreferrer"` (matches the
  existing convention at `JobForm.jsx:497`).
- New routes are inside `ProtectedRoute`, consistent with other authed pages.

## Testing

- **vitest unit tests:**
  - `ResourcePage.test.jsx` — asserts the 4 reference links, GitHub + CRAN links,
    and the moved sample-data source string are present.
  - `AcknowledgmentPage.test.jsx` — asserts the award link renders, and that an
    investigator data array renders the expected cards (with/without photo).
  - `PageHeader` credit-line test — asserts the credit text + DSAI link render.
  - Follows the existing label-assertion style (`JobDetail.test.js`).
- **Manual (dev server):** click through all four tabs; confirm the credit line
  appears on each; videos play on Resource; the Source line no longer appears in
  the form.

## Out of scope (tracked elsewhere)

- #68: title rename to "Correcting for Algorithmic Misclassification in Estimating
  Cause Distributions", "VA-Calibration" naming, CCVA-misclassification hyperlink.
- `LandingPage.jsx:115` Pramanik citation (public landing page, not the input frame).

## Open items to resolve before merge

1. Investigator list + affiliations + profile links + optional headshots (from award image).
2. DSAI contributor names + links for the Contributors section.
3. Department page URLs for the credit line and Acknowledgment hyperlinks.
4. Canonical vacalibration GitHub repo (`sandy-pramanik` vs `VA-calibration`).
