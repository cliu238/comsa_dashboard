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

describe('Input Type / Output Type (issue #73, narrowed by #79)', () => {
  it('shows the locked Output-from-CCVA input and Cause-Distribution output', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    expect(screen.getByText('Output from CCVA')).toBeTruthy()
    expect(screen.getByText('Cause Distribution')).toBeTruthy()
  })

  it('no longer offers the removed Individual VA Records / Top Cause options (issue #79)', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    // The Input Type is locked text, not a dropdown — clicking it reveals nothing.
    fireEvent.click(screen.getByText('Output from CCVA'))
    expect(screen.queryByText('Individual VA Records')).toBeNull()
    expect(screen.queryByText('Individual Top Cause of Death')).toBeNull()
  })
})
