# Landing Page Design Spec

## Problem

The root URL `/comsa-dashboard/` renders an empty page. Unauthenticated users must manually navigate to `/comsa-dashboard/login`. There is no public-facing page explaining what the platform does.

## Solution

Create a `LandingPage.jsx` component that serves as the public entry point for unauthenticated users at the root route `/`.

## Routing Change

- **Unauthenticated users** visiting `/` see `LandingPage`
- **Authenticated users** visiting `/` see `Dashboard` (current behavior preserved)
- Login and Register pages remain at `/login` and `/register`
- No changes to any other routes

Implementation: Update `App.jsx` to conditionally render `LandingPage` vs `Dashboard` on the `/` route based on auth state.

## Visual Style

Match the existing app design system exactly:
- **Color palette**: `--color-accent: #6366f1`, `--gradient-accent`, `--sidebar-bg: #0f1117`, `--color-bg: #f4f5f7`, `--color-surface: #ffffff`
- **Font**: DM Sans (body), same sizes/weights as existing components
- **Hero background**: Dark gradient matching the auth pages' glassmorphism style
- **Content sections**: Light background (#f4f5f7) with white cards, matching existing component patterns

## Page Sections (top to bottom)

### 1. Hero
- Dark gradient background (linear-gradient from #0f1117 through #1e1b4b to #312e81)
- Subtle radial glow effects (matching auth page style)
- "COMSA" title, "Verbal Autopsy Calibration Platform" subtitle
- One-liner description of the platform's purpose
- Two CTA buttons: "Login" (gradient filled) and "Register" (outlined)
- Login links to `/login`, Register links to `/register`

### 2. Stats Bar
- Dark background (#1e1b4b) bridging hero and content
- Three stats: "7 Countries" | "3 Algorithms" | "15 Cause Types"
- Accent-colored numbers (#818cf8)

### 3. How It Works
- Light background section
- Title: "How It Works" with subtitle
- Three-step horizontal flow with numbered badges:
  1. Upload — "CSV with VA data"
  2. Calibrate — "Bayesian MCMC"
  3. Results — "CSMF, matrices, export"
- Arrow connectors between steps

### 4. Platform Features
- 2x2 grid of feature cards on light background
- Each card: icon, title, short description
- Cards:
  - CSMF Bar Charts — visualize cause-specific mortality fractions
  - Misclassification Matrices — examine algorithm-specific patterns
  - Multi-Algorithm Ensemble — combine InterVA, InSilicoVA, EAVA
  - Export & Reports — download calibrated results

### 5. Calibration Algorithm
- White background section
- Title: "The Calibration Algorithm"
- Subtitle: "Powered by the vacalibration R package"
- Content structured as two sub-parts:

**How it works (paragraph):**
Computer-coded verbal autopsy (CCVA) algorithms like InterVA, InSilicoVA, and EAVA assign causes of death from VA survey data, but they systematically misclassify certain causes. The vacalibration package uses pre-computed misclassification matrices from the CHAMPS (Child Health and Mortality Prevention Surveillance) project — which has gold-standard cause-of-death data — to correct these biases at the population level.

**Method (compact visual/text):**
- Uses Bayesian calibration with Dirichlet-distributed priors on the misclassification matrix M
- MCMC sampling (Stan) propagates uncertainty from M through to the calibrated CSMF estimates
- Produces posterior mean + 95% credible intervals for each cause-specific mortality fraction
- Supports two modes: `Mmatprior` (full Bayesian uncertainty) and `Mmatfixed` (fixed average matrix)
- Ensemble mode combines multiple algorithms for more robust estimates

**Reference link:** Pramanik et al. (2025), Annals of Applied Statistics

### 6. Research Context
- Light background
- Two info cards side by side:
  - Supported Countries: Bangladesh, Ethiopia, Kenya, Mali, Mozambique, Sierra Leone, South Africa
  - Age Groups: Neonate (6 causes), Child (9 causes)
- Link buttons (open in new tabs):
  - "View Publication" → https://doi.org/10.1214/24-AOAS2006
  - "vacalibration on GitHub" → https://github.com/sandy-pramanik/vacalibration

### 7. Footer
- Dark background (#0f1117) matching sidebar
- "Powered by Johns Hopkins Data Science & AI Institute (DSAI)"

## Files Changed

| File | Change |
|------|--------|
| `frontend/src/pages/LandingPage.jsx` | New file — landing page component |
| `frontend/src/App.jsx` | Update `/` route to conditionally render LandingPage vs Dashboard |
| `frontend/src/App.css` | Add landing page styles (scoped with `.landing-*` class prefix) |

## Testing

- Manual verification: visit `/comsa-dashboard/` while logged out — should see landing page
- Manual verification: visit `/comsa-dashboard/` while logged in — should see Dashboard
- Login and Register buttons navigate to correct pages
- Page is responsive (single-column on mobile, content remains readable)
- Existing auth flow and dashboard unchanged
