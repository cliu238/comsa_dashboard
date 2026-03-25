import { describe, it, expect } from 'vitest'
import { formatCauseDisplay, orderCauses, sortCausesByValue } from './causeDisplay.js'

describe('formatCauseDisplay', () => {
  it('uses custom display name when provided', () => {
    const displayNames = { prematurity: 'Preterm', ipre: 'Intrapartum' }
    expect(formatCauseDisplay('prematurity', displayNames)).toBe('Preterm')
    expect(formatCauseDisplay('ipre', displayNames)).toBe('Intrapartum')
  })

  it('falls back to default formatting when no custom names', () => {
    expect(formatCauseDisplay('prematurity', null)).toBe('Prematurity')
    expect(formatCauseDisplay('ipre', null)).toBe('Intrapartum Events')
    expect(formatCauseDisplay('sepsis_meningitis_inf', null)).toBe('Sepsis/Meningitis')
  })

  it('falls back to default when cause not in custom names', () => {
    const displayNames = { prematurity: 'Preterm' }
    expect(formatCauseDisplay('pneumonia', displayNames)).toBe('Pneumonia')
  })

  it('handles undefined displayNames same as null', () => {
    expect(formatCauseDisplay('prematurity', undefined)).toBe('Prematurity')
  })

  it('title-cases unknown causes with underscores replaced', () => {
    expect(formatCauseDisplay('some_new_cause', null)).toBe('Some New Cause')
  })
})

describe('orderCauses', () => {
  it('reorders causes according to causeOrder', () => {
    const causes = ['prematurity', 'pneumonia', 'ipre', 'other']
    const causeOrder = ['pneumonia', 'ipre', 'prematurity', 'other']
    expect(orderCauses(causes, causeOrder)).toEqual(['pneumonia', 'ipre', 'prematurity', 'other'])
  })

  it('returns original order when causeOrder is null', () => {
    const causes = ['prematurity', 'pneumonia', 'ipre']
    expect(orderCauses(causes, null)).toEqual(['prematurity', 'pneumonia', 'ipre'])
  })

  it('returns original order when causeOrder is undefined', () => {
    const causes = ['prematurity', 'pneumonia', 'ipre']
    expect(orderCauses(causes, undefined)).toEqual(['prematurity', 'pneumonia', 'ipre'])
  })

  it('appends causes not in causeOrder at the end', () => {
    const causes = ['prematurity', 'pneumonia', 'ipre', 'other']
    const causeOrder = ['pneumonia', 'ipre']
    expect(orderCauses(causes, causeOrder)).toEqual(['pneumonia', 'ipre', 'prematurity', 'other'])
  })

  it('ignores causeOrder entries not in causes', () => {
    const causes = ['prematurity', 'pneumonia']
    const causeOrder = ['ipre', 'pneumonia', 'prematurity', 'other']
    expect(orderCauses(causes, causeOrder)).toEqual(['pneumonia', 'prematurity'])
  })
})

describe('sortCausesByValue', () => {
  it('sorts causes by descending value', () => {
    const causes = ['pneumonia', 'prematurity', 'ipre', 'other']
    const values = { pneumonia: 0.1, prematurity: 0.4, ipre: 0.3, other: 0.2 }
    expect(sortCausesByValue(causes, values)).toEqual(['prematurity', 'ipre', 'other', 'pneumonia'])
  })

  it('puts zero-value causes at the bottom', () => {
    const causes = ['pneumonia', 'prematurity', 'ipre', 'other']
    const values = { pneumonia: 0, prematurity: 0.5, ipre: 0.3, other: 0 }
    expect(sortCausesByValue(causes, values)).toEqual(['prematurity', 'ipre', 'pneumonia', 'other'])
  })

  it('handles missing values as zero', () => {
    const causes = ['pneumonia', 'prematurity', 'ipre']
    const values = { prematurity: 0.5 }
    expect(sortCausesByValue(causes, values)).toEqual(['prematurity', 'pneumonia', 'ipre'])
  })

  it('does not mutate the original array', () => {
    const causes = ['pneumonia', 'prematurity', 'ipre']
    const values = { pneumonia: 0.1, prematurity: 0.4, ipre: 0.3 }
    sortCausesByValue(causes, values)
    expect(causes).toEqual(['pneumonia', 'prematurity', 'ipre'])
  })
})
