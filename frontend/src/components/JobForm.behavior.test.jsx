/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import JobForm from './JobForm'

// Stub the API client — these tests are pure UI behavior, no backend calls.
vi.mock('../api/client', () => ({
  submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
  getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
}))

const renderForm = () => render(<JobForm onJobSubmitted={() => {}} />)

const switchToCalibrationOnly = () => {
  // The default jobType is already 'vacalibration' (Calibration Only), so this
  // helper is a no-op in the current code. After the refactor the default may
  // change; at that point this helper will need to drive the CustomSelect.
  // For now: verify the form is in Calibration Only mode, or do nothing.
}

const getAlgoCheckbox = (name) =>
  screen.getByLabelText(new RegExp(`^${name}\\b`, 'i'))

const getEnsembleCheckbox = () =>
  screen.getByLabelText(/Also run ensemble/i)

describe('Calibration Only — algorithms-first flow', () => {
  beforeEach(() => {
    vi.clearAllMocks()
  })

  it('ensemble row is rendered but disabled when only 1 algorithm is selected', () => {
    renderForm()
    switchToCalibrationOnly()

    // Default state: InterVA only.
    const ensemble = getEnsembleCheckbox()
    expect(ensemble).toBeTruthy()
    expect(ensemble.disabled).toBe(true)

    // Hint text is visible.
    expect(screen.getByText(/requires 2\+ algorithms/i)).toBeTruthy()
  })

  it('auto-enables ensemble when user crosses from 1 to 2 algorithms', () => {
    renderForm()
    switchToCalibrationOnly()

    const ensemble = getEnsembleCheckbox()
    expect(ensemble.checked).toBe(false)

    fireEvent.click(getAlgoCheckbox('InSilicoVA'))

    expect(ensemble.disabled).toBe(false)
    expect(ensemble.checked).toBe(true)
  })

  it('respects sticky-uncheck: once user unchecks ensemble, do not auto-re-enable on re-crossing', () => {
    renderForm()
    switchToCalibrationOnly()

    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    const ensemble = getEnsembleCheckbox()
    expect(ensemble.checked).toBe(true)

    fireEvent.click(ensemble)
    expect(ensemble.checked).toBe(false)

    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    expect(ensemble.disabled).toBe(true)

    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    expect(ensemble.disabled).toBe(false)
    expect(ensemble.checked).toBe(false)
  })

  it('renders one labeled upload row per selected algorithm, regardless of ensemble', () => {
    renderForm()
    switchToCalibrationOnly()

    expect(screen.getAllByText(/^InterVA/i).length).toBeGreaterThanOrEqual(1)
    expect(screen.queryByText(/^InSilicoVA/i)).toBeNull()

    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    expect(screen.getAllByText(/^InterVA/i).length).toBeGreaterThanOrEqual(1)
    expect(screen.getAllByText(/^InSilicoVA/i).length).toBeGreaterThanOrEqual(1)

    const fileInputs = document.querySelectorAll('input[type="file"]')
    expect(fileInputs.length).toBe(2)
  })
})
