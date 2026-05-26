# Resource & Acknowledgment Tabs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Resource tab and an Acknowledgment tab to the left menu, a running credit line under every page title, and relocate the sample-data source citation out of the job form (GitHub issue #69).

**Architecture:** Follow the existing flat route + sidebar pattern in `frontend/src/App.jsx` (each menu item = one `navItems` entry + one `<Route>`). All external links and citations live in one plain-JS data module (`src/content/links.js`) so they are unit-testable in the node test environment and editable in one place. The two new pages are thin presentational components that map over that data. The existing `VideosSection` is extracted from `App.jsx` into its own component and rendered on the Resource page.

**Tech Stack:** React 18, react-router-dom, Vite, Vitest (config: `environment: 'node'`, `globals: true`; jsdom opt-in per-file via a `@vitest-environment jsdom` docblock), @testing-library/react.

---

## Conventions you must follow

- **Two test styles already exist in this repo — match them:**
  - *Source-level tests* (`*.test.js`, node env): `readFileSync` the `.jsx` source and assert `toContain(...)`. Used for content/label checks (see `src/components/JobForm.test.js`, `JobDetail.test.js`).
  - *Render tests* (`*.test.jsx` with a `/** @vitest-environment jsdom */` docblock as the FIRST lines): `render(...)` + `screen` from `@testing-library/react` (see `src/components/JobForm.behavior.test.jsx`).
  - Plain-JS data modules can be imported directly in node-env `*.test.js`.
- **No `@testing-library/jest-dom`** is configured. Do NOT use `.toBeInTheDocument()`. Use `screen.getByRole/getByText` (these throw if absent) plus `expect(x).toBeTruthy()` / `expect(x.getAttribute('href')).toBe(...)` / `expect(screen.queryByRole('img')).toBeNull()`.
- **All outbound links** use `target="_blank" rel="noopener noreferrer"` (matches `JobForm.jsx:497`).
- **Run tests from the `frontend/` directory:** `cd frontend && npx vitest run <path>`.
- **CSS uses design tokens** already defined in `App.css`: `var(--color-text)`, `var(--color-text-secondary)`, `var(--color-accent)`, `var(--color-surface)`, `var(--color-border)`, `var(--radius-md)`, `var(--transition-fast)`. Reuse them; do not hardcode colors.

---

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `frontend/src/content/links.js` | Single source of truth for all external links + citation text | Create |
| `frontend/src/content/links.test.js` | Unit test for the data module (node env) | Create |
| `frontend/src/components/VideosSection.jsx` | Collapsible Introduction Videos (extracted from App.jsx) | Create |
| `frontend/src/components/VideosSection.test.jsx` | Render test (jsdom) | Create |
| `frontend/src/pages/ResourcePage.jsx` | References, package links, sample-data source, videos | Create |
| `frontend/src/pages/ResourcePage.test.jsx` | Render test (jsdom) | Create |
| `frontend/src/pages/AcknowledgmentPage.jsx` | Award, investigators, contributors (+ `InvestigatorCard`) | Create |
| `frontend/src/pages/AcknowledgmentPage.test.jsx` | Render test (jsdom) | Create |
| `frontend/src/App.jsx` | Sidebar entries + routes; credit line in `PageHeader`; remove inline `VideosSection` | Modify |
| `frontend/src/App.routes.test.js` | Source-level test for nav/routes/credit (node env) | Create |
| `frontend/src/components/JobForm.jsx` | Remove the `.sample-source` citation (~line 497) | Modify |
| `frontend/src/components/JobForm.source.test.js` | Source-level test that the citation is gone | Create |
| `frontend/src/App.css` | Styles: `.page-credit`, `.content-page`, `.content-section`, people cards | Modify |

---

## Task 1: Central content/links data module

**Files:**
- Create: `frontend/src/content/links.js`
- Test: `frontend/src/content/links.test.js`

- [ ] **Step 1: Verify the external URLs are live before baking them in**

The project rule is "verify against actual source, don't trust assumptions." Confirm each URL resolves (HTTP 200/3xx) and pick the canonical vacalibration GitHub repo (CRAN manual lists `sandy-pramanik/vacalibration`; the app currently cites `VA-calibration/vacalibration`).

Run:
```bash
for u in \
  "https://github.com/sandy-pramanik/vacalibration" \
  "https://github.com/VA-calibration/vacalibration" \
  "https://cran.r-project.org/package=vacalibration" \
  "https://doi.org/10.1136/bmjgh-2025-021747" \
  "https://doi.org/10.1214/24-AOAS2006" \
  "https://www.tandfonline.com/doi/full/10.1080/01621459.2021.1909599" \
  "https://doi.org/10.1093/biostatistics/kxaa001" \
  "https://ai.jhu.edu/" \
  "https://ai.jhu.edu/news/data-science-and-ai-institute-announces-inaugural-demonstration-projects-award-recipients-2024/" \
  "https://publichealth.jhu.edu/departments/biostatistics" \
  "https://publichealth.jhu.edu/departments/international-health" ; do
  printf '%s -> %s\n' "$(curl -s -o /dev/null -w '%{http_code}' -L "$u")" "$u"
done
```
Expected: each prints `200` (or `3xx` before the `-L` follow resolves to 200). If a `github.com/...vacalibration` repo 404s, use the one that resolves as the canonical repo in Step 3. If a `publichealth.jhu.edu` department URL 404s, replace it with the URL that resolves (search the JHU Bloomberg School site) and note it in Task 9.

- [ ] **Step 2: Write the failing test**

```js
import { describe, it, expect } from 'vitest'
import {
  PACKAGE_LINKS, REFERENCES, AWARD, ORGS, CREDIT, SAMPLE_DATA_SOURCE,
} from './links'

const isHttps = (u) => typeof u === 'string' && u.startsWith('https://')

describe('content/links data module', () => {
  it('has exactly 4 references, each with an https URL and a title', () => {
    expect(REFERENCES).toHaveLength(4)
    REFERENCES.forEach((r) => {
      expect(isHttps(r.url)).toBe(true)
      expect(r.title.length).toBeGreaterThan(0)
      expect(String(r.year).length).toBe(4)
    })
  })

  it('package links point to a vacalibration GitHub repo and the CRAN page', () => {
    expect(PACKAGE_LINKS.github).toMatch(/github\.com\/[^/]+\/vacalibration/)
    expect(PACKAGE_LINKS.cran).toBe('https://cran.r-project.org/package=vacalibration')
  })

  it('award and org links are https', () => {
    expect(isHttps(AWARD.url)).toBe(true)
    expect(isHttps(ORGS.dsai.url)).toBe(true)
    expect(isHttps(ORGS.biostat.url)).toBe(true)
    expect(isHttps(ORGS.intlHealth.url)).toBe(true)
  })

  it('credit line uses the issue #69 wording verbatim', () => {
    expect(CREDIT.prefix).toBe('Designed and maintained by ')
    expect(CREDIT.parts.map((p) => p.label)).toEqual([
      'DSAI', 'Dept of Biostat', 'Dept of International Health',
    ])
    expect(CREDIT.suffix).toBe(' at Johns Hopkins')
    CREDIT.parts.forEach((p) => expect(isHttps(p.url)).toBe(true))
  })

  it('sample-data source has citation text and a link', () => {
    expect(SAMPLE_DATA_SOURCE.text).toMatch(/Pramanik S, Wilson E/)
    expect(isHttps(SAMPLE_DATA_SOURCE.url)).toBe(true)
  })
})
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/content/links.test.js`
Expected: FAIL — `Failed to resolve import "./links"` (module does not exist yet).

- [ ] **Step 4: Create the data module**

Create `frontend/src/content/links.js` (substitute the canonical GitHub repo confirmed in Step 1; the value below is the CRAN-manual repo):

```js
// Single source of truth for external links and citations used by the
// Resource and Acknowledgment pages (issue #69). URLs verified live 2026-05-26.

export const PACKAGE_LINKS = {
  github: 'https://github.com/sandy-pramanik/vacalibration',
  cran: 'https://cran.r-project.org/package=vacalibration',
};

// The 4 references cited on pg. 17 of the vacalibration CRAN manual.
export const REFERENCES = [
  {
    authors: 'Pramanik S, et al.',
    year: 2026,
    title: 'Country-Specific Estimates of Misclassification Rates of Computer-Coded Verbal Autopsy Algorithms',
    venue: 'BMJ Global Health',
    url: 'https://doi.org/10.1136/bmjgh-2025-021747',
  },
  {
    authors: 'Pramanik S, et al.',
    year: 2025,
    title: 'Modeling structure and country-specific heterogeneity in misclassification matrices of verbal autopsy-based cause of death classifiers',
    venue: 'Annals of Applied Statistics',
    url: 'https://doi.org/10.1214/24-AOAS2006',
  },
  {
    authors: 'Fiksel J, et al.',
    year: 2022,
    title: 'Generalized Bayes Quantification Learning under Dataset Shift',
    venue: 'Journal of the American Statistical Association',
    url: 'https://www.tandfonline.com/doi/full/10.1080/01621459.2021.1909599',
  },
  {
    authors: 'Datta A, et al.',
    year: 2021,
    title: 'Regularized Bayesian transfer learning for population-level etiological distributions',
    venue: 'Biostatistics',
    url: 'https://doi.org/10.1093/biostatistics/kxaa001',
  },
];

// Moved out of the job form (was JobForm.jsx:497).
export const SAMPLE_DATA_SOURCE = {
  text: 'Source: Pramanik S, Wilson E, Fiksel J, Gilbert B, Datta A (2025). vacalibration: Calibration of Computer-Coded Verbal Autopsy Algorithm. R package version 2.0. COMSA Mozambique data.',
  url: 'https://github.com/sandy-pramanik/vacalibration',
};

export const AWARD = {
  title: '2024 Data Science and AI Institute Demonstration Projects Award',
  url: 'https://ai.jhu.edu/news/data-science-and-ai-institute-announces-inaugural-demonstration-projects-award-recipients-2024/',
};

export const ORGS = {
  dsai: { name: 'Johns Hopkins Data Science and AI Institute (DSAI)', url: 'https://ai.jhu.edu/' },
  biostat: { name: 'Department of Biostatistics', url: 'https://publichealth.jhu.edu/departments/biostatistics' },
  intlHealth: { name: 'Department of International Health', url: 'https://publichealth.jhu.edu/departments/international-health' },
};

// Running credit shown under every page title. Wording is verbatim from issue #69.
export const CREDIT = {
  prefix: 'Designed and maintained by ',
  parts: [
    { label: 'DSAI', url: ORGS.dsai.url },
    { label: 'Dept of Biostat', url: ORGS.biostat.url },
    { label: 'Dept of International Health', url: ORGS.intlHealth.url },
  ],
  suffix: ' at Johns Hopkins',
};

// Award investigators — populated in Task 9 from the award image (issue #69).
// Shape: { name, role, affiliation, url, photo }. `url` and `photo` optional;
// `photo` is a filename served from /acknowledgment/ under frontend/public.
export const INVESTIGATORS = [];

// DSAI contributors who built the platform — populated in Task 9.
export const CONTRIBUTORS = [];
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd frontend && npx vitest run src/content/links.test.js`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add frontend/src/content/links.js frontend/src/content/links.test.js
git commit -m "feat(resource): add central links/citations data module (#69)"
```

---

## Task 2: Extract VideosSection out of App.jsx

**Files:**
- Create: `frontend/src/components/VideosSection.jsx`
- Create: `frontend/src/components/VideosSection.test.jsx`
- Modify: `frontend/src/App.jsx` (remove `VideosSection` function at lines 152-186, remove `<VideosSection />` from the Calibrate route at line 205, remove the now-unused `video` icon at lines 72-76)

- [ ] **Step 1: Write the failing render test**

Create `frontend/src/components/VideosSection.test.jsx`:
```jsx
/** @vitest-environment jsdom */
import { describe, it, expect } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import VideosSection from './VideosSection'

describe('VideosSection', () => {
  it('is collapsed by default and expands on click', () => {
    render(<VideosSection />)
    expect(screen.queryByText('Platform Overview')).toBeNull()
    fireEvent.click(screen.getByText('Introduction Videos'))
    expect(screen.getByText('Platform Overview')).toBeTruthy()
    expect(screen.getByText('Methodology Details')).toBeTruthy()
  })

  it('renders expanded when defaultExpanded is set', () => {
    render(<VideosSection defaultExpanded />)
    expect(screen.getByText('Platform Overview')).toBeTruthy()
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/components/VideosSection.test.jsx`
Expected: FAIL — `Failed to resolve import "./VideosSection"`.

- [ ] **Step 3: Create the extracted component**

Create `frontend/src/components/VideosSection.jsx`:
```jsx
import { useState } from 'react';

const videoIcon = (
  <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
    <rect x="2" y="3" width="20" height="14" rx="2" /><path d="m7 21 5-3 5 3" />
  </svg>
);

export default function VideosSection({ defaultExpanded = false }) {
  const [expanded, setExpanded] = useState(defaultExpanded);

  return (
    <section className="videos-section">
      <button className="videos-toggle" onClick={() => setExpanded(!expanded)}>
        <span className="videos-toggle-icon">{videoIcon}</span>
        <span>Introduction Videos</span>
        <span className={`videos-chevron ${expanded ? 'expanded' : ''}`}>
          <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="6 9 12 15 18 9" />
          </svg>
        </span>
      </button>
      {expanded && (
        <div className="video-grid">
          <div className="video-item">
            <h4>Platform Overview</h4>
            <p>Introduction to the Verbal Autopsy Calibration Platform</p>
            <video controls>
              <source src={`${import.meta.env.BASE_URL}VacalibrationVideo.mp4`} type="video/mp4" />
            </video>
          </div>
          <div className="video-item">
            <h4>Methodology Details</h4>
            <p>Technical explanation of the Bayesian calibration methodology</p>
            <video controls>
              <source src={`${import.meta.env.BASE_URL}vacalibration-full-method.mp4`} type="video/mp4" />
            </video>
          </div>
        </div>
      )}
    </section>
  );
}
```

- [ ] **Step 4: Remove the inline VideosSection from App.jsx**

In `frontend/src/App.jsx`:
1. Delete the entire `function VideosSection() { ... }` block (currently lines 152-186).
2. Delete the `video:` icon entry from the `icons` object (currently lines 72-76).
3. In the `/` (Calibrate) route, delete the `<VideosSection />` line so the element reads:
```jsx
<Route path="/" element={
  loading ? null : user ? (
    <ProtectedRoute>
      <PageHeader title="Calibrate" subtitle="Submit and monitor verbal autopsy calibration jobs" />
      <Dashboard />
    </ProtectedRoute>
  ) : (
    <LandingPage />
  )
} />
```
Do NOT add an import for `VideosSection` in App.jsx — App.jsx no longer references it (the Resource page will, in Task 3).

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd frontend && npx vitest run src/components/VideosSection.test.jsx`
Expected: PASS (2 tests).
Run: `cd frontend && npx vitest run` (full suite, to confirm nothing else broke)
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/components/VideosSection.jsx frontend/src/components/VideosSection.test.jsx frontend/src/App.jsx
git commit -m "refactor(videos): extract VideosSection into its own component (#69)"
```

---

## Task 3: Resource page

**Files:**
- Create: `frontend/src/pages/ResourcePage.jsx`
- Test: `frontend/src/pages/ResourcePage.test.jsx`

- [ ] **Step 1: Write the failing render test**

Create `frontend/src/pages/ResourcePage.test.jsx`:
```jsx
/** @vitest-environment jsdom */
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import ResourcePage from './ResourcePage'
import { REFERENCES, PACKAGE_LINKS } from '../content/links'

describe('ResourcePage', () => {
  it('renders an outbound link for every reference', () => {
    render(<ResourcePage />)
    const hrefs = screen.getAllByRole('link').map((a) => a.getAttribute('href'))
    REFERENCES.forEach((r) => expect(hrefs).toContain(r.url))
  })

  it('renders the GitHub and CRAN package links', () => {
    render(<ResourcePage />)
    const hrefs = screen.getAllByRole('link').map((a) => a.getAttribute('href'))
    expect(hrefs).toContain(PACKAGE_LINKS.github)
    expect(hrefs).toContain(PACKAGE_LINKS.cran)
  })

  it('shows the moved sample-data source citation', () => {
    render(<ResourcePage />)
    expect(screen.getByText(/Pramanik S, Wilson E/)).toBeTruthy()
  })

  it('includes the Introduction Videos section', () => {
    render(<ResourcePage />)
    expect(screen.getByText('Introduction Videos')).toBeTruthy()
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/pages/ResourcePage.test.jsx`
Expected: FAIL — `Failed to resolve import "./ResourcePage"`.

- [ ] **Step 3: Create the page**

Create `frontend/src/pages/ResourcePage.jsx`:
```jsx
import VideosSection from '../components/VideosSection';
import { PACKAGE_LINKS, REFERENCES, SAMPLE_DATA_SOURCE } from '../content/links';

export default function ResourcePage() {
  return (
    <div className="content-page">
      <section className="content-section">
        <h2>vacalibration R Package</h2>
        <ul className="link-list">
          <li>
            <a href={PACKAGE_LINKS.github} target="_blank" rel="noopener noreferrer">GitHub repository</a>
          </li>
          <li>
            <a href={PACKAGE_LINKS.cran} target="_blank" rel="noopener noreferrer">CRAN package page</a>
          </li>
        </ul>
      </section>

      <section className="content-section">
        <h2>References</h2>
        <ol className="reference-list">
          {REFERENCES.map((r) => (
            <li key={r.url}>
              {r.authors} ({r.year}). {r.title}. <em>{r.venue}.</em>{' '}
              <a href={r.url} target="_blank" rel="noopener noreferrer">Link</a>
            </li>
          ))}
        </ol>
      </section>

      <section className="content-section">
        <h2>Sample Data Source</h2>
        <p className="sample-source">
          {SAMPLE_DATA_SOURCE.text}{' '}
          <a href={SAMPLE_DATA_SOURCE.url} target="_blank" rel="noopener noreferrer">GitHub</a>
        </p>
      </section>

      <section className="content-section">
        <VideosSection defaultExpanded />
      </section>
    </div>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && npx vitest run src/pages/ResourcePage.test.jsx`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/pages/ResourcePage.jsx frontend/src/pages/ResourcePage.test.jsx
git commit -m "feat(resource): add Resource page with references, package links, source, videos (#69)"
```

---

## Task 4: Acknowledgment page + InvestigatorCard

**Files:**
- Create: `frontend/src/pages/AcknowledgmentPage.jsx`
- Test: `frontend/src/pages/AcknowledgmentPage.test.jsx`

- [ ] **Step 1: Write the failing render test**

Create `frontend/src/pages/AcknowledgmentPage.test.jsx`:
```jsx
/** @vitest-environment jsdom */
import { describe, it, expect } from 'vitest'
import { render, screen } from '@testing-library/react'
import AcknowledgmentPage, { InvestigatorCard } from './AcknowledgmentPage'
import { AWARD } from '../content/links'

describe('AcknowledgmentPage', () => {
  it('renders the award link pointing to the DSAI announcement', () => {
    render(<AcknowledgmentPage />)
    const link = screen.getByRole('link', { name: AWARD.title })
    expect(link.getAttribute('href')).toBe(AWARD.url)
  })

  it('renders Investigators and Contributors headings', () => {
    render(<AcknowledgmentPage />)
    expect(screen.getByText('Investigators')).toBeTruthy()
    expect(screen.getByText('Contributors')).toBeTruthy()
  })
})

describe('InvestigatorCard', () => {
  it('shows a photo when one is provided', () => {
    render(<InvestigatorCard person={{ name: 'Jane Doe', photo: 'jane.jpg', url: 'https://example.org/jane' }} />)
    const img = screen.getByRole('img', { name: 'Jane Doe' })
    expect(img.getAttribute('src')).toMatch(/jane\.jpg$/)
    expect(screen.getByRole('link', { name: 'Jane Doe' }).getAttribute('href')).toBe('https://example.org/jane')
  })

  it('falls back to initials when no photo is provided', () => {
    render(<InvestigatorCard person={{ name: 'Jane Doe' }} />)
    expect(screen.queryByRole('img')).toBeNull()
    expect(screen.getByText('JD')).toBeTruthy()
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/pages/AcknowledgmentPage.test.jsx`
Expected: FAIL — `Failed to resolve import "./AcknowledgmentPage"`.

- [ ] **Step 3: Create the page**

Create `frontend/src/pages/AcknowledgmentPage.jsx`:
```jsx
import { AWARD, ORGS, INVESTIGATORS, CONTRIBUTORS } from '../content/links';

function initials(name) {
  return name.split(/\s+/).map((w) => w[0]).slice(0, 2).join('').toUpperCase();
}

export function InvestigatorCard({ person }) {
  const { name, role, affiliation, url, photo } = person;
  const nameEl = url
    ? <a href={url} target="_blank" rel="noopener noreferrer">{name}</a>
    : name;
  return (
    <div className="person-card">
      {photo
        ? <img className="person-photo" src={`${import.meta.env.BASE_URL}${photo}`} alt={name} />
        : <div className="person-avatar" aria-hidden="true">{initials(name)}</div>}
      <div className="person-info">
        <span className="person-name">{nameEl}</span>
        {role && <span className="person-role">{role}</span>}
        {affiliation && <span className="person-affiliation">{affiliation}</span>}
      </div>
    </div>
  );
}

export default function AcknowledgmentPage() {
  return (
    <div className="content-page">
      <section className="content-section">
        <h2>Award</h2>
        <p>
          This work was supported by the{' '}
          <a href={AWARD.url} target="_blank" rel="noopener noreferrer">{AWARD.title}</a>{' '}
          from the{' '}
          <a href={ORGS.dsai.url} target="_blank" rel="noopener noreferrer">{ORGS.dsai.name}</a>.
        </p>
      </section>

      <section className="content-section">
        <h2>Investigators</h2>
        <div className="person-grid">
          {INVESTIGATORS.map((p) => <InvestigatorCard key={p.name} person={p} />)}
        </div>
      </section>

      <section className="content-section">
        <h2>Contributors</h2>
        <p>
          Platform designed and developed by the{' '}
          <a href={ORGS.dsai.url} target="_blank" rel="noopener noreferrer">{ORGS.dsai.name}</a>,{' '}
          <a href={ORGS.biostat.url} target="_blank" rel="noopener noreferrer">{ORGS.biostat.name}</a>, and{' '}
          <a href={ORGS.intlHealth.url} target="_blank" rel="noopener noreferrer">{ORGS.intlHealth.name}</a>{' '}
          at Johns Hopkins.
        </p>
        <div className="person-grid">
          {CONTRIBUTORS.map((p) => <InvestigatorCard key={p.name} person={p} />)}
        </div>
      </section>
    </div>
  );
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd frontend && npx vitest run src/pages/AcknowledgmentPage.test.jsx`
Expected: PASS (4 tests).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/pages/AcknowledgmentPage.jsx frontend/src/pages/AcknowledgmentPage.test.jsx
git commit -m "feat(ack): add Acknowledgment page with award, investigators, contributors (#69)"
```

---

## Task 5: Wire pages into the sidebar + routes

**Files:**
- Modify: `frontend/src/App.jsx` (imports; `icons` object; `navItems`; routes)
- Test: `frontend/src/App.routes.test.js`

- [ ] **Step 1: Write the failing source-level test**

Create `frontend/src/App.routes.test.js`:
```js
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const appSrc = readFileSync(resolve(__dir, 'App.jsx'), 'utf-8')

describe('App navigation & routes (issue #69)', () => {
  it('imports the two new pages', () => {
    expect(appSrc).toContain("import ResourcePage")
    expect(appSrc).toContain("import AcknowledgmentPage")
  })

  it('sidebar has Resource and Acknowledgment entries', () => {
    expect(appSrc).toContain("label: 'Resource'")
    expect(appSrc).toContain("label: 'Acknowledgment'")
  })

  it('defines /resource and /acknowledgment routes', () => {
    expect(appSrc).toContain('path="/resource"')
    expect(appSrc).toContain('path="/acknowledgment"')
  })

  it('no longer references the inline VideosSection', () => {
    expect(appSrc).not.toContain('<VideosSection')
    expect(appSrc).not.toContain('function VideosSection')
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/App.routes.test.js`
Expected: FAIL — the "imports the two new pages" / "sidebar has … entries" / "defines … routes" assertions fail. (The VideosSection assertion should already pass from Task 2.)

- [ ] **Step 3: Add imports for the new pages**

In `frontend/src/App.jsx`, after the existing `import AdminPage from './pages/AdminPage';` line, add:
```jsx
import ResourcePage from './pages/ResourcePage';
import AcknowledgmentPage from './pages/AcknowledgmentPage';
```

- [ ] **Step 4: Add the two icons to the `icons` object**

In the `icons` object in `App.jsx`, add these two entries:
```jsx
  resource: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" /><path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
    </svg>
  ),
  acknowledgment: (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="12" cy="8" r="6" /><path d="M15.477 12.89 17 22l-5-3-5 3 1.523-9.11" />
    </svg>
  ),
```

- [ ] **Step 5: Add the two `navItems` entries (between Demo Gallery and the admin push)**

Update the `navItems` array in `Sidebar()` so it reads:
```jsx
  const navItems = [
    { path: '/', label: 'Calibrate', icon: icons.calibrate },
    { path: '/demos', label: 'Demo Gallery', icon: icons.demos },
    { path: '/resource', label: 'Resource', icon: icons.resource },
    { path: '/acknowledgment', label: 'Acknowledgment', icon: icons.acknowledgment },
  ];

  if (user.role === 'admin') {
    navItems.push({ path: '/admin', label: 'Users', icon: icons.admin });
  }
```

- [ ] **Step 6: Add the two routes**

In the `<Routes>` block, after the `/demos` route and before `/admin`, add:
```jsx
            <Route path="/resource" element={
              <ProtectedRoute>
                <PageHeader title="Resource" subtitle="Source code, references, and introduction videos" />
                <ResourcePage />
              </ProtectedRoute>
            } />
            <Route path="/acknowledgment" element={
              <ProtectedRoute>
                <PageHeader title="Acknowledgment" subtitle="Award, investigators, and contributors" />
                <AcknowledgmentPage />
              </ProtectedRoute>
            } />
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `cd frontend && npx vitest run src/App.routes.test.js`
Expected: PASS (4 tests).

- [ ] **Step 8: Commit**

```bash
git add frontend/src/App.jsx frontend/src/App.routes.test.js
git commit -m "feat(nav): add Resource and Acknowledgment sidebar tabs + routes (#69)"
```

---

## Task 6: Running credit line in PageHeader

**Files:**
- Modify: `frontend/src/App.jsx` (`PageHeader` component + import `CREDIT`)
- Test: `frontend/src/App.routes.test.js` (add a `describe` block)

- [ ] **Step 1: Add the failing assertions**

Append to `frontend/src/App.routes.test.js`:
```js
describe('Running credit line (issue #69)', () => {
  it('PageHeader renders a credit line driven by the CREDIT data', () => {
    expect(appSrc).toContain('page-credit')
    expect(appSrc).toContain('CREDIT.prefix')
    expect(appSrc).toContain('CREDIT.parts')
  })

  it('imports CREDIT from the links module', () => {
    expect(appSrc).toContain("import { CREDIT }")
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/App.routes.test.js`
Expected: FAIL — the two new assertions fail (`page-credit` / `CREDIT` not present).

- [ ] **Step 3: Import CREDIT**

In `frontend/src/App.jsx`, add near the other imports:
```jsx
import { CREDIT } from './content/links';
```

- [ ] **Step 4: Render the credit line in PageHeader**

Replace the `PageHeader` component body so it reads:
```jsx
function PageHeader({ title, subtitle }) {
  return (
    <div className="page-header">
      <h1 className="page-title">{title}</h1>
      {subtitle && <p className="page-subtitle">{subtitle}</p>}
      <p className="page-credit">
        {CREDIT.prefix}
        {CREDIT.parts.map((part, i) => (
          <span key={part.label}>
            {i > 0 && ', '}
            <a href={part.url} target="_blank" rel="noopener noreferrer">{part.label}</a>
          </span>
        ))}
        {CREDIT.suffix}
      </p>
    </div>
  );
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `cd frontend && npx vitest run src/App.routes.test.js`
Expected: PASS (6 tests total).

- [ ] **Step 6: Commit**

```bash
git add frontend/src/App.jsx frontend/src/App.routes.test.js
git commit -m "feat(header): add running credit line under page title (#69)"
```

---

## Task 7: Remove the Source citation from the job form

**Files:**
- Modify: `frontend/src/components/JobForm.jsx` (delete the `.sample-source` `<small>` at ~line 497)
- Test: `frontend/src/components/JobForm.source.test.js`

- [ ] **Step 1: Write the failing source-level test**

Create `frontend/src/components/JobForm.source.test.js`:
```js
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const jobFormSrc = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')

describe('Source citation moved out of the job form (issue #69)', () => {
  it('no longer renders the sample-source citation', () => {
    expect(jobFormSrc).not.toContain('sample-source')
    expect(jobFormSrc).not.toContain('R package version 2.0. COMSA Mozambique data.')
  })

  it('still keeps the sample CSV download links', () => {
    expect(jobFormSrc).toContain('sample-links')
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/components/JobForm.source.test.js`
Expected: FAIL — the "no longer renders" assertion fails (the citation is still present at line 497).

- [ ] **Step 3: Delete the citation line**

In `frontend/src/components/JobForm.jsx`, delete the single line (currently line 497):
```jsx
              <small className="sample-source">Source: Pramanik S, Wilson E, Fiksel J, Gilbert B, Datta A (2025). <a href="https://github.com/VA-calibration/vacalibration" target="_blank" rel="noopener noreferrer"><em>vacalibration: Calibration of Computer-Coded Verbal Autopsy Algorithm</em></a>. R package version 2.0. COMSA Mozambique data.</small>
```
Leave the surrounding `.sample-download` / `.sample-links` block (lines 490-496, 498) intact.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd frontend && npx vitest run src/components/JobForm.source.test.js`
Expected: PASS (2 tests).
Run: `cd frontend && npx vitest run` (full suite)
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/JobForm.jsx frontend/src/components/JobForm.source.test.js
git commit -m "refactor(form): move sample-data source citation to Resource page (#69)"
```

---

## Task 8: Styles for the credit line, content pages, and people cards

**Files:**
- Modify: `frontend/src/App.css` (append a new section)

This task is presentational; verification is build + lint + visual (no unit test).

- [ ] **Step 1: Append the styles**

Add to the end of `frontend/src/App.css`:
```css
/* ========================================
   Issue #69 — Credit line, content pages, people cards
   ======================================== */
.page-credit {
  margin-top: 0.35rem;
  font-size: 0.8rem;
  color: var(--color-text-secondary);
}
.page-credit a {
  color: var(--color-accent);
  text-decoration: none;
}
.page-credit a:hover { text-decoration: underline; }

.content-page {
  padding: 1.5rem 2.5rem 2rem;
  max-width: 900px;
}
.content-section { margin-bottom: 2rem; }
.content-section h2 {
  font-size: 1.05rem;
  font-weight: 600;
  color: var(--color-text);
  margin-bottom: 0.75rem;
}
.content-section a { color: var(--color-accent); }
.link-list,
.reference-list {
  padding-left: 1.25rem;
  line-height: 1.7;
}
.content-page .sample-source {
  font-size: 0.85rem;
  color: var(--color-text-secondary);
}

.person-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
  gap: 1rem;
  margin-top: 0.75rem;
}
.person-card {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem;
  background: var(--color-surface);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
}
.person-photo,
.person-avatar {
  width: 48px;
  height: 48px;
  border-radius: 50%;
  flex-shrink: 0;
  object-fit: cover;
}
.person-avatar {
  display: flex;
  align-items: center;
  justify-content: center;
  background: var(--color-accent);
  color: #fff;
  font-weight: 600;
  font-size: 0.95rem;
}
.person-info { display: flex; flex-direction: column; }
.person-name { font-weight: 600; color: var(--color-text); }
.person-role,
.person-affiliation {
  font-size: 0.8rem;
  color: var(--color-text-secondary);
}
```

- [ ] **Step 2: Verify the build and lint pass**

Run: `cd frontend && npm run lint && npm run build`
Expected: lint passes; build succeeds with no errors.

- [ ] **Step 3: Commit**

```bash
git add frontend/src/App.css
git commit -m "style(resource): add credit line, content page, and people-card styles (#69)"
```

---

## Task 9: Populate content + full manual verification

**Files:**
- Modify: `frontend/src/content/links.js` (`INVESTIGATORS`, `CONTRIBUTORS`; correct any URL that 404'd in Task 1)
- (Optional) Add headshot images under `frontend/public/acknowledgment/`

This task depends on user-supplied content (award investigator list + DSAI contributor names/links, optional headshots). Ask the user for these before starting.

- [ ] **Step 1: Populate the investigator and contributor arrays**

Fill `INVESTIGATORS` and `CONTRIBUTORS` in `links.js` using the user-provided list. Example shape (replace with real data):
```js
export const INVESTIGATORS = [
  { name: 'Full Name', role: 'Principal Investigator', affiliation: 'Dept of Biostatistics, JHU', url: 'https://…', photo: null },
  // …one entry per investigator listed in the award image…
];

export const CONTRIBUTORS = [
  { name: 'Full Name', role: 'Lead Developer', affiliation: 'DSAI', url: 'https://…', photo: null },
  // …DSAI folks who built the platform; highlight significant contributors…
];
```
If headshots are provided, drop the files in `frontend/public/acknowledgment/` and set `photo: 'acknowledgment/<file>.jpg'`.

- [ ] **Step 2: Reconcile any URLs flagged in Task 1**

If any department URL or the GitHub repo 404'd in Task 1 Step 1, update the corresponding value in `links.js` to the URL that resolves.

- [ ] **Step 3: Run the full test suite**

Run: `cd frontend && npx vitest run`
Expected: PASS (all suites, including the new files).

- [ ] **Step 4: Manual verification in the browser**

Start backend if needed (per repo convention) and the dev server:
```bash
lsof -ti:8000 || (cd backend && Rscript run.R &)
cd frontend && npm run dev
```
Then in the browser, log in and confirm:
- Sidebar shows: Calibrate → Demo Gallery → **Resource** → **Acknowledgment** (→ Users if admin).
- The credit line "Designed and maintained by DSAI, Dept of Biostat, Dept of International Health at Johns Hopkins" appears under the title on **every** page, with working links.
- **Resource** page: 4 references (links open correct papers), GitHub + CRAN links, the moved sample-data source line, and the Introduction Videos (videos play).
- **Acknowledgment** page: award link works; investigator cards render (photo or initials); contributor section shows the DSAI/department credit with working links.
- **Calibrate** page: the Introduction Videos section is gone, and the form no longer shows the "Source:" citation under the sample CSV links.
- "Powered by … DSAI" footer is unchanged.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/content/links.js frontend/public/acknowledgment 2>/dev/null
git commit -m "content(ack): populate investigators and contributors (#69)"
```

---

## Self-Review (completed by plan author)

- **Spec coverage:** Resource tab (Task 3/5), Acknowledgment tab (Task 4/5), tab order (Task 5), credit line all pages (Task 6), credit wording verbatim (Task 1 data + Task 6), move Source out of form (Task 7) into Resource (Task 3), 4 references + GitHub + CRAN (Task 1/3), videos moved (Task 2/3), hyperlink award + DSAI + departments + individuals (Task 4), photos with text fallback (Task 4 `InvestigatorCard`), highlight contributors (Task 4 Contributors + Task 9), "Powered by" footer untouched (verified in Task 9 manual check), title rename deferred to #68 (not in scope). All covered.
- **Placeholder scan:** No `TODO`/`TBD` in code steps. The empty `INVESTIGATORS`/`CONTRIBUTORS` arrays are valid initial state with a documented shape, populated in Task 9 from required user input — not a code placeholder.
- **Type consistency:** `InvestigatorCard` takes `{ person }` with fields `{ name, role, affiliation, url, photo }` everywhere (Task 4 component, test, and Task 9 data). `CREDIT` shape (`prefix`/`parts[{label,url}]`/`suffix`) is identical across Task 1 data, Task 1 test, and Task 6 render. `PACKAGE_LINKS.github`/`.cran`, `REFERENCES[].url`, `SAMPLE_DATA_SOURCE.text`/`.url`, `AWARD.title`/`.url`, `ORGS.*.name`/`.url` are used consistently across tasks.
