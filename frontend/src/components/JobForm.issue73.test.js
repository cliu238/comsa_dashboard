import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const src = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')

describe('Panel heading & required legend (issue #73 items #1, #4)', () => {
  it('heading is "Submit Job", not "Submit New Job"', () => {
    expect(src).toContain('<h2>Submit Job</h2>')
    expect(src).not.toContain('Submit New Job')
  })
  it('shows a "Required fields" legend', () => {
    expect(src).toContain('required-legend')
    expect(src).toContain('Required fields')
  })
  it('marks required field titles with an asterisk span', () => {
    expect(src).toContain('Country <span className="required">*</span>')
    expect(src).toContain('Age Group <span className="required">*</span>')
    expect(src).toContain('Upload VA Data <span className="required">*</span>')
  })
})

describe('Upload label & example script link (issue #73 items #6, #9)', () => {
  it('renames the upload label to "Upload VA Data"', () => {
    expect(src).toContain('Upload VA Data')
    expect(src).not.toContain('VA Data Files (one CSV per selected algorithm)')
  })
  it('links to the vacalibration example repository', () => {
    expect(src).toContain('https://github.com/sandy-pramanik/vacalibration')
  })
})

describe('Timings removed & algorithm order (issue #73 item #2)', () => {
  it('removes all per-algorithm timing hints', () => {
    expect(src).not.toContain('~30sec')
    expect(src).not.toContain('~2-3min')
    expect(src).not.toContain('~1min')
  })
  it('removes ensemble runtime estimates', () => {
    expect(src).not.toContain('Estimated runtime')
    expect(src).not.toContain('will take approximately')
  })
  it('orders algorithm options EAVA, InSilicoVA, InterVA in the calibration block', () => {
    const block = src.slice(src.indexOf('algorithm-checkboxes'))
    const eava = block.indexOf("checked={algorithms.includes('EAVA')}")
    const insilico = block.indexOf("checked={algorithms.includes('InSilicoVA')}")
    const interva = block.indexOf("checked={algorithms.includes('InterVA')}")
    expect(eava).toBeGreaterThan(-1)
    expect(eava).toBeLessThan(insilico)
    expect(insilico).toBeLessThan(interva)
  })
  it('orders the sample CSV links EAVA, InSilicoVA, InterVA', () => {
    const eava = src.indexOf('sample_eava_neonate.csv')
    const insilico = src.indexOf('sample_insilicova_neonate.csv')
    const interva = src.indexOf('sample_interva_neonate.csv')
    expect(eava).toBeLessThan(insilico)
    expect(insilico).toBeLessThan(interva)
  })
})

describe('Uncertainty block restructure (issue #73 item #8)', () => {
  it('uses a heading + a "Propagate" checkbox, not the combined #68 label', () => {
    expect(src).toContain('Uncertainty in CCVA misclassification')
    expect(src).not.toContain('Propagate uncertainty in CCVA misclassification')
    expect(src).toContain("checked={calibModelType === 'Mmatprior'}")
    expect(src).toContain('https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices')
  })
})
