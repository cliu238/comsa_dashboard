/**
 * @vitest-environment jsdom
 *
 * Render tests for the calibrated results view (issue #101).
 *
 * JobDetail.test.js is entirely source-string greps, which prove a literal appears
 * in the file but nothing about what the view renders. These are the behavioural
 * counterpart: the results view has no React error boundary anywhere in
 * frontend/src, so anything that throws here blanks the entire SPA.
 */
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import { CalibratedResults } from './JobDetail.jsx';

const CAUSES = ['prematurity', 'pneumonia'];

const MMAT = {
  eava: {
    matrix: [[0.8, 0.2], [0.3, 0.7]],
    champs_causes: CAUSES,
    va_causes: CAUSES,
    not_calibrated: 'other',
  },
};

// An ensemble job: the primary row IS the ensemble, which has no lambda of its own,
// so path_correction_stalled is FALSE on it by design. The stalled constituent is
// reported through stalled_constituents instead.
const ensembleWithStalledConstituent = {
  algorithm: ['eava', 'interva'],
  age_group: 'neonate',
  country: 'Mozambique',
  ensemble: true,
  cause_order: CAUSES,
  path_correction_stalled: false,
  stalled_constituents: ['eava'],
  uncalibrated_csmf:   { prematurity: 0.6, pneumonia: 0.4 },
  calibrated_csmf:     { prematurity: 0.55, pneumonia: 0.45 },
  calibrated_ci_lower: { prematurity: 0.45, pneumonia: 0.35 },
  calibrated_ci_upper: { prematurity: 0.65, pneumonia: 0.55 },
  misclassification_matrix: MMAT,
};

const renderResults = (results) =>
  render(<CalibratedResults results={results} jobId="job-101" />);

// issue #101, R2: the panel's near-identity caveat is a statement about the MATRIX,
// not about interval width, so the retraction did not touch it -- but rekeying the
// prop from ci_unreliable to path_correction_stalled silently dropped it for every
// ensemble job, which is the only shape where a constituent can stall unseen.
describe('misclassification stall caveat on an ensemble job (issue #101)', () => {
  it('shows the near-identity caveat when a constituent stalled', () => {
    const { container } = renderResults(ensembleWithStalledConstituent);
    const note = container.querySelector('.matrix-stall-note');
    expect(note).not.toBeNull();
    expect(note.textContent).toContain('close to the identity');
  });

  it('names the stalled constituent rather than blaming the whole run', () => {
    const { container } = renderResults(ensembleWithStalledConstituent);
    expect(container.querySelector('.matrix-stall-note').textContent).toContain('EAVA');
  });

  it('accepts the unboxed single-constituent shape (a bare string)', () => {
    const { container } = renderResults({
      ...ensembleWithStalledConstituent,
      stalled_constituents: 'eava',
    });
    expect(container.querySelector('.matrix-stall-note').textContent).toContain('EAVA');
  });

  it('still shows the caveat for a single-algorithm run whose own lambda stalled', () => {
    const { container } = renderResults({
      ...ensembleWithStalledConstituent,
      algorithm: 'eava',
      ensemble: false,
      stalled_constituents: undefined,
      path_correction_stalled: true,
      lambda_calibpath: 0.99,
    });
    const note = container.querySelector('.matrix-stall-note');
    expect(note.textContent).toContain('0.99');
    expect(note.textContent).toContain('close to the identity');
  });

  it('shows no caveat when nothing stalled', () => {
    const { container } = renderResults({
      ...ensembleWithStalledConstituent,
      stalled_constituents: undefined,
      lambda_calibpath: 0.41,
    });
    expect(container.querySelector('.matrix-stall-note')).toBeNull();
  });
});

// issue #101, R1, plan edge case "one or fewer calibratable causes remain": this is
// the run where vacalibration returns calibrated = FALSE, and the run whose
// cause_order crosses the wire as a bare string. Both land on the same render.
describe('one surviving cause, calibration declined (issue #101, R1)', () => {
  const oneCauseDeclined = {
    algorithm: 'eava',
    age_group: 'neonate',
    country: 'Mozambique',
    ensemble: false,
    // unboxed by api/client.js: a one-element list arrives as a bare scalar
    cause_order: 'prematurity',
    zero_count_causes: ['pneumonia', 'ipre', 'sepsis_meningitis_inf'],
    calibration_declined: true,
    uncalibrated_csmf:   { prematurity: 1 },
    calibrated_csmf:     { prematurity: 1 },
    calibrated_ci_lower: { prematurity: 1 },
    calibrated_ci_upper: { prematurity: 1 },
  };

  it('renders without throwing when cause_order is a bare string', () => {
    const { container } = renderResults(oneCauseDeclined);
    expect(container.querySelector('.results-tab')).not.toBeNull();
  });

  it('discloses that calibration was declined', () => {
    const { container } = renderResults(oneCauseDeclined);
    expect(container.textContent).toContain('Calibration declined');
  });

  it('labels the comparison table row as uncalibrated rather than "Calibrated"', () => {
    const { container } = renderResults(oneCauseDeclined);
    const types = [...container.querySelectorAll('.csmf-table.consolidated .type-cell')]
      .map(td => td.textContent);
    expect(types).toContain('Uncalibrated');
    expect(types).not.toContain('Calibrated');
    expect(types.some(t => t.includes('could not calibrate this dataset'))).toBe(true);
  });

  it('lists the zero-death causes it excluded instead of dropping them silently', () => {
    const { container } = renderResults(oneCauseDeclined);
    const text = container.textContent;
    expect(text).toContain('Excluded from calibration (no observed deaths)');
    expect(text).toContain('Pneumonia');
  });

  it('accepts the unboxed single zero-count cause too', () => {
    const { container } = renderResults({ ...oneCauseDeclined, zero_count_causes: 'pneumonia' });
    expect(container.textContent).toContain('Excluded from calibration (no observed deaths)');
    expect(container.textContent).toContain('Pneumonia');
  });

  it('omits both disclosures on an ordinary run', () => {
    const { container } = renderResults(ensembleWithStalledConstituent);
    expect(container.textContent).not.toContain('Calibration declined');
    expect(container.textContent).not.toContain('Excluded from calibration (no observed deaths)');
  });
});
