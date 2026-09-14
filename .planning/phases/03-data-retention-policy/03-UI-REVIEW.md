# Phase 3 — UI Review

**Audited:** 2026-09-13
**Baseline:** abstract 6-pillar standards (no UI-SPEC.md exists for this phase)
**Screenshots:** not captured — no dev server on localhost:3000 or 5173 (code-only audit)

**Scope:** This phase's only frontend delivery is one line — `RETENTION_NOTICE` rendered as `<p className="retention-notice">` in `frontend/src/components/JobList.jsx:116`, immediately after `<h3>Recent Jobs</h3>`. There is no accompanying CSS rule for `.retention-notice` anywhere in `frontend/src` (confirmed via grep across all `.css` files). Scores below are for this delivery's integration into the existing "Recent Jobs" panel, not the pre-existing rest of the app.

---

## Pillar Scores

| Pillar | Score | Key Finding |
|--------|-------|-------------|
| 1. Copywriting | 4/4 | Specific, non-generic, matches D-09's contract wording exactly; states the action the user should take. |
| 2. Visuals | 2/4 | No visual differentiation (no icon, no tint, no border) despite disclosing an irreversible-deletion policy; renders as plain body text competing with the panel header and table. |
| 3. Color | 2/4 | Uses default full-strength `--color-text` (#111827) instead of the app's own established `--color-text-secondary` convention (used 12+ times elsewhere for helper/subordinate copy) — the notice reads with the same visual weight as primary job data. |
| 4. Typography | 2/4 | Renders at the global 16px body size with no override; every other secondary/helper string in the codebase is deliberately smaller (`0.75rem`–`0.875rem` per existing `.job-list th/td` and other secondary-text rules) — this one-off breaks that established scale. |
| 5. Spacing | 2/4 | Zero CSS rule means the global reset (`*{margin:0;padding:0}`) applies: the `<p>` sits with no margin between the `h3`'s bottom border and the table's top edge, breaking the panel's otherwise consistent spacing rhythm (`h3` has `padding-bottom: 0.75rem`, table cells have `padding: 0.875rem 0.75rem`). |
| 6. Experience Design | 3/4 | Correctly placed on every load of the non-empty job list (satisfies D-09's "no per-job date, no banner, no modal"), but the empty-state branch (`jobs.length === 0`, line 105–111) renders and returns before the notice, so a user who has never submitted a job never sees the retention policy at all. |

**Overall: 15/24**

---

## Top 3 Priority Fixes

1. **No dedicated `.retention-notice` style rule exists** — the notice inherits full-size, full-contrast body text with zero margin, so it visually collides with the panel header/table and reads as equally important as job data instead of as a subordinate disclosure. *User impact:* a policy statement about irreversible data deletion is easy to skim past or, conversely, unintentionally draws the eye away from the actual job table due to the missing spacing gap. *Fix:* add `.retention-notice { color: var(--color-text-secondary); font-size: 0.8rem; margin: -0.5rem 0 1rem; }` (or similar) in `App.css`, consistent with the app's existing secondary-text convention.
2. **Empty state never shows the retention notice** — `JobList.jsx` lines 105–111 return early for `jobs.length === 0` without rendering `RETENTION_NOTICE`. *User impact:* a first-time user (arguably the audience most likely to need to know the policy before their first upload) never sees it. *Fix:* render `RETENTION_NOTICE` in the empty-state branch too, or hoist it above the `if (jobs.length === 0)` check so it always renders once jobs have loaded.
3. **No affordance distinguishing this as a system/policy notice vs. ordinary text** — no icon, tinted background, or border treatment, despite the app already having `--color-warning-bg`/`--color-info-bg` tokens defined and used elsewhere (`.status-badge`, line 708) for exactly this kind of "pay attention" styling. *User impact:* the notice can visually disappear into the panel on first glance. *Fix:* consider a subtle `background: var(--color-info-bg)` treatment matching the app's own established pattern language, or at minimum apply the secondary-text color fix in item 1.

---

## Detailed Findings

### Pillar 1: Copywriting (4/4)
`frontend/src/components/JobList.jsx:8` — `RETENTION_NOTICE = 'Jobs and their uploaded files are deleted automatically 90 days after completion — download any results you need to keep.'` This is specific, states the mechanism (automatic), the window (90 days), and the required user action (download to keep). It matches D-09's contract almost verbatim and is machine-pinned against `RETENTION_DAYS` by `tests/test_retention.R` section 4 (per 03-02-SUMMARY.md), so it cannot silently drift. No generic-label or vague-copy issues found.

### Pillar 2: Visuals (2/4)
`JobList.jsx:116` renders the notice as a bare `<p>` with no icon, no background treatment, and no border — a plain sentence sandwiched between the section header and the data table. The rest of the panel (`.job-list`) has a defined visual system: card surface, border, shadow, header divider (`.job-list h3` has `border-bottom`). The notice does not participate in that system at all; it is the only element in the panel with zero styling. Given it communicates an irreversible-deletion policy, it warrants at least the level of visual treatment given to a `.status-badge`, which it does not have.

### Pillar 3: Color (2/4)
No `.retention-notice` rule exists (confirmed: `grep -rn "retention-notice" frontend/src --include="*.css"` returns nothing). The element inherits `body { color: var(--color-text) }` = `#111827`, the app's primary/near-black text color, identical in weight to headings and table cell text. The codebase has an established `--color-text-secondary` (`#6b7280`) used at 12+ call sites in `App.css` specifically for de-emphasized/helper copy. The notice's failure to use it means it competes for visual weight with actual job data rather than reading as secondary information.

### Pillar 4: Typography (2/4)
No font-size override; the `<p>` renders at the `html { font-size: 16px }` root default (no rem override applied anywhere for it), the largest text size in the panel apart from the `h3` title. Every other piece of secondary/contextual copy in the surrounding table uses smaller sizes (`.job-list th, .job-list td { font-size: 0.875rem }`, `.job-list th { font-size: 0.8rem }`). A disclaimer-style sentence rendering larger than the table's own header row breaks the panel's internal type scale.

### Pillar 5: Spacing (2/4)
The global reset `*, *::before, *::after { margin: 0; padding: 0; }` (App.css) applies to the unstyled `<p>`, so it has zero margin above or below. It sits directly under `.job-list h3`, which has `padding-bottom: 0.75rem` and a `border-bottom`, and directly above `.job-list table`, which has no `margin-top`. The result: no breathing room between the header's rule line and the notice, and none between the notice and the table's top border — a visible violation of the panel's otherwise-consistent `0.75rem`–`1rem` spacing rhythm used everywhere else in this component's CSS.

### Pillar 6: Experience Design (3/4)
Positive: the notice appears unconditionally on every render of the populated job list (not gated behind a first-visit flag, not dismissible, not re-fetched — matching D-09's explicit "no per-job expiry, no banner, no modal" constraint), and its correctness is pinned by a dependency-free test (`tests/test_retention.R` section 4) tying it to the single `RETENTION_DAYS` source of truth, which is a genuinely strong experience-design property (no drift risk). Negative: `JobList.jsx` lines 105–111 handle the `jobs.length === 0` case with an early return that never reaches line 116, so a user with no jobs yet — arguably the highest-value audience for a policy notice, since they haven't yet uploaded anything — never sees it. This is a real coverage gap in an otherwise deliberately minimal design.

---

## Files Audited
- `/Users/eric/projects6/comsa_dashboard/frontend/src/components/JobList.jsx`
- `/Users/eric/projects6/comsa_dashboard/frontend/src/App.css`
- `/Users/eric/projects6/comsa_dashboard/.planning/phases/03-data-retention-policy/03-01-SUMMARY.md`
- `/Users/eric/projects6/comsa_dashboard/.planning/phases/03-data-retention-policy/03-02-SUMMARY.md`
- `/Users/eric/projects6/comsa_dashboard/.planning/phases/03-data-retention-policy/03-03-SUMMARY.md`
- `/Users/eric/projects6/comsa_dashboard/.planning/phases/03-data-retention-policy/03-CONTEXT.md`

No `components.json` / shadcn registry present in this repo — Registry Safety audit skipped.
