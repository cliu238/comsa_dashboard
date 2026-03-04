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

describe('App tab label (issue #26)', () => {
  it('tab says "Calibrate" not "Submit Job"', () => {
    // The tab in App.jsx should also say "Calibrate"
    expect(appSrc).toMatch(/>\s*Calibrate\s*</)
    expect(appSrc).not.toMatch(/>\s*Submit Job\s*</)
  })
})
