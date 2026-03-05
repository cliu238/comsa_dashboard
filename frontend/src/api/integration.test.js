import { describe, it, expect, beforeAll, afterAll } from 'vitest'
import { spawn } from 'child_process'
import { resolve } from 'path'

const API_BASE = 'http://localhost:8000'
let backendProcess = null

async function isBackendUp() {
  try {
    const res = await fetch(`${API_BASE}/health`, { signal: AbortSignal.timeout(2000) })
    return res.ok
  } catch {
    return false
  }
}

async function waitForBackend(maxWaitMs = 30000) {
  const start = Date.now()
  while (Date.now() - start < maxWaitMs) {
    if (await isBackendUp()) return true
    await new Promise(r => setTimeout(r, 500))
  }
  return false
}

beforeAll(async () => {
  if (await isBackendUp()) return

  const backendDir = resolve(import.meta.dirname, '../../../backend')
  backendProcess = spawn('Rscript', ['run.R'], {
    cwd: backendDir,
    stdio: 'ignore',
    detached: false,
  })
  backendProcess.on('error', () => { backendProcess = null })

  const ready = await waitForBackend()
  if (!ready && backendProcess) {
    backendProcess.kill()
    backendProcess = null
    throw new Error('Backend failed to start within 30s')
  }
}, 35000)

afterAll(() => {
  if (backendProcess) {
    backendProcess.kill()
    backendProcess = null
  }
})

describe('Backend API integration', () => {
  it('GET /health returns ok', async () => {
    const res = await fetch(`${API_BASE}/health`)
    expect(res.ok).toBe(true)
    const data = await res.json()
    expect(data).toHaveProperty('status')
  })

  it('GET /jobs returns jobs array', async () => {
    const res = await fetch(`${API_BASE}/jobs`)
    expect(res.ok).toBe(true)
    const data = await res.json()
    expect(data).toHaveProperty('jobs')
    expect(Array.isArray(data.jobs)).toBe(true)
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
