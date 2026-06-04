/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import JobForm from './JobForm'

vi.mock('../api/client', () => ({
  submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
  getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
}))

const uncertaintyCheckbox = () =>
  screen.getByLabelText(/Propagate/i)

describe('Uncertainty checkbox behavior (issue #68)', () => {
  it('renders a checkbox that is checked by default (propagate = on)', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    const cb = uncertaintyCheckbox()
    expect(cb.type).toBe('checkbox')
    expect(cb.checked).toBe(true)
  })
  it('unchecks when clicked', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    const cb = uncertaintyCheckbox()
    fireEvent.click(cb)
    expect(cb.checked).toBe(false)
  })
})

describe('Form field order (issue #68)', () => {
  it('renders fields in order: Input Type, Output Type, Country, Age Group, CCVA Algorithm, Uncertainty, Upload, MCMC', () => {
    const { container } = render(<JobForm onJobSubmitted={() => {}} />)
    const text = container.textContent
    const sequence = [
      'Input Type',
      'Output Type',
      'Country',
      'Age Group',
      'Computer-Coded Verbal Autopsy (CCVA) Algorithm',
      'Uncertainty in CCVA misclassification',
      'Upload VA Data',
      'MCMC Specifics',
    ]
    const positions = sequence.map((s) => text.indexOf(s))
    positions.forEach((p, i) => expect(p, `"${sequence[i]}" not found`).toBeGreaterThan(-1))
    for (let i = 1; i < positions.length; i++) {
      expect(positions[i], `"${sequence[i]}" should come after "${sequence[i - 1]}"`).toBeGreaterThan(positions[i - 1])
    }
  })
})
