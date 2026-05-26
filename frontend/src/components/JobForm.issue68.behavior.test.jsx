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
  screen.getByLabelText(/Propagate uncertainty in CCVA misclassification/i)

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
