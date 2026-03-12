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

describe('Multi-upload ensemble UI (issue #27)', () => {
  it('has uploads state array for managing per-algorithm files', () => {
    expect(jobFormSrc).toContain('useState([{ id: nextUploadId++, algorithm:');
  })

  it('shows upload rows when ensemble is checked for vacalibration', () => {
    expect(jobFormSrc).toContain('upload-row')
  })

  it('has add-algorithm button capped at 3 rows', () => {
    expect(jobFormSrc).toContain('Add Algorithm')
    expect(jobFormSrc).toContain('uploads.length < 3')
  })

  it('has remove button for upload rows', () => {
    expect(jobFormSrc).toContain('removeUpload')
  })

  it('filters already-selected algorithms from dropdowns', () => {
    expect(jobFormSrc).toContain('availableAlgorithms')
  })

  it('keeps single file input for non-ensemble vacalibration', () => {
    expect(jobFormSrc).toContain("type=\"file\"")
  })

  it('pipeline ensemble shows checkboxes + single file (no per-algo uploads)', () => {
    expect(jobFormSrc).toContain('algorithm-checkboxes')
  })
})

describe('Ensemble upload validation (issue #27)', () => {
  it('validates all upload rows have a file and algorithm for ensemble submission', () => {
    expect(jobFormSrc).toContain('uploads.some')
  })

  it('syncs algorithms state from uploads when ensemble changes', () => {
    expect(jobFormSrc).toContain('setAlgorithms')
  })
})

describe('App tab label (issue #26)', () => {
  it('tab says "Calibrate" not "Submit Job"', () => {
    // The tab in App.jsx should also say "Calibrate"
    expect(appSrc).toMatch(/>\s*Calibrate\s*</)
    expect(appSrc).not.toMatch(/>\s*Submit Job\s*</)
  })
})
