/**
 * @vitest-environment jsdom
 *
 * Issue #88: the upload rows must follow the same fixed display order as the
 * selection panel (EAVA -> InSilicoVA -> InterVA), NOT the order the user
 * happened to check the algorithm checkboxes.
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/react'
import { screen } from '@testing-library/dom'
import JobForm from './JobForm'

vi.mock('../api/client', () => ({
  submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
  getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
}))

const renderForm = () => render(<JobForm onJobSubmitted={() => {}} />)
const getAlgoCheckbox = (name) =>
  screen.getByLabelText(new RegExp(`^${name}\\b`, 'i'))

const uploadRowAlgos = (container) =>
  Array.from(container.querySelectorAll('.upload-row .upload-algo-label')).map(
    (el) => el.textContent.trim()
  )

describe('Upload-row order matches selection-panel order (issue #88)', () => {
  beforeEach(() => vi.clearAllMocks())

  it('orders rows EAVA -> InterVA even when InterVA was selected first', () => {
    // Default state is ['InterVA']; checking EAVA appends it (click order
    // [InterVA, EAVA]). The rows must still render EAVA before InterVA.
    const { container } = renderForm()
    fireEvent.click(getAlgoCheckbox('EAVA'))

    expect(uploadRowAlgos(container)).toEqual(['EAVA', 'InterVA'])
  })

  it('orders all three rows EAVA -> InSilicoVA -> InterVA regardless of check order', () => {
    // Start from default InterVA, then check InSilicoVA, then EAVA — click
    // order [InterVA, InSilicoVA, EAVA]. Rows must be in canonical order.
    const { container } = renderForm()
    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    fireEvent.click(getAlgoCheckbox('EAVA'))

    expect(uploadRowAlgos(container)).toEqual(['EAVA', 'InSilicoVA', 'InterVA'])
  })
})
