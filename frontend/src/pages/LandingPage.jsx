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
            <div className="landing-feature-icon" aria-hidden="true">&#128202;</div>
            <h3>CSMF Bar Charts</h3>
            <p>Visualize cause-specific mortality fractions before and after calibration</p>
          </div>
          <div className="landing-feature-card">
            <div className="landing-feature-icon" aria-hidden="true">&#129518;</div>
            <h3>Misclassification Matrices</h3>
            <p>Examine algorithm-specific misclassification patterns across causes</p>
          </div>
          <div className="landing-feature-card">
            <div className="landing-feature-icon" aria-hidden="true">&#128279;</div>
            <h3>Multi-Algorithm Ensemble</h3>
            <p>Combine InterVA, InSilicoVA, and EAVA for robust ensemble estimates</p>
          </div>
          <div className="landing-feature-card">
            <div className="landing-feature-icon" aria-hidden="true">&#128196;</div>
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
            <li>Two modes: Mmatprior (full Bayesian uncertainty) and Mmatfixed (fixed average matrix)</li>
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
