/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, fireEvent, waitFor } from '@testing-library/react';

const previewMapping = vi.fn();
vi.mock('../api/client', () => ({
  submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
  getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
  previewMapping: (...args) => previewMapping(...args),
}));

import JobForm from './JobForm';

describe('JobForm cause preview', () => {
  beforeEach(() => { previewMapping.mockReset(); });

  it('disables Calibrate when the preview reports unrecognized causes', async () => {
    previewMapping.mockResolvedValue({
      reports: { interva: {
        total_records: 5, calibrated_denominator: 3, excluded_undetermined: [],
        unrecognized: [{ cause: 'Pnemonia', count: 2, suggestion: 'pneumonia' }],
        mapping: [], has_errors: true,
      } },
    });

    render(<JobForm onJobSubmitted={() => {}} />);
    const file = new File(['ID,cause\n1,Pnemonia\n'], 'interva.csv', { type: 'text/csv' });
    const input = document.querySelector('input[type="file"]');
    fireEvent.change(input, { target: { files: [file] } });

    await waitFor(() => expect(screen.getByText(/Pnemonia/)).toBeTruthy());
    const calibrateBtn = screen.getByRole('button', { name: /^calibrat/i });
    expect(calibrateBtn.disabled).toBe(true);
  });
});
