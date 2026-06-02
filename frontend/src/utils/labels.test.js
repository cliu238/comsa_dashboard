import { describe, it, expect } from 'vitest'
import { formatAlgorithmName, formatAlgorithmList, formatAgeGroup } from './labels.js'

describe('formatAlgorithmName', () => {
  it('maps known algorithm keys to proper names', () => {
    expect(formatAlgorithmName('interva')).toBe('InterVA')
    expect(formatAlgorithmName('insilicova')).toBe('InSilicoVA')
    expect(formatAlgorithmName('eava')).toBe('EAVA')
    expect(formatAlgorithmName('ensemble')).toBe('Ensemble')
  })

  it('is case-insensitive', () => {
    expect(formatAlgorithmName('InterVA')).toBe('InterVA')
  })

  it('uppercases unknown keys', () => {
    expect(formatAlgorithmName('foo')).toBe('FOO')
  })

  it('returns empty string for nullish input', () => {
    expect(formatAlgorithmName(null)).toBe('')
    expect(formatAlgorithmName(undefined)).toBe('')
  })
})

describe('formatAlgorithmList', () => {
  it('joins multiple algorithms with commas and proper names', () => {
    expect(formatAlgorithmList(['eava', 'insilicova', 'interva']))
      .toBe('EAVA, InSilicoVA, InterVA')
  })

  it('accepts a single string', () => {
    expect(formatAlgorithmList('eava')).toBe('EAVA')
  })
})

describe('formatAgeGroup', () => {
  it('maps neonate and child to friendly labels', () => {
    expect(formatAgeGroup('neonate')).toBe('Neonate (0-27 days)')
    expect(formatAgeGroup('child')).toBe('Children (1-59 months)')
  })

  it('returns the input unchanged for unknown groups', () => {
    expect(formatAgeGroup('adult')).toBe('adult')
  })
})
