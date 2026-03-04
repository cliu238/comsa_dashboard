import { describe, it, expect, beforeAll } from 'vitest'

const API_BASE = 'http://localhost:8000'
let backendUp = false

beforeAll(async () => {
  try {
    const res = await fetch(`${API_BASE}/health`, { signal: AbortSignal.timeout(2000) })
    backendUp = res.ok
  } catch {
    backendUp = false
  }
})

describe.skipIf(!backendUp)('Backend API integration', () => {
  it('GET /health returns ok', async () => {
    const res = await fetch(`${API_BASE}/health`)
    expect(res.ok).toBe(true)
    const data = await res.json()
    expect(data).toHaveProperty('status')
  })

  it('GET /jobs returns array', async () => {
    const res = await fetch(`${API_BASE}/jobs`)
    expect(res.ok).toBe(true)
    const data = await res.json()
    expect(Array.isArray(data)).toBe(true)
  })

  it('POST /jobs/demo creates a job', async () => {
    const params = new URLSearchParams({
      job_type: 'vacalibration',
      algorithm: 'InterVA',
      age_group: 'neonate',
      country: 'Mozambique',
      calib_model_type: 'Mmatprior',
      ensemble: 'false',
      n_mcmc: '2000',
      n_burn: '1000',
      n_thin: '1',
    })
    const res = await fetch(`${API_BASE}/jobs/demo?${params}`, { method: 'POST' })
    expect(res.ok).toBe(true)
    const data = await res.json()
    expect(data).toHaveProperty('job_id')
  })
})
