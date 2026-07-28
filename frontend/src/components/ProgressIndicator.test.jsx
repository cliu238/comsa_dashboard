/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi } from 'vitest'
import { render, screen } from '@testing-library/react'
import ProgressIndicator from './ProgressIndicator'

// Mock progress utils
vi.mock('../utils/progress', () => ({
  parseProgress: vi.fn(),
  getElapsedTime: vi.fn(() => '2m 15s'),
  parseAlgorithmProgress: vi.fn(() => null),
}))

import { parseProgress, parseAlgorithmProgress } from '../utils/progress'

describe('ProgressIndicator', () => {
  it('renders segmented bar for pipeline jobs', () => {
    parseProgress.mockReturnValue({
      percentage: 50,
      stage: 'Phase 1/2: openVA (2/2) — InSilicoVA 50%',
      phase: 'openva',
      subPhase: 'InSilicoVA',
      phaseProgress: 50,
    })

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />
    )

    expect(screen.getByText(/Phase 1\/2/)).toBeTruthy()
    expect(container.querySelector('.progress-segmented')).toBeTruthy()
    expect(screen.getByText(/Overall: 50%/)).toBeTruthy()
  })

  it('renders simple bar for non-pipeline jobs', () => {
    parseProgress.mockReturnValue({
      percentage: 60,
      stage: 'InterVA: 60%',
      phase: null,
      subPhase: null,
      phaseProgress: null,
    })

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />
    )

    expect(container.querySelector('.progress-bar')).toBeTruthy()
    expect(container.querySelector('.progress-segmented')).toBeNull()
  })

  it('renders compact mode with overall percentage only', () => {
    parseProgress.mockReturnValue({
      percentage: 45,
      stage: 'Phase 1/2: openVA (1/2) — InterVA 60%',
      phase: 'openva',
      subPhase: 'InterVA',
      phaseProgress: 60,
    })

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" compact={true} />
    )

    // Compact mode: no segmented bar
    expect(container.querySelector('.progress-segmented')).toBeNull()
    expect(container.querySelector('.progress-bar-mini')).toBeTruthy()
  })
})

// --- Issue #104 item 3: one bar per algorithm -------------------------------
describe('ProgressIndicator per-algorithm bars (issue #104)', () => {
  it('renders one labeled bar per algorithm instead of a single overall bar', () => {
    parseProgress.mockReturnValue({
      percentage: 99, stage: 'Calibration: 99%', phase: null, subPhase: null, phaseProgress: null,
    })
    parseAlgorithmProgress.mockReturnValue([
      { name: 'interva', percentage: 100, done: true },
      { name: 'eava', percentage: 100, done: true },
      { name: 'insilicova', percentage: 30, done: false },
    ])

    const { container } = render(<ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />)

    const bars = container.querySelectorAll('.progress-algo')
    expect(bars.length).toBe(3)
    expect(container.textContent).toMatch(/InterVA/)
    expect(container.textContent).toMatch(/EAVA/)
    expect(container.textContent).toMatch(/InSilicoVA/)
    // the in-flight one shows its own percentage, finished ones read Done
    expect(container.textContent).toMatch(/30%/)
    expect(container.textContent).toMatch(/Done/)
    // the single aggregate readout is replaced, not duplicated
    expect(container.querySelector('.progress-percentage')).toBeNull()
    expect(bars[2].querySelector('.progress-fill').style.width).toBe('30%')
  })

  it('falls back to the single bar when calibration has not started', () => {
    parseProgress.mockReturnValue({
      percentage: 60, stage: 'InterVA: 60%', phase: null, subPhase: null, phaseProgress: null,
    })
    parseAlgorithmProgress.mockReturnValue(null)

    const { container } = render(<ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />)

    expect(container.querySelectorAll('.progress-algo').length).toBe(0)
    expect(container.querySelector('.progress-bar')).toBeTruthy()
    expect(container.querySelector('.progress-percentage').textContent).toMatch(/60%/)
  })

  it('never renders per-algorithm bars in compact mode', () => {
    parseProgress.mockReturnValue({
      percentage: 45, stage: 'Calibration: 45%', phase: null, subPhase: null, phaseProgress: null,
    })
    parseAlgorithmProgress.mockReturnValue([{ name: 'interva', percentage: 45, done: false }])

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" compact={true} />
    )
    expect(container.querySelectorAll('.progress-algo').length).toBe(0)
    expect(container.querySelector('.progress-bar-mini')).toBeTruthy()
  })
})
