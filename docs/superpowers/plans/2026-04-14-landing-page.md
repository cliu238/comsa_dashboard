# Landing Page Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a public landing page at `/` for unauthenticated users, showing platform info, features, and login/register CTAs.

**Architecture:** New `LandingPage.jsx` component rendered at `/` when not logged in. Authenticated users still see Dashboard. Styles added to `App.css` with `.landing-*` prefix.

**Tech Stack:** React, React Router, existing CSS design system (DM Sans, indigo/purple palette)

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `frontend/src/pages/LandingPage.jsx` | Create | Landing page component with all 7 sections |
| `frontend/src/App.jsx` | Modify (lines 1-2, 199-205) | Import LandingPage, conditional route rendering |
| `frontend/src/App.css` | Modify (append) | Landing page styles with `.landing-*` class prefix |

---

### Task 1: Create LandingPage component

**Files:**
- Create: `frontend/src/pages/LandingPage.jsx`

- [ ] **Step 1: Create `LandingPage.jsx` with all sections**

```jsx
import { Link } from 'react-router-dom';

export default function LandingPage() {
  return (
    <div className="landing-page">
      {/* Hero */}
      <section className="landing-hero">
        <div className="landing-hero-glow landing-hero-glow--top" />
        <div className="landing-hero-glow landing-hero-glow--bottom" />
        <div className="landing-hero-content">
          <h1 className="landing-hero-title">COMSA</h1>
          <p className="landing-hero-subtitle">Verbal Autopsy Calibration Platform</p>
          <p className="landing-hero-desc">
            Bayesian calibration of cause-of-death classifications using the openVA and vacalibration R packages
          </p>
          <div className="landing-hero-actions">
            <Link to="/login" className="landing-btn landing-btn--primary">Login</Link>
            <Link to="/register" className="landing-btn landing-btn--outline">Register</Link>
          </div>
        </div>
      </section>

      {/* Stats Bar */}
      <section className="landing-stats">
        <div className="landing-stat">
          <span className="landing-stat-number">7</span>
          <span className="landing-stat-label">Countries</span>
        </div>
        <div className="landing-stat">
          <span className="landing-stat-number">3</span>
          <span className="landing-stat-label">Algorithms</span>
        </div>
        <div className="landing-stat">
          <span className="landing-stat-number">15</span>
          <span className="landing-stat-label">Cause Types</span>
        </div>
      </section>

      {/* How It Works */}
      <section className="landing-section">
        <h2 className="landing-section-title">How It Works</h2>
        <p className="landing-section-subtitle">Three steps from raw VA data to calibrated results</p>
        <div className="landing-steps">
          <div className="landing-step">
            <div className="landing-step-badge">1</div>
            <h3>Upload</h3>
            <p>CSV with VA data</p>
          </div>
          <div className="landing-step-arrow">&rarr;</div>
          <div className="landing-step">
            <div className="landing-step-badge">2</div>
            <h3>Calibrate</h3>
            <p>Bayesian MCMC</p>
          </div>
          <div className="landing-step-arrow">&rarr;</div>
          <div className="landing-step">
            <div className="landing-step-badge">3</div>
            <h3>Results</h3>
            <p>CSMF, matrices, export</p>
          </div>
        </div>
      </section>

      {/* Platform Features */}
      <section className="landing-section">
        <h2 className="landing-section-title">Platform Features</h2>
        <p className="landing-section-subtitle">Tools for cause-of-death analysis and calibration</p>
        <div className="landing-features">
          <div className="landing-feature-card">
            <div className="landing-feature-icon">&#128202;</div>
            <h3>CSMF Bar Charts</h3>
            <p>Visualize cause-specific mortality fractions before and after calibration</p>
          </div>
          <div className="landing-feature-card">
            <div className="landing-feature-icon">&#129518;</div>
            <h3>Misclassification Matrices</h3>
            <p>Examine algorithm-specific misclassification patterns across causes</p>
          </div>
          <div className="landing-feature-card">
            <div className="landing-feature-icon">&#128279;</div>
            <h3>Multi-Algorithm Ensemble</h3>
            <p>Combine InterVA, InSilicoVA, and EAVA for robust ensemble estimates</p>
          </div>
          <div className="landing-feature-card">
            <div className="landing-feature-icon">&#128196;</div>
            <h3>Export &amp; Reports</h3>
            <p>Download calibrated results as CSV or generate summary reports</p>
          </div>
        </div>
      </section>

      {/* Calibration Algorithm */}
      <section className="landing-section landing-section--alt">
        <h2 className="landing-section-title">The Calibration Algorithm</h2>
        <p className="landing-section-subtitle">Powered by the vacalibration R package</p>
        <div className="landing-algorithm">
          <div className="landing-algorithm-text">
            <p>
              Computer-coded verbal autopsy (CCVA) algorithms like InterVA, InSilicoVA, and EAVA
              assign causes of death from VA survey data, but they systematically misclassify
              certain causes. The vacalibration package uses pre-computed misclassification matrices
              from the CHAMPS (Child Health and Mortality Prevention Surveillance) project — which
              has gold-standard cause-of-death data — to correct these biases at the population level.
            </p>
          </div>
          <ul className="landing-algorithm-details">
            <li>Bayesian calibration with Dirichlet-distributed priors on the misclassification matrix</li>
            <li>MCMC sampling (Stan) propagates uncertainty through to calibrated CSMF estimates</li>
            <li>Posterior mean + 95% credible intervals for each cause-specific mortality fraction</li>
            <li>Ensemble mode combines multiple algorithms for more robust estimates</li>
          </ul>
          <p className="landing-algorithm-ref">
            <a href="https://doi.org/10.1214/24-AOAS2006" target="_blank" rel="noopener noreferrer">
              Pramanik et al. (2025), Annals of Applied Statistics
            </a>
          </p>
        </div>
      </section>

      {/* Research Context */}
      <section className="landing-section">
        <h2 className="landing-section-title">Research Context</h2>
        <p className="landing-section-subtitle">Supporting verbal autopsy research worldwide</p>
        <div className="landing-research">
          <div className="landing-research-card">
            <h3>Supported Countries</h3>
            <p>Bangladesh, Ethiopia, Kenya, Mali, Mozambique, Sierra Leone, South Africa</p>
          </div>
          <div className="landing-research-card">
            <h3>Age Groups</h3>
            <p>Neonate (6 causes)<br />Child (9 causes)</p>
          </div>
        </div>
        <div className="landing-research-links">
          <a href="https://doi.org/10.1214/24-AOAS2006" target="_blank" rel="noopener noreferrer" className="landing-link-btn">
            View Publication &rarr;
          </a>
          <a href="https://github.com/sandy-pramanik/vacalibration" target="_blank" rel="noopener noreferrer" className="landing-link-btn">
            vacalibration on GitHub &rarr;
          </a>
        </div>
      </section>

      {/* Footer */}
      <footer className="landing-footer">
        <p className="landing-footer-label">Powered by</p>
        <p className="landing-footer-org">Johns Hopkins Data Science &amp; AI Institute (DSAI)</p>
      </footer>
    </div>
  );
}
```

- [ ] **Step 2: Verify file was created**

Run: `ls frontend/src/pages/LandingPage.jsx`
Expected: file exists

---

### Task 2: Update App.jsx routing

**Files:**
- Modify: `frontend/src/App.jsx:1-2,199-205`

- [ ] **Step 1: Add LandingPage import**

In `frontend/src/App.jsx`, add after line 10 (`import RegisterPage`):

```jsx
import LandingPage from './pages/LandingPage';
```

- [ ] **Step 2: Update the `/` route to conditionally render**

In `frontend/src/App.jsx`, replace the existing `/` route (lines 199-205):

```jsx
            <Route path="/" element={
              <ProtectedRoute>
                <PageHeader title="Calibrate" subtitle="Submit and monitor verbal autopsy calibration jobs" />
                <VideosSection />
                <Dashboard />
              </ProtectedRoute>
            } />
```

with:

```jsx
            <Route path="/" element={
              user ? (
                <ProtectedRoute>
                  <PageHeader title="Calibrate" subtitle="Submit and monitor verbal autopsy calibration jobs" />
                  <VideosSection />
                  <Dashboard />
                </ProtectedRoute>
              ) : (
                <LandingPage />
              )
            } />
```

- [ ] **Step 3: Verify the app compiles**

Run: `cd frontend && npm run build`
Expected: build succeeds with no errors

- [ ] **Step 4: Commit**

```bash
git add frontend/src/pages/LandingPage.jsx frontend/src/App.jsx
git commit -m "feat: add landing page component and route (#63)"
```

---

### Task 3: Add landing page styles

**Files:**
- Modify: `frontend/src/App.css` (append at end)

- [ ] **Step 1: Append landing page CSS to App.css**

Add the following at the end of `frontend/src/App.css`:

```css
/* ========================================
   Landing Page
   ======================================== */
.landing-page {
  min-height: 100vh;
  background: var(--color-bg);
}

/* Hero */
.landing-hero {
  position: relative;
  background: linear-gradient(135deg, var(--sidebar-bg) 0%, #1e1b4b 50%, #312e81 100%);
  padding: 5rem 2rem 4rem;
  text-align: center;
  overflow: hidden;
}

.landing-hero-glow {
  position: absolute;
  border-radius: 50%;
  pointer-events: none;
}

.landing-hero-glow--top {
  top: -30%;
  right: -10%;
  width: 500px;
  height: 500px;
  background: radial-gradient(circle, rgba(99, 102, 241, 0.15), transparent 70%);
}

.landing-hero-glow--bottom {
  bottom: -20%;
  left: -10%;
  width: 400px;
  height: 400px;
  background: radial-gradient(circle, rgba(139, 92, 246, 0.1), transparent 70%);
}

.landing-hero-content {
  position: relative;
  z-index: 1;
  max-width: 600px;
  margin: 0 auto;
}

.landing-hero-title {
  font-size: 3rem;
  font-weight: 700;
  color: white;
  margin: 0 0 0.25rem;
  letter-spacing: -0.02em;
}

.landing-hero-subtitle {
  font-size: 1.1rem;
  color: rgba(255, 255, 255, 0.7);
  margin: 0 0 0.5rem;
  letter-spacing: 0.5px;
}

.landing-hero-desc {
  font-size: 0.9rem;
  color: rgba(255, 255, 255, 0.5);
  margin: 0 0 2rem;
  line-height: 1.6;
}

.landing-hero-actions {
  display: flex;
  gap: 0.75rem;
  justify-content: center;
}

.landing-btn {
  padding: 0.65rem 1.75rem;
  border-radius: var(--radius-md);
  font-size: 0.9rem;
  font-weight: 600;
  text-decoration: none;
  transition: all var(--transition-base);
}

.landing-btn--primary {
  background: var(--gradient-accent);
  color: white;
  box-shadow: 0 4px 15px rgba(99, 102, 241, 0.3);
}

.landing-btn--primary:hover {
  transform: translateY(-1px);
  box-shadow: 0 6px 20px rgba(99, 102, 241, 0.4);
}

.landing-btn--outline {
  border: 1px solid rgba(255, 255, 255, 0.3);
  color: white;
}

.landing-btn--outline:hover {
  background: rgba(255, 255, 255, 0.08);
  border-color: rgba(255, 255, 255, 0.5);
}

/* Stats Bar */
.landing-stats {
  display: flex;
  background: #1e1b4b;
  border-top: 1px solid rgba(99, 102, 241, 0.2);
  border-bottom: 1px solid rgba(99, 102, 241, 0.2);
}

.landing-stat {
  flex: 1;
  text-align: center;
  padding: 1.25rem 0;
}

.landing-stat:not(:last-child) {
  border-right: 1px solid rgba(99, 102, 241, 0.15);
}

.landing-stat-number {
  display: block;
  font-size: 1.75rem;
  font-weight: 700;
  color: var(--color-accent-hover);
}

.landing-stat-label {
  display: block;
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.5);
  letter-spacing: 0.5px;
  margin-top: 0.15rem;
}

/* Sections */
.landing-section {
  padding: 3rem 2rem;
  max-width: 900px;
  margin: 0 auto;
}

.landing-section--alt {
  background: var(--color-surface);
  max-width: 100%;
  border-top: 1px solid var(--color-border);
  border-bottom: 1px solid var(--color-border);
}

.landing-section--alt > * {
  max-width: 900px;
  margin-left: auto;
  margin-right: auto;
}

.landing-section-title {
  font-size: 1.35rem;
  font-weight: 700;
  color: var(--color-text);
  text-align: center;
  margin: 0 0 0.25rem;
}

.landing-section-subtitle {
  font-size: 0.85rem;
  color: var(--color-text-secondary);
  text-align: center;
  margin: 0 0 1.5rem;
}

/* How It Works */
.landing-steps {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  justify-content: center;
}

.landing-step {
  flex: 1;
  max-width: 200px;
  background: var(--color-surface);
  padding: 1.25rem 1rem;
  border-radius: var(--radius-md);
  text-align: center;
  border: 1px solid var(--color-border);
}

.landing-step-badge {
  width: 28px;
  height: 28px;
  background: var(--gradient-accent);
  border-radius: var(--radius-sm);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  font-size: 0.8rem;
  font-weight: 700;
  margin: 0 auto 0.6rem;
}

.landing-step h3 {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--color-text);
  margin: 0 0 0.15rem;
}

.landing-step p {
  font-size: 0.75rem;
  color: var(--color-text-secondary);
  margin: 0;
}

.landing-step-arrow {
  color: var(--color-accent);
  font-size: 1.25rem;
  font-weight: 700;
  flex-shrink: 0;
}

/* Features */
.landing-features {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
}

.landing-feature-card {
  background: var(--color-surface);
  padding: 1.25rem;
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
}

.landing-feature-icon {
  font-size: 1.5rem;
  margin-bottom: 0.5rem;
}

.landing-feature-card h3 {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--color-text);
  margin: 0 0 0.25rem;
}

.landing-feature-card p {
  font-size: 0.8rem;
  color: var(--color-text-secondary);
  margin: 0;
  line-height: 1.5;
}

/* Algorithm */
.landing-algorithm {
  background: var(--color-bg);
  border: 1px solid var(--color-border);
  border-radius: var(--radius-md);
  padding: 1.5rem;
}

.landing-algorithm-text p {
  font-size: 0.85rem;
  color: var(--color-text-secondary);
  line-height: 1.7;
  margin: 0 0 1rem;
}

.landing-algorithm-details {
  list-style: none;
  padding: 0;
  margin: 0 0 1rem;
}

.landing-algorithm-details li {
  font-size: 0.8rem;
  color: var(--color-text-secondary);
  padding: 0.3rem 0 0.3rem 1.25rem;
  position: relative;
  line-height: 1.5;
}

.landing-algorithm-details li::before {
  content: '';
  position: absolute;
  left: 0;
  top: 0.65rem;
  width: 6px;
  height: 6px;
  border-radius: 50%;
  background: var(--color-accent);
}

.landing-algorithm-ref {
  margin: 0;
  font-size: 0.8rem;
}

.landing-algorithm-ref a {
  color: var(--color-accent);
  text-decoration: none;
}

.landing-algorithm-ref a:hover {
  text-decoration: underline;
}

/* Research */
.landing-research {
  display: flex;
  gap: 1rem;
  margin-bottom: 1.25rem;
}

.landing-research-card {
  flex: 1;
  background: var(--color-surface);
  padding: 1.25rem;
  border-radius: var(--radius-md);
  border: 1px solid var(--color-border);
  text-align: center;
}

.landing-research-card h3 {
  font-size: 0.9rem;
  font-weight: 600;
  color: var(--color-text);
  margin: 0 0 0.4rem;
}

.landing-research-card p {
  font-size: 0.8rem;
  color: var(--color-text-secondary);
  margin: 0;
  line-height: 1.5;
}

.landing-research-links {
  display: flex;
  gap: 0.75rem;
  justify-content: center;
}

.landing-link-btn {
  display: inline-block;
  padding: 0.5rem 1.25rem;
  background: var(--color-surface);
  border-radius: var(--radius-sm);
  border: 1px solid var(--color-border);
  font-size: 0.8rem;
  font-weight: 600;
  color: var(--color-accent);
  text-decoration: none;
  transition: all var(--transition-base);
}

.landing-link-btn:hover {
  border-color: var(--color-accent);
  background: rgba(99, 102, 241, 0.04);
}

/* Footer */
.landing-footer {
  background: var(--sidebar-bg);
  padding: 1.5rem 2rem;
  text-align: center;
}

.landing-footer-label {
  font-size: 0.75rem;
  color: rgba(255, 255, 255, 0.4);
  margin: 0 0 0.15rem;
}

.landing-footer-org {
  font-size: 0.85rem;
  color: rgba(255, 255, 255, 0.65);
  font-weight: 600;
  margin: 0;
}

/* Mobile responsive */
@media (max-width: 640px) {
  .landing-hero {
    padding: 3rem 1.5rem 2.5rem;
  }

  .landing-hero-title {
    font-size: 2.25rem;
  }

  .landing-steps {
    flex-direction: column;
  }

  .landing-step {
    max-width: 100%;
    width: 100%;
  }

  .landing-step-arrow {
    transform: rotate(90deg);
  }

  .landing-features {
    grid-template-columns: 1fr;
  }

  .landing-research {
    flex-direction: column;
  }

  .landing-research-links {
    flex-direction: column;
    align-items: center;
  }

  .landing-section {
    padding: 2rem 1.5rem;
  }
}
```

- [ ] **Step 2: Verify build still succeeds**

Run: `cd frontend && npm run build`
Expected: build succeeds with no errors

- [ ] **Step 3: Commit**

```bash
git add frontend/src/App.css
git commit -m "style: add landing page styles (#63)"
```

---

### Task 4: Manual verification

- [ ] **Step 1: Start dev server**

Run: `cd frontend && npm run dev`

- [ ] **Step 2: Test unauthenticated view**

Open `http://localhost:5173/comsa-dashboard/` in browser (logged out / incognito).
Expected: Landing page renders with all 7 sections — Hero, Stats, How It Works, Features, Algorithm, Research, Footer. Login and Register buttons are visible.

- [ ] **Step 3: Test navigation**

Click "Login" button.
Expected: navigates to `/comsa-dashboard/login`

Click browser back, then click "Register" button.
Expected: navigates to `/comsa-dashboard/register`

- [ ] **Step 4: Test authenticated view**

Log in with valid credentials.
Expected: redirected to `/comsa-dashboard/` showing the Calibrate dashboard (not the landing page).

- [ ] **Step 5: Test external links**

Click "View Publication" link in Research Context section.
Expected: opens `https://doi.org/10.1214/24-AOAS2006` in a new tab.

Click "vacalibration on GitHub" link.
Expected: opens `https://github.com/sandy-pramanik/vacalibration` in a new tab.

- [ ] **Step 6: Test mobile responsive**

Resize browser to ~375px width.
Expected: steps stack vertically, feature cards become single column, research cards stack.
