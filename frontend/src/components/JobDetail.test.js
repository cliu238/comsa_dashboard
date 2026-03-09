import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const jobDetailSrc = readFileSync(resolve(__dir, 'JobDetail.jsx'), 'utf-8')

describe('CSMF full name display (issue #28)', () => {
  it('OpenVA results heading uses full name "Cause-Specific Mortality Fractions (CSMF)"', () => {
    // The openVA results section should spell out the full name
    expect(jobDetailSrc).toContain('Cause-Specific Mortality Fractions (CSMF)')
  })

  it('Calibrated results first CSMF heading uses full name', () => {
    // In CalibratedResults, the first heading mentioning CSMF must spell it out
    // The CSMF Chart heading is the first CSMF reference in calibrated results
    expect(jobDetailSrc).toContain('Cause-Specific Mortality Fractions (CSMF) Chart')
  })

  it('Calibrated results has a subsequent CSMF heading that can use abbreviation', () => {
    // After first use, abbreviation is fine
    expect(jobDetailSrc).toContain('CSMF Comparison')
  })
})
