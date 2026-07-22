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
