import { describe, it, expect } from 'vitest'
import { buildCsmfFacets, buildCsmfTableRows } from './CSMFChart.js'

const single = {
  algorithm: 'eava',
  cause_order: ['prematurity', 'sepsis_meningitis_inf', 'pneumonia'],
  uncalibrated_csmf: { prematurity: 0.40, sepsis_meningitis_inf: 0.35, pneumonia: 0.25 },
  calibrated_csmf:   { prematurity: 0.30, sepsis_meningitis_inf: 0.45, pneumonia: 0.25 },
  calibrated_ci_lower: { prematurity: 0.20, sepsis_meningitis_inf: 0.30, pneumonia: 0.15 },
  calibrated_ci_upper: { prematurity: 0.42, sepsis_meningitis_inf: 0.55, pneumonia: 0.35 },
}

const ensemble = {
  algorithm: ['eava', 'interva'],
  cause_order: ['prematurity', 'pneumonia'],
  uncalibrated_csmf: { prematurity: 0.29, pneumonia: 0.12 },
  calibrated_csmf:   { prematurity: 0.12, pneumonia: 0.09 },
  calibrated_ci_lower: { prematurity: 0.06, pneumonia: 0.02 },
  calibrated_ci_upper: { prematurity: 0.19, pneumonia: 0.21 },
  per_algorithm: {
    eava:     { uncalibrated_csmf: { prematurity: 0.19, pneumonia: 0.24 }, calibrated_csmf: { prematurity: 0.13, pneumonia: 0.24 }, calibrated_ci_lower: { prematurity: 0.05, pneumonia: 0.07 }, calibrated_ci_upper: { prematurity: 0.23, pneumonia: 0.45 } },
    interva:  { uncalibrated_csmf: { prematurity: 0.42, pneumonia: 0.07 }, calibrated_csmf: { prematurity: 0.44, pneumonia: 0.08 }, calibrated_ci_lower: { prematurity: 0.26, pneumonia: 0.01 }, calibrated_ci_upper: { prematurity: 0.62, pneumonia: 0.21 } },
    ensemble: { uncalibrated_csmf: { prematurity: 0.29, pneumonia: 0.12 }, calibrated_csmf: { prematurity: 0.12, pneumonia: 0.09 }, calibrated_ci_lower: { prematurity: 0.06, pneumonia: 0.02 }, calibrated_ci_upper: { prematurity: 0.19, pneumonia: 0.21 } },
  },
}

describe('buildCsmfFacets', () => {
  it('returns a single facet for a single-algorithm result', () => {
    const facets = buildCsmfFacets(single)
    expect(facets).toHaveLength(1)
    expect(facets[0].label).toBe('EAVA')
    expect(facets[0].causes.map(c => c.cause)).toEqual(['prematurity', 'sepsis_meningitis_inf', 'pneumonia'])
  })

  it('keeps raw [0,1] fractions (no maxVal normalization)', () => {
    const facets = buildCsmfFacets(single)
    const prem = facets[0].causes.find(c => c.cause === 'prematurity')
    expect(prem.calibrated).toBeCloseTo(0.30, 5)
    expect(prem.uncalibrated).toBeCloseTo(0.40, 5)
    expect(prem.ciLower).toBeCloseTo(0.20, 5)
    expect(prem.ciUpper).toBeCloseTo(0.42, 5)
  })

  it('returns one facet per algorithm plus ensemble, with ensemble last', () => {
    const facets = buildCsmfFacets(ensemble)
    expect(facets.map(f => f.label)).toEqual(['EAVA', 'InterVA', 'Ensemble'])
  })

  it('orders causes by cause_order across every facet', () => {
    const facets = buildCsmfFacets(ensemble)
    facets.forEach(f => expect(f.causes.map(c => c.cause)).toEqual(['prematurity', 'pneumonia']))
  })

  it('returns [] for nullish input', () => {
    expect(buildCsmfFacets(null)).toEqual([])
  })
})

describe('buildCsmfTableRows', () => {
  it('produces one group per algorithm (ensemble last) with two rows each', () => {
    const { groups } = buildCsmfTableRows(ensemble)
    expect(groups.map(g => g.algorithm)).toEqual(['EAVA', 'InterVA', 'Ensemble'])
    groups.forEach(g => expect(g.rows.map(r => r.type)).toEqual(['Uncalibrated', 'Calibrated']))
  })

  it('falls back to a single group for single-algorithm results', () => {
    const { groups } = buildCsmfTableRows(single)
    expect(groups).toHaveLength(1)
    expect(groups[0].algorithm).toBe('EAVA')
  })

  it('formats values as integer percents; uncalibrated has no CI, calibrated does', () => {
    const { groups } = buildCsmfTableRows(single)
    const [uncal, cal] = groups[0].rows
    const premUncal = uncal.cells.find(c => c.cause === 'prematurity')
    const premCal = cal.cells.find(c => c.cause === 'prematurity')
    expect(premUncal.mean).toBe(40)
    expect(premUncal.lower).toBeNull()
    expect(premCal.mean).toBe(30)
    expect(premCal.lower).toBe(20)
    expect(premCal.upper).toBe(42)
  })

  it('exposes the ordered cause list', () => {
    const { causes } = buildCsmfTableRows(single)
    expect(causes).toEqual(['prematurity', 'sepsis_meningitis_inf', 'pneumonia'])
  })
})
