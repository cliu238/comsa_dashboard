/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import ProgressIndicator from './ProgressIndicator';

// Mock progress utils
vi.mock('../utils/progress', () => ({
  parseProgress: vi.fn(),
  getElapsedTime: vi.fn(() => '2m 15s'),
}));

import { parseProgress } from '../utils/progress';

describe('ProgressIndicator', () => {
  it('renders segmented bar for pipeline jobs', () => {
    parseProgress.mockReturnValue({
      percentage: 50,
      stage: 'Phase 1/2: openVA (2/2) — InSilicoVA 50%',
      phase: 'openva',
      subPhase: 'InSilicoVA',
      phaseProgress: 50,
    });

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />
    );

    expect(screen.getByText(/Phase 1\/2/)).toBeTruthy();
    expect(container.querySelector('.progress-segmented')).toBeTruthy();
    expect(screen.getByText(/Overall: 50%/)).toBeTruthy();
  });

  it('renders simple bar for non-pipeline jobs', () => {
    parseProgress.mockReturnValue({
      percentage: 60,
      stage: 'InterVA: 60%',
      phase: null,
      subPhase: null,
      phaseProgress: null,
    });

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />
    );

    expect(container.querySelector('.progress-bar')).toBeTruthy();
    expect(container.querySelector('.progress-segmented')).toBeNull();
  });

  it('renders compact mode with overall percentage only', () => {
    parseProgress.mockReturnValue({
      percentage: 45,
      stage: 'Phase 1/2: openVA (1/2) — InterVA 60%',
      phase: 'openva',
      subPhase: 'InterVA',
      phaseProgress: 60,
    });

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" compact={true} />
    );

    // Compact mode: no segmented bar
    expect(container.querySelector('.progress-segmented')).toBeNull();
    expect(container.querySelector('.progress-bar-mini')).toBeTruthy();
  });
});
