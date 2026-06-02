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

describe('Input Type / Output Type cascade (issue #73)', () => {
  it('defaults to Output from CCVA with a locked Cause Distribution output', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    expect(screen.getByText('Output from CCVA')).toBeTruthy()
    expect(screen.getByText('Cause Distribution')).toBeTruthy()
  })

  it('switching Input Type to Individual VA Records reveals the two outputs', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    fireEvent.click(screen.getByText('Output from CCVA'))     // open Input Type
    fireEvent.click(screen.getByText('Individual VA Records')) // select it
    expect(screen.getByText('Individual Top Cause of Death')).toBeTruthy()
  })
})
