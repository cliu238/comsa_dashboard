import { describe, it, expect } from 'vitest'
import { buildCsmfFacets, buildCsmfTableRows, csmfWhisker } from './CSMFChart.js'

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

describe('csmfWhisker', () => {
  it('scales CI offsets relative to the calibrated bar height', () => {
    const w = csmfWhisker(0.4, 0.3, 0.5)
    expect(w.bottomPct).toBeCloseTo(75, 5)   // 0.3/0.4
    expect(w.heightPct).toBeCloseTo(50, 5)   // (0.5-0.3)/0.4
  })
  it('works for a small calibrated bar (offsets exceed 100%)', () => {
    const w = csmfWhisker(0.1, 0.05, 0.2)
    expect(w.bottomPct).toBeCloseTo(50, 5)
    expect(w.heightPct).toBeCloseTo(150, 5)
  })
  it('returns null when CI is missing or calibrated is 0', () => {
    expect(csmfWhisker(0.4, null, 0.5)).toBeNull()
    expect(csmfWhisker(0.4, 0.3, null)).toBeNull()
    expect(csmfWhisker(0, 0.3, 0.5)).toBeNull()
  })

  // issue #101: when path correction stalls at lambda = 0.99 the intervals come back
  // ~7x too tight, so drawing them would assert a certainty the model never had.
  it('returns null when path correction stalled', () => {
    expect(csmfWhisker(0.4, 0.3, 0.5, true)).toBeNull()
  })
  it('still draws the CI when path correction did not stall', () => {
    expect(csmfWhisker(0.4, 0.3, 0.5, false)).not.toBeNull()
    expect(csmfWhisker(0.4, 0.3, 0.5, undefined)).not.toBeNull()
  })
})

// issue #101: each facet must carry its own stall flag, because in a multi-algorithm
// run one algorithm can stall while another calibrates normally.
describe('path-correction stall flag (issue #101)', () => {
  it('exposes lambda and the stall flag on a single-algorithm facet', () => {
    const stalled = { ...single, lambda_calibpath: 0.99, path_correction_stalled: true }
    const [facet] = buildCsmfFacets(stalled)
    expect(facet.pathCorrectionStalled).toBe(true)
    expect(facet.lambda).toBeCloseTo(0.99, 5)
  })

  it('defaults to not-stalled when the backend omits the field (older jobs)', () => {
    const [facet] = buildCsmfFacets(single)
    expect(facet.pathCorrectionStalled).toBe(false)
    expect(facet.lambda).toBeNull()
  })

  it('flags only the algorithms that actually stalled', () => {
    const mixed = {
      ...ensemble,
      per_algorithm: {
        eava:     { ...ensemble.per_algorithm.eava,     lambda_calibpath: 0.99, path_correction_stalled: true },
        interva:  { ...ensemble.per_algorithm.interva,  lambda_calibpath: 0.40, path_correction_stalled: false },
        ensemble: { ...ensemble.per_algorithm.ensemble, path_correction_stalled: true },
      },
    }
    const facets = buildCsmfFacets(mixed)
    const by = Object.fromEntries(facets.map(f => [f.label, f]))
    expect(by['EAVA'].pathCorrectionStalled).toBe(true)
    expect(by['InterVA'].pathCorrectionStalled).toBe(false)
    // The ensemble posterior is built from the per-algorithm draws, so one stalled
    // algorithm contaminates it — the backend flags it and the facet must carry that.
    expect(by['Ensemble'].pathCorrectionStalled).toBe(true)
    expect(by['Ensemble'].lambda).toBeNull()
  })
})

// issue #101 follow-up: the real wire shape for a missing lambda. jsonlite serialises an R
// NULL inside list() as {} (an empty OBJECT), which `?? null` does NOT catch — so a raw
// `facet.lambda.toFixed()` throws and, with no error boundary, blanks the page. The
// ensemble facet always hits this, i.e. exactly when the stall note is rendered.
describe('lambda wire shapes (issue #101)', () => {
  it('treats an empty object (R NULL) as no lambda', () => {
    const [f] = buildCsmfFacets({ ...single, lambda_calibpath: {}, path_correction_stalled: true })
    expect(f.lambda).toBeNull()
  })

  it('treats the string "NA" (R NA_real_) as no lambda', () => {
    const [f] = buildCsmfFacets({ ...single, lambda_calibpath: 'NA', path_correction_stalled: true })
    expect(f.lambda).toBeNull()
  })

  it('keeps a genuine number', () => {
    const [f] = buildCsmfFacets({ ...single, lambda_calibpath: 0.99, path_correction_stalled: true })
    expect(f.lambda).toBeCloseTo(0.99, 5)
  })

  it('ensemble facet with {} lambda is still flagged and exposes a formattable lambda', () => {
    const mixed = {
      ...ensemble,
      per_algorithm: {
        eava:     { ...ensemble.per_algorithm.eava,     lambda_calibpath: 0.99, path_correction_stalled: true },
        interva:  { ...ensemble.per_algorithm.interva,  lambda_calibpath: 0.43, path_correction_stalled: false },
        ensemble: { ...ensemble.per_algorithm.ensemble, lambda_calibpath: {},   path_correction_stalled: true },
      },
    }
    const by = Object.fromEntries(buildCsmfFacets(mixed).map(f => [f.label, f]))
    expect(by['Ensemble'].pathCorrectionStalled).toBe(true)
    expect(by['Ensemble'].lambda).toBeNull()
    // the guard the render relies on: null is skipped, a number is formattable
    expect(typeof by['EAVA'].lambda === 'number' && by['EAVA'].lambda.toFixed(2)).toBe('0.99')
  })
})

// issue #101: a point-mass interval (lower == upper) claims perfect certainty. vacalibration
// returns exactly that for every cause it did not calibrate (`other` is excluded by default,
// so every run has at least one), independently of whether path correction stalled.
describe('degenerate interval guard (issue #101)', () => {
  it('returns null when lower equals upper', () => {
    expect(csmfWhisker(0.084, 0.084, 0.084)).toBeNull()
  })

  it('returns null when the interval is inverted', () => {
    expect(csmfWhisker(0.2, 0.3, 0.1)).toBeNull()
  })

  it('still draws a genuine interval', () => {
    expect(csmfWhisker(0.4, 0.3, 0.5)).not.toBeNull()
  })
})

// issue #101: the CSMF Comparison table sits directly under the chart and shares its numbers.
// Suppressing the whiskers while the table still prints "22% (20-24)" would show two
// contradictory claims on one page — and the table is what gets exported.
describe('table suppresses CI when path correction stalled (issue #101)', () => {
  it('drops lower/upper on the calibrated row when stalled', () => {
    const stalled = { ...single, lambda_calibpath: 0.99, path_correction_stalled: true }
    const { groups } = buildCsmfTableRows(stalled)
    const cal = groups[0].rows.find(r => r.type.startsWith('Calibrated'))
    expect(cal.cells.every(c => c.lower === null && c.upper === null)).toBe(true)
    expect(cal.cells.find(c => c.cause === 'prematurity').mean).toBe(30)
  })

  it('marks the calibrated row so the omission is not silent', () => {
    const stalled = { ...single, lambda_calibpath: 0.99, path_correction_stalled: true }
    const { groups } = buildCsmfTableRows(stalled)
    expect(groups[0].rows.some(r => /not calibrated/i.test(r.type))).toBe(true)
  })

  it('keeps the CI when path correction did not stall', () => {
    const { groups } = buildCsmfTableRows(single)
    const cal = groups[0].rows.find(r => r.type === 'Calibrated')
    const prem = cal.cells.find(c => c.cause === 'prematurity')
    expect(prem.lower).toBe(20)
    expect(prem.upper).toBe(42)
  })

  it('suppresses per-algorithm CI only for the stalled algorithm', () => {
    const mixed = {
      ...ensemble,
      per_algorithm: {
        eava:     { ...ensemble.per_algorithm.eava,     path_correction_stalled: true },
        interva:  { ...ensemble.per_algorithm.interva,  path_correction_stalled: false },
        ensemble: { ...ensemble.per_algorithm.ensemble, path_correction_stalled: false },
      },
    }
    const { groups } = buildCsmfTableRows(mixed)
    const g = Object.fromEntries(groups.map(x => [x.algorithm, x]))
    const calOf = grp => grp.rows.find(r => /^Calibrated/.test(r.type))
    expect(calOf(g['EAVA']).cells.every(c => c.lower === null)).toBe(true)
    expect(calOf(g['InterVA']).cells.some(c => c.lower !== null)).toBe(true)
  })
})
