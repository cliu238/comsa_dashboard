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

  it('keeps single file input for non-ensemble vacalibration', () => {
    expect(jobFormSrc).toContain("type=\"file\"")
  })

  it('pipeline ensemble shows checkboxes + single file (no per-algo uploads)', () => {
    expect(jobFormSrc).toContain('algorithm-checkboxes')
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
    // The tab in App.jsx should also say "Calibrate"
    expect(appSrc).toMatch(/>\s*Calibrate\s*</)
    expect(appSrc).not.toMatch(/>\s*Submit Job\s*</)
  })
})
