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

describe('Uncertainty propagation control (issue #68 supersedes #25)', () => {
  it('label is the new CCVA wording, not the old matrix wording', () => {
    // Issue #73 item #8 splits the #68 label into a heading + "Propagate" checkbox.
    expect(jobFormSrc).toContain('Uncertainty in CCVA misclassification')
    expect(jobFormSrc).not.toContain('Propagate uncertainty in misclassification matrix')
    expect(jobFormSrc).not.toContain('Uncertainty Propagation')
  })

  it('is a checkbox bound to calibModelType (no Yes/No dropdown options)', () => {
    expect(jobFormSrc).toContain("checked={calibModelType === 'Mmatprior'}")
    expect(jobFormSrc).not.toContain("'Yes (Informative Prior)'")
    expect(jobFormSrc).not.toContain("'No (Fixed misclassification matrix)'")
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
    // Effect syncs uploads from algorithms array (checkboxes are source of truth),
    // sorted into the fixed display order (issue #88).
    expect(jobFormSrc).toContain('.sort((a, b) => algoOrderIndex(a) - algoOrderIndex(b))')
    expect(jobFormSrc).toContain('.map(algo =>')
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
    expect(jobFormSrc).toContain('upload-algo-label');
    // The upload section for vacalibration must be unconditional (not gated on ensemble).
    // Current (bad): jobType === 'vacalibration' && ensemble ? (multi) : (single)
    // New (good):    jobType === 'vacalibration' ? (multi) : (single for pipeline/openva)
    // Guard: the old ternary that gates per-algo upload rows on BOTH vacalibration AND ensemble must be gone.
    expect(jobFormSrc).not.toMatch(
      /jobType === 'vacalibration' && ensemble\s*\?[\s\S]{0,400}upload-row/
    );
  })

  it('renders the algorithm selection as checkboxes (multi-select)', () => {
    expect(jobFormSrc).toContain('algorithm-checkboxes')
  })

  it('renders an always-visible ensemble row tied to the algorithm checkboxes', () => {
    // Anchor the hint to the algorithm-checkboxes JSX block so the assertion
    // verifies the ensemble row sits with the calibration algorithm picker.
    expect(jobFormSrc).toMatch(
      /algorithm-checkboxes[\s\S]{0,2000}requires 2\+ algorithms/i
    );
  })

  it('introduces ensembleUserTouched sentinel for sticky-uncheck behavior', () => {
    expect(jobFormSrc).toMatch(/ensembleUserTouched/)
  })

  it('splits the jobType conditional so pipeline and vacalibration are separate branches', () => {
    // The OLD combined conditional `(jobType === 'vacalibration' || jobType === 'pipeline')`
    // for the ensemble checkbox must not appear in the new code — it has been split.
    expect(jobFormSrc).not.toMatch(
      /\(jobType === ['"]vacalibration['"]\s*\|\|\s*jobType === ['"]pipeline['"]\)[\s\S]{0,200}ensemble-toggle/
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
