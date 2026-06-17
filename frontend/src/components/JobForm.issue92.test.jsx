/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi } from 'vitest'
import { render } from '@testing-library/react'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
import JobForm from './JobForm'

vi.mock('../api/client', () => ({
  submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
  getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
}))

const src = readFileSync(resolve(dirname(fileURLToPath(import.meta.url)), 'JobForm.jsx'), 'utf-8')

// Issue #92: the form must proactively state which causes are supported so the
// user can fix unrecognized causes (which are reported, never silently dropped).
describe('Supported-causes hint (issue #92)', () => {
  it('renders the neonate supported-cause list by default', () => {
    const { container } = render(<JobForm onJobSubmitted={() => {}} />)
    expect(container.textContent).toContain('Supported causes')
    expect(container.textContent).toContain('Sepsis/Meningitis')
    expect(container.textContent).toContain('Intrapartum Events')
    expect(container.textContent).not.toContain('Malaria') // a child-only cause
  })

  it('states that unrecognized causes are reported, not dropped', () => {
    const { container } = render(<JobForm onJobSubmitted={() => {}} />)
    expect(container.textContent).toMatch(/never silently dropped/i)
  })

  it('drives the list off ageGroup so it switches for children', () => {
    expect(src).toContain('SUPPORTED_CAUSES[ageGroup]')
    expect(src).toMatch(/child:\s*\[[^\]]*'Malaria'/)
    expect(src).toMatch(/child:\s*\[[^\]]*'Neonatal Causes'/)
  })
})
