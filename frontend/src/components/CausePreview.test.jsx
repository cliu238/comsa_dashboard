/**
 * @vitest-environment jsdom
 */
import { describe, it, expect } from 'vitest';
import { render } from '@testing-library/react';
import CausePreview from './CausePreview';

describe('CausePreview', () => {
  it('shows denominator headline and excluded warning', () => {
    const { container } = render(<CausePreview algorithmLabel="EAVA" report={{
      total_records: 1190, calibrated_denominator: 940,
      excluded_undetermined: [{ cause: 'Unspecified', count: 250 }],
      unrecognized: [], mapping: [{ input_cause: 'Preterm', broad_cause: 'prematurity', count: 164 }],
      has_errors: false,
    }} />);
    expect(container.textContent).toMatch(/940 of 1190/);
    expect(container.textContent).toMatch(/Unspecified \(250\)/);
    expect(container.querySelector('.cause-preview.has-errors')).toBeNull();
  });

  it('shows unrecognized causes with suggestion as an error', () => {
    const { container } = render(<CausePreview algorithmLabel="InterVA" report={{
      total_records: 5, calibrated_denominator: 3,
      excluded_undetermined: [],
      unrecognized: [{ cause: 'Pnemonia', count: 2, suggestion: 'pneumonia' }],
      mapping: [], has_errors: true,
    }} />);
    expect(container.textContent).toMatch(/Pnemonia/);
    expect(container.textContent).toMatch(/did you mean/i);
    expect(container.textContent).toMatch(/pneumonia/);
    expect(container.textContent).toMatch(/unrecognized/i);
    expect(container.querySelector('.cause-preview.has-errors')).not.toBeNull();
  });
});

// --- Issue #104 item 2: the preview must not swamp the form -----------------
// With three algorithms uploaded the form rendered three full mapping tables
// (~27 rows) inline, pushing Calibrate off-screen. The bulk collapses; anything
// that BLOCKS submission must stay visible without expanding.
describe('CausePreview collapsing (issue #104)', () => {
  const clean = {
    total_records: 1190, calibrated_denominator: 1190,
    excluded_undetermined: [], unrecognized: [],
    mapping: [
      { input_cause: 'Birth asphyxia', broad_cause: 'ipre', count: 288 },
      { input_cause: 'Prematurity', broad_cause: 'prematurity', count: 495 },
    ],
    has_errors: false,
  };

  it('keeps the mapping table collapsed by default', () => {
    const { container } = render(<CausePreview algorithmLabel="InterVA" report={clean} />);
    const details = container.querySelector('details');
    expect(details).toBeTruthy();
    expect(details.open).toBe(false);
    expect(details.querySelector('table.cause-preview-table')).toBeTruthy();
  });

  it('still shows the headline without expanding', () => {
    const { container } = render(<CausePreview algorithmLabel="InterVA" report={clean} />);
    const summaryText = container.querySelector('summary').textContent;
    expect(container.querySelector('.cause-preview-headline').textContent).toMatch(/1190 of 1190/);
    // the row detail is inside the collapsed region, not in the always-visible summary
    expect(summaryText).not.toMatch(/Birth asphyxia/);
  });

  it('summarises how many causes are hidden', () => {
    const { container } = render(<CausePreview algorithmLabel="InterVA" report={clean} />);
    expect(container.querySelector('summary').textContent).toMatch(/2/);
  });

  it('keeps blocking errors visible outside the collapsed region', () => {
    const { container } = render(<CausePreview algorithmLabel="EAVA" report={{
      ...clean, unrecognized: [{ cause: 'hiv', count: 162, suggestion: null }], has_errors: true,
    }} />);
    const unrecognized = container.querySelector('.cause-preview-unrecognized');
    expect(unrecognized).toBeTruthy();
    expect(unrecognized.closest('details')).toBeNull();   // NOT hidden behind the toggle
    expect(unrecognized.textContent).toMatch(/hiv/);
  });

  it('keeps the undetermined-exclusion note visible outside the collapsed region', () => {
    const { container } = render(<CausePreview algorithmLabel="EAVA" report={{
      ...clean, excluded_undetermined: [{ cause: 'Unspecified', count: 250 }],
    }} />);
    const excluded = container.querySelector('.cause-preview-excluded');
    expect(excluded.closest('details')).toBeNull();
    expect(excluded.textContent).toMatch(/Unspecified \(250\)/);
  });

  it('renders no toggle when there is nothing to collapse', () => {
    const { container } = render(<CausePreview algorithmLabel="EAVA" report={{
      ...clean, mapping: [],
    }} />);
    expect(container.querySelector('details')).toBeNull();
  });
});
