import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const appSrc = readFileSync(resolve(__dir, 'App.jsx'), 'utf-8')
const htmlSrc = readFileSync(resolve(__dir, '../index.html'), 'utf-8')

describe('Page title (issue #68)', () => {
  it('Calibrate page heading is the long misclassification title', () => {
    expect(appSrc).toContain('Correcting for Algorithmic Misclassification in Estimating Cause Distributions')
  })
  it('drops the old "Submit and monitor" subtitle', () => {
    expect(appSrc).not.toContain('Submit and monitor verbal autopsy calibration jobs')
  })
})

describe('VA-Calibration branding (issue #68)', () => {
  it('sidebar brand and tab title use the hyphenated "VA-Calibration"', () => {
    expect(appSrc).toContain('VA-Calibration')
    expect(htmlSrc).toContain('VA-Calibration Platform')
  })
  it('no unhyphenated "VA Calibration" remains in App.jsx or index.html', () => {
    expect(appSrc).not.toContain('VA Calibration')
    expect(htmlSrc).not.toContain('VA Calibration')
  })
})
