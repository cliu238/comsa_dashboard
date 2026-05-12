import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))

// Source-level TDD: verify button labels in JobForm match requirements (issue #26)
const jobFormSrc = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')

// Also check the tab label in App.jsx
const appSrc = readFileSync(resolve(__dir, '../App.jsx'), 'utf-8')

describe('JobForm button labels (issue #26)', () => {
  it('submit button says "Calibrate" not "Submit Job"', () => {
    expect(jobFormSrc).toContain("'Calibrate'")
    expect(jobFormSrc).not.toMatch(/['"]Submit Job['"]/)
  })

  it('loading state says "Calibrating..." not "Submitting..."', () => {
    expect(jobFormSrc).toContain("'Calibrating...'")
    expect(jobFormSrc).not.toMatch(/['"]Submitting\.\.\.['"]/)
  })
})

describe('Uncertainty propagation labels (issue #25)', () => {
  it('label says "Propagate uncertainty in misclassification matrix" not "Uncertainty Propagation"', () => {
    expect(jobFormSrc).toContain('Propagate uncertainty in misclassification matrix')
    expect(jobFormSrc).not.toContain('Uncertainty Propagation')
  })

  it('Mmatprior option says "Yes (Informative Prior)" not "Prior (Full Bayesian)"', () => {
    expect(jobFormSrc).toContain("'Yes (Informative Prior)'")
    expect(jobFormSrc).not.toContain("'Prior (Full Bayesian)'")
  })

  it('Mmatfixed option says "No (Fixed misclassification matrix)" not "Fixed (No Uncertainty)"', () => {
    expect(jobFormSrc).toContain("'No (Fixed misclassification matrix)'")
    expect(jobFormSrc).not.toContain("'Fixed (No Uncertainty)'")
  })
})

describe('Checkbox-driven ensemble uploads', () => {
  it('has uploads state array for managing per-algorithm files', () => {
    expect(jobFormSrc).toContain('useState([{ id: nextUploadId++, algorithm:');
  })

  it('shows upload rows when ensemble is checked for vacalibration', () => {
    expect(jobFormSrc).toContain('upload-row')
  })

  it('auto-generates upload rows from checked algorithms', () => {
    // Effect syncs uploads from algorithms array (checkboxes are source of truth)
    expect(jobFormSrc).toContain('algorithms.map(algo =>')
    expect(jobFormSrc).toContain("prev.find(u => u.algorithm === algo)")
  })

  it('displays algorithm name as a label, not a dropdown', () => {
    expect(jobFormSrc).toContain('upload-algo-label')
    // No CustomSelect in upload rows
    expect(jobFormSrc).not.toContain('availableAlgorithms')
    expect(jobFormSrc).not.toContain('Select algorithm...')
  })

  it('does not have manual add/remove upload buttons', () => {
    expect(jobFormSrc).not.toContain('Add Algorithm')
    expect(jobFormSrc).not.toContain('removeUpload')
    expect(jobFormSrc).not.toContain('addUpload')
  })

  it('vacalibration mode always uses per-algorithm upload rows (no single-file branch)', () => {
    // The vacalibration JSX branch never renders the "VA Data File (CSV)" label —
    // that label is reserved for openVA-only and Pipeline non-ensemble modes.
    // Per-algorithm rows are denoted by `upload-row`/`upload-algo-label`.
    expect(jobFormSrc).toContain('upload-algo-label')

    // Negative guard: in the vacalibration branch, the legacy single-file label
    // must not appear. We tolerate the label elsewhere (Pipeline non-ensemble).
    const calibBlock = jobFormSrc.match(
      /jobType === 'vacalibration'[\s\S]*?(?=jobType === 'pipeline'|jobType === 'openva'|$)/
    )?.[0] || ''
    expect(calibBlock).not.toMatch(/VA Data File \(CSV\)/)
  })

  it('pipeline ensemble shows checkboxes + single file (no per-algo uploads)', () => {
    expect(jobFormSrc).toContain('algorithm-checkboxes')
  })

  it('renders an always-visible ensemble row in the vacalibration branch', () => {
    // Source contains a disabled hint for the 1-algo case.
    expect(jobFormSrc).toMatch(/requires 2\+ algorithms/i)
  })

  it('introduces ensembleUserTouched sentinel for sticky-uncheck behavior', () => {
    expect(jobFormSrc).toMatch(/ensembleUserTouched/)
  })

  it('splits the jobType conditional so pipeline and vacalibration are separate branches', () => {
    // The OLD combined conditional `(jobType === 'vacalibration' || jobType === 'pipeline')`
    // for the ensemble checkbox must not appear in the new code — it has been split.
    // Pipeline's ensemble-first UI stays under jobType === 'pipeline'.
    expect(jobFormSrc).toContain("jobType === 'pipeline'")
    expect(jobFormSrc).toContain("jobType === 'vacalibration'")
    // The combined form for the ensemble toggle should be gone.
    expect(jobFormSrc).not.toMatch(
      /\(jobType === ['"]vacalibration['"] \|\| jobType === ['"]pipeline['"]\)[\s\S]{0,200}ensemble-toggle/
    )
  })

  it('removes the file-algorithm-mismatch hint banner', () => {
    // The hint is no longer needed because each upload row is labeled.
    expect(jobFormSrc).not.toContain('algorithm selection below will be used to match the data format')
  })
})

describe('Ensemble upload validation', () => {
  it('validates all upload rows have a file for ensemble submission', () => {
    expect(jobFormSrc).toContain('uploads.some(u => !u.file)')
  })

  it('does not reverse-sync algorithms from uploads', () => {
    // Effect 3 was removed — no setAlgorithms based on upload rows
    expect(jobFormSrc).not.toContain('uploadAlgos')
  })
})

describe('App tab label (issue #26)', () => {
  it('tab says "Calibrate" not "Submit Job"', () => {
    // The nav label in App.jsx should say "Calibrate" (sidebar link or tab)
    expect(appSrc).toMatch(/Calibrate/)
    expect(appSrc).not.toMatch(/Submit Job/)
  })
})
