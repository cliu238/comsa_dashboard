import { describe, it, expect } from 'vitest'
import { formatCauseDisplay, normalizeCauseList, orderCauses, sortCausesByValue } from './causeDisplay.js'

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

  // issue #101, R1 + CR-01: cause_order became length-variable when zero-death
  // causes started being filtered out of it. A run where a single broad cause
  // survives crosses the wire as a BARE STRING (api/client.js unbox()), which is
  // truthy but has no .filter() -- it used to throw and blank the whole SPA.
  it('accepts the unboxed single-cause shape (a bare string) without throwing', () => {
    expect(orderCauses(['prematurity'], 'prematurity')).toEqual(['prematurity'])
  })

  it('puts the single unboxed cause first and appends the rest', () => {
    expect(orderCauses(['pneumonia', 'prematurity'], 'prematurity'))
      .toEqual(['prematurity', 'pneumonia'])
  })

  it('tolerates an unboxed causes list as well', () => {
    expect(orderCauses('prematurity', ['prematurity', 'pneumonia'])).toEqual(['prematurity'])
  })

  it('ignores a non-list causeOrder (jsonlite emits {} for an R NULL)', () => {
    expect(orderCauses(['pneumonia', 'prematurity'], {})).toEqual(['pneumonia', 'prematurity'])
  })

  it('returns original order for an empty causeOrder array', () => {
    expect(orderCauses(['pneumonia', 'prematurity'], [])).toEqual(['pneumonia', 'prematurity'])
  })
})

describe('normalizeCauseList', () => {
  it('keeps an array unchanged', () => {
    expect(normalizeCauseList(['a', 'b'])).toEqual(['a', 'b'])
  })

  it('wraps the unboxed single-item shape', () => {
    expect(normalizeCauseList('a')).toEqual(['a'])
  })

  it('returns [] for null, undefined and the {} an R NULL serialises to', () => {
    expect(normalizeCauseList(null)).toEqual([])
    expect(normalizeCauseList(undefined)).toEqual([])
    expect(normalizeCauseList({})).toEqual([])
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
