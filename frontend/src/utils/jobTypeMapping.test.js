import { describe, it, expect } from 'vitest'
import {
  INPUT_TYPES,
  outputTypeOptions,
  deriveJobType,
  jobTypeToSelectors,
} from './jobTypeMapping.js'

describe('jobTypeMapping (issue #73)', () => {
  it('offers two input types', () => {
    expect(INPUT_TYPES.map((o) => o.value)).toEqual(['individual', 'ccva_output'])
  })

  it('Individual VA Records offers top-cause and distribution outputs', () => {
    expect(outputTypeOptions('individual').map((o) => o.value)).toEqual([
      'top_cause',
      'distribution',
    ])
  })

  it('Output from CCVA locks output to a single distribution option', () => {
    expect(outputTypeOptions('ccva_output').map((o) => o.value)).toEqual(['distribution'])
  })

  it('derives job_type for every valid combination', () => {
    expect(deriveJobType('individual', 'top_cause')).toBe('openva')
    expect(deriveJobType('individual', 'distribution')).toBe('pipeline')
    expect(deriveJobType('ccva_output', 'distribution')).toBe('vacalibration')
  })

  it('falls back to vacalibration for the locked input regardless of output', () => {
    expect(deriveJobType('ccva_output', 'top_cause')).toBe('vacalibration')
  })

  it('inverts a job_type back into selector values', () => {
    expect(jobTypeToSelectors('openva')).toEqual({ inputType: 'individual', outputType: 'top_cause' })
    expect(jobTypeToSelectors('pipeline')).toEqual({ inputType: 'individual', outputType: 'distribution' })
    expect(jobTypeToSelectors('vacalibration')).toEqual({ inputType: 'ccva_output', outputType: 'distribution' })
  })

  it('defaults unknown job_type to the vacalibration selectors', () => {
    expect(jobTypeToSelectors('???')).toEqual({ inputType: 'ccva_output', outputType: 'distribution' })
  })
})
