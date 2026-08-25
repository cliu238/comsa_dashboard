import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'
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

  // issue #101, R2 retraction: the package author confirmed a stalled run's interval
  // EQUALS the uncalibrated one's own sampling error -- it is not falsely narrow.
  // There is no stall argument and no stall-based suppression any more.
  it('has a three-argument signature -- no fourth suppression parameter can creep back', () => {
    expect(csmfWhisker.length).toBe(3)
  })
  it('draws the interval unconditionally once bounds and a nonzero bar exist', () => {
    expect(csmfWhisker(0.4, 0.3, 0.5)).not.toBeNull()
  })
})

// issue #101: each facet must carry its own stall flag, because in a multi-algorithm
// run one algorithm can stall while another calibrates normally.
describe('path-correction stall flag (issue #101)', () => {
  it('exposes lambda and the stall flag on a single-algorithm facet, with no ciUnreliable key', () => {
    const stalled = { ...single, lambda_calibpath: 0.99, path_correction_stalled: true }
    const [facet] = buildCsmfFacets(stalled)
    expect(facet.pathCorrectionStalled).toBe(true)
    expect(facet.lambda).toBeCloseTo(0.99, 5)
    expect('ciUnreliable' in facet).toBe(false)
  })

  it('defaults to not-stalled when the backend omits the field (older jobs)', () => {
    const [facet] = buildCsmfFacets(single)
    expect(facet.pathCorrectionStalled).toBe(false)
    expect(facet.lambda).toBeNull()
    expect('ciUnreliable' in facet).toBe(false)
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
    // algorithm contaminates it -- the backend flags it and the facet must carry that.
    expect(by['Ensemble'].pathCorrectionStalled).toBe(true)
    expect(by['Ensemble'].lambda).toBeNull()
  })
})

// issue #101 follow-up: the real wire shape for a missing lambda. jsonlite serialises an R
// NULL inside list() as {} (an empty OBJECT), which `?? null` does NOT catch -- so a raw
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

// issue #101, R2 retraction: a stalled run's interval is drawn again in the chart and
// printed again in the comparison table -- it is the genuine uncertainty of an
// uncalibrated estimate (sampling error only), confirmed against the package author.
// The row is relabelled, via `type`, so the reader still knows no calibration reached it.
describe('table keeps intervals for a stalled run, relabelled (issue #101, R2)', () => {
  it('keeps lower/upper on the calibrated row when stalled', () => {
    const stalled = { ...single, lambda_calibpath: 0.99, path_correction_stalled: true }
    const { groups } = buildCsmfTableRows(stalled)
    const cal = groups[0].rows.find(r => r.type !== 'Uncalibrated')
    expect(cal.cells.some(c => c.lower !== null && c.upper !== null)).toBe(true)
    expect(cal.cells.find(c => c.cause === 'prematurity').mean).toBe(30)
  })

  it('uses the exact stalled row-type wording', () => {
    const stalled = { ...single, lambda_calibpath: 0.99, path_correction_stalled: true }
    const { groups } = buildCsmfTableRows(stalled)
    expect(groups[0].rows[1].type).toBe('Calibrated (none applied — interval is the uncalibrated estimate)')
  })

  it('uses the plain Calibrated type when not stalled, and keeps the interval', () => {
    const { groups } = buildCsmfTableRows(single)
    const cal = groups[0].rows.find(r => r.type !== 'Uncalibrated')
    expect(cal.type).toBe('Calibrated')
    const prem = cal.cells.find(c => c.cause === 'prematurity')
    expect(prem.lower).toBe(20)
    expect(prem.upper).toBe(42)
  })

  it('marks only the stalled algorithm\'s row, per facet', () => {
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
    const calOf = grp => grp.rows.find(r => r.type !== 'Uncalibrated')
    expect(calOf(g['EAVA']).type).toBe('Calibrated (none applied — interval is the uncalibrated estimate)')
    expect(calOf(g['InterVA']).type).toBe('Calibrated')
    expect(calOf(g['InterVA']).cells.some(c => c.lower !== null)).toBe(true)
  })
})

// issue #101, R1: a declined run (vacalibration returned calibrated = FALSE because one
// or fewer causes remained) copies p_uncalib verbatim into pcalib_postsumm. The chart
// facet and the summary banner both disclose that; the comparison table did not, so
// exportConsolidatedCSMF() wrote those uncalibrated numbers to disk labelled "Calibrated".
describe('table discloses a declined calibration (issue #101, R1)', () => {
  const DECLINED_TYPE = 'Calibrated (none applied — vacalibration could not calibrate this dataset)'

  it('relabels the calibrated row when calibration_declined is set', () => {
    const declined = { ...single, calibration_declined: true }
    const { groups } = buildCsmfTableRows(declined)
    expect(groups[0].rows[1].type).toBe(DECLINED_TYPE)
  })

  it('requires strict === true, so an unboxed non-flag never relabels the row', () => {
    const { groups } = buildCsmfTableRows({ ...single, calibration_declined: 'FALSE' })
    expect(groups[0].rows[1].type).toBe('Calibrated')
  })

  it('marks only the declined algorithm\'s row, per facet', () => {
    const mixed = {
      ...ensemble,
      per_algorithm: {
        eava:     { ...ensemble.per_algorithm.eava,     calibration_declined: true },
        interva:  { ...ensemble.per_algorithm.interva },
        ensemble: { ...ensemble.per_algorithm.ensemble },
      },
    }
    const { groups } = buildCsmfTableRows(mixed)
    const g = Object.fromEntries(groups.map(x => [x.algorithm, x]))
    const calOf = grp => grp.rows.find(r => r.type !== 'Uncalibrated')
    expect(calOf(g['EAVA']).type).toBe(DECLINED_TYPE)
    expect(calOf(g['InterVA']).type).toBe('Calibrated')
  })

  it('declined and stalled each get their own wording, never a plain "Calibrated"', () => {
    const d = buildCsmfTableRows({ ...single, calibration_declined: true }).groups[0].rows[1].type
    const s = buildCsmfTableRows({ ...single, path_correction_stalled: true }).groups[0].rows[1].type
    expect(d).not.toBe(s)
    expect(d).not.toBe('Calibrated')
    expect(s).not.toBe('Calibrated')
  })
})

// issue #101, R2 retraction: an ensemble whose constituent stalled still shows its own
// intervals (its estimate is a genuine fit built from the per-algorithm draws), and the
// note about the stalled constituent makes no claim about interval width or trustworthiness.
describe('ensemble with a stalled constituent (issue #101, R2)', () => {
  const mixed = {
    ...ensemble,
    per_algorithm: {
      eava:     { ...ensemble.per_algorithm.eava,     lambda_calibpath: 0.99, path_correction_stalled: true },
      interva:  { ...ensemble.per_algorithm.interva,  lambda_calibpath: 0.43, path_correction_stalled: false },
      ensemble: { ...ensemble.per_algorithm.ensemble, path_correction_stalled: false, stalled_constituents: ['eava'] },
    },
  }
  const by = () => Object.fromEntries(buildCsmfFacets(mixed).map(f => [f.label, f]))

  it('carries pathCorrectionStalled per facet, with no ciUnreliable key anywhere', () => {
    expect(by()['EAVA'].pathCorrectionStalled).toBe(true)
    expect(by()['Ensemble'].pathCorrectionStalled).toBe(false)
    expect(by()['InterVA'].pathCorrectionStalled).toBe(false)
    Object.values(by()).forEach(f => expect('ciUnreliable' in f).toBe(false))
  })

  it('names the stalled constituents on the ensemble facet', () => {
    expect(by()['Ensemble'].stalledConstituents).toEqual(['eava'])
  })

  // api/client.js unbox() collapses a ONE-item primitive array to a scalar, so the
  // common case (exactly one algorithm stalled) arrives as the string "eava", not
  // ["eava"]. An Array.isArray() guard alone drops it and the note stops naming the
  // algorithm -- which is the whole point of the field.
  it('accepts the unboxed single-constituent shape (a bare string)', () => {
    const one = {
      ...ensemble,
      per_algorithm: {
        ...ensemble.per_algorithm,
        ensemble: { ...ensemble.per_algorithm.ensemble, stalled_constituents: 'eava' },
      },
    }
    const f = Object.fromEntries(buildCsmfFacets(one).map(x => [x.label, x]))['Ensemble']
    expect(f.stalledConstituents).toEqual(['eava'])
  })

  it('keeps a multi-constituent array unchanged (unbox leaves those alone)', () => {
    const two = {
      ...ensemble,
      per_algorithm: {
        ...ensemble.per_algorithm,
        ensemble: { ...ensemble.per_algorithm.ensemble, stalled_constituents: ['eava', 'insilicova'] },
      },
    }
    const f = Object.fromEntries(buildCsmfFacets(two).map(x => [x.label, x]))['Ensemble']
    expect(f.stalledConstituents).toEqual(['eava', 'insilicova'])
  })

  it('ignores a shape that is neither string nor array', () => {
    const bad = {
      ...ensemble,
      per_algorithm: {
        ...ensemble.per_algorithm,
        ensemble: { ...ensemble.per_algorithm.ensemble, stalled_constituents: {} },
      },
    }
    const f = Object.fromEntries(buildCsmfFacets(bad).map(x => [x.label, x]))['Ensemble']
    expect(f.stalledConstituents).toBeNull()
  })

  it('draws the ensemble whisker unconditionally -- its own row did not stall', () => {
    expect(csmfWhisker(0.4, 0.3, 0.5)).not.toBeNull()
  })

  it('the table keeps the ensemble interval and uses the plain Calibrated type', () => {
    const { groups } = buildCsmfTableRows(mixed)
    const g = Object.fromEntries(groups.map(x => [x.algorithm, x]))
    const calOf = grp => grp.rows.find(r => r.type !== 'Uncalibrated')
    expect(calOf(g['Ensemble']).type).toBe('Calibrated')
    expect(calOf(g['Ensemble']).cells.some(c => c.lower !== null)).toBe(true)
    // the genuinely stalled algorithm keeps the stronger label
    expect(calOf(g['EAVA']).type).toBe('Calibrated (none applied — interval is the uncalibrated estimate)')
  })

  it('older jobs without either field render unchanged, with no ciUnreliable key', () => {
    const [f] = buildCsmfFacets(single)
    expect(f.pathCorrectionStalled).toBe(false)
    expect('ciUnreliable' in f).toBe(false)
  })

  // M5 from the mutation review: `=== true` must not be `?? false`, so a non-boolean
  // never reads as stalled. R can put odd shapes on the wire.
  it('a non-boolean flag never counts as stalled', () => {
    const odd = { ...single, path_correction_stalled: {} }
    const [f] = buildCsmfFacets(odd)
    expect(f.pathCorrectionStalled).toBe(false)
  })

  // issue #101, R2: older stored jobs still carry `ci_unreliable` in their JSON. The
  // field is dead -- nothing may read it, and its presence alone must not suppress an
  // interval or flag anything. This is the proof of that backward compatibility.
  it('a legacy payload carrying only ci_unreliable is read as not-stalled, intervals kept', () => {
    const legacy = { ...single, ci_unreliable: true }
    const [f] = buildCsmfFacets(legacy)
    expect(f.pathCorrectionStalled).toBe(false)
    expect('ciUnreliable' in f).toBe(false)
    const { groups } = buildCsmfTableRows(legacy)
    const cal = groups[0].rows.find(r => r.type !== 'Uncalibrated')
    expect(cal.type).toBe('Calibrated')
    expect(cal.cells.some(c => c.lower !== null && c.upper !== null)).toBe(true)
  })
})

// issue #101 follow-up: the point-mass guard existed only in the chart, so on EVERY run
// (`other` is excluded from calibration by default) the chart hid the whisker while the
// table printed "1% (1-1)" for the same cause. Unrelated to any stall -- kept unchanged.
describe('table drops point-mass intervals too (issue #101 follow-up)', () => {
  const nonStalled = {
    algorithm: 'interva',
    cause_order: ['pneumonia', 'other'],
    path_correction_stalled: false,
    uncalibrated_csmf:   { pneumonia: 0.30, other: 0.013 },
    calibrated_csmf:     { pneumonia: 0.42, other: 0.013 },
    calibrated_ci_lower: { pneumonia: 0.35, other: 0.013 },
    calibrated_ci_upper: { pneumonia: 0.49, other: 0.013 },
  }

  it('drops the CI for a cause whose interval is a point mass', () => {
    const { groups } = buildCsmfTableRows(nonStalled)
    const cal = groups[0].rows.find(r => r.type !== 'Uncalibrated')
    const other = cal.cells.find(c => c.cause === 'other')
    expect(other.mean).toBe(1)
    expect(other.lower).toBeNull()
    expect(other.upper).toBeNull()
  })

  it('keeps the CI for causes with a real interval in the same row', () => {
    const { groups } = buildCsmfTableRows(nonStalled)
    const cal = groups[0].rows.find(r => r.type !== 'Uncalibrated')
    const pneu = cal.cells.find(c => c.cause === 'pneumonia')
    expect(pneu.lower).toBe(35)
    expect(pneu.upper).toBe(49)
  })

  it('chart and table now agree that the point mass has no interval', () => {
    expect(csmfWhisker(0.013, 0.013, 0.013)).toBeNull()
  })
})

// issue #101 follow-up: every scalar arrives from plumber boxed as [x]; api/client.js
// unbox() collapses it before the component sees it. Without that layer `=== true` and
// `typeof === 'number'` both fail and the whole feature silently does nothing, so pin it.
describe('depends on api/client unbox() (issue #101 follow-up)', () => {
  it('boxed scalars would defeat the guards, documenting the dependency', () => {
    const boxed = { ...single, path_correction_stalled: [true], lambda_calibpath: [0.99] }
    const [f] = buildCsmfFacets(boxed)
    expect(f.pathCorrectionStalled).toBe(false)
    expect(f.lambda).toBeNull()
  })

  it('works on the unboxed shape the client actually delivers', () => {
    const unboxed = { ...single, path_correction_stalled: true, lambda_calibpath: 0.99 }
    const [f] = buildCsmfFacets(unboxed)
    expect(f.pathCorrectionStalled).toBe(true)
    expect(f.lambda).toBeCloseTo(0.99, 5)
  })
})

// issue #101 follow-up 2: the degeneracy decision must be made at ONE precision. The
// chart tests raw fractions (ciUpper > ciLower) while the table used to test rounded
// integer percents, so an interval like 0.0131-0.0134 was drawn by the chart and
// suppressed by the table -- the same chart/table disagreement, just reversed.
describe('degeneracy decided on raw bounds, not rounded (issue #101 follow-up 2)', () => {
  const narrowButReal = {
    algorithm: 'interva',
    cause_order: ['other'],
    path_correction_stalled: false,
    uncalibrated_csmf:   { other: 0.013 },
    calibrated_csmf:     { other: 0.0132 },
    calibrated_ci_lower: { other: 0.0131 },
    calibrated_ci_upper: { other: 0.0134 },   // distinct raw bounds, both round to 1%
  }

  it('keeps a real interval whose bounds round to the same percent', () => {
    const { groups } = buildCsmfTableRows(narrowButReal)
    const cal = groups[0].rows.find(r => r.type !== 'Uncalibrated')
    const other = cal.cells.find(c => c.cause === 'other')
    expect(other.lower).not.toBeNull()
    expect(other.upper).not.toBeNull()
  })

  it('agrees with the chart on the same bounds', () => {
    expect(csmfWhisker(0.0132, 0.0131, 0.0134)).not.toBeNull()
  })

  it('still drops a genuine point mass', () => {
    const pointMass = {
      ...narrowButReal,
      calibrated_ci_lower: { other: 0.0132 },
      calibrated_ci_upper: { other: 0.0132 },
    }
    const { groups } = buildCsmfTableRows(pointMass)
    const cal = groups[0].rows.find(r => r.type !== 'Uncalibrated')
    expect(cal.cells.find(c => c.cause === 'other').lower).toBeNull()
    expect(csmfWhisker(0.0132, 0.0132, 0.0132)).toBeNull()
  })
})

// issue #101, R1: the backend already filters zero-death causes out of
// calibrated_csmf/uncalibrated_csmf (assemble_calibration_result()), but
// cause_order is built from the ORIGINAL upload and may still list one.
// orderedCauses() must never reintroduce a cause absent from calibrated_csmf --
// this is the view-model-layer regression net for ROADMAP criterion 2.
describe('hidden zero-death causes cannot reappear via cause_order (issue #101, R1)', () => {
  const withStaleCauseOrder = {
    algorithm: 'eava',
    // cause_order still lists 'injury' even though the backend already
    // excluded it (zero observed deaths) from every cause-keyed field.
    cause_order: ['malaria', 'injury', 'other'],
    uncalibrated_csmf:   { malaria: 0.60, other: 0.40 },
    calibrated_csmf:     { malaria: 0.55, other: 0.45 },
    calibrated_ci_lower: { malaria: 0.45, other: 0.35 },
    calibrated_ci_upper: { malaria: 0.65, other: 0.55 },
  }

  it('buildCsmfFacets() never introduces a cause absent from calibrated_csmf', () => {
    const facets = buildCsmfFacets(withStaleCauseOrder)
    facets.forEach(f => expect(f.causes.map(c => c.cause)).not.toContain('injury'))
  })

  it('buildCsmfTableRows() never introduces a cause absent from calibrated_csmf', () => {
    const { causes, groups } = buildCsmfTableRows(withStaleCauseOrder)
    expect(causes).not.toContain('injury')
    groups.forEach(g => g.rows.forEach(r => expect(r.cells.map(c => c.cause)).not.toContain('injury')))
  })
})

// issue #101, R1: filtering zero-death causes out of cause_order made it
// length-variable for the first time. When a single broad cause survives (every
// record maps to `prematurity`), R's toJSON(auto_unbox = TRUE) emits it as a BARE
// STRING -- the same unbox() hazard already handled for stalled_constituents and
// zero_count_causes. `if (!causeOrder)` did not catch it (a non-empty string is
// truthy) and orderCauses() threw "causeOrder.filter is not a function", which
// blanks the entire SPA because there is no React error boundary.
describe('single surviving cause: cause_order arrives unboxed (issue #101, R1)', () => {
  const oneCause = {
    algorithm: 'eava',
    cause_order: 'prematurity',
    calibration_declined: true,
    uncalibrated_csmf:   { prematurity: 1 },
    calibrated_csmf:     { prematurity: 1 },
    calibrated_ci_lower: { prematurity: 1 },
    calibrated_ci_upper: { prematurity: 1 },
  }

  it('buildCsmfFacets() does not throw and keeps the surviving cause', () => {
    const facets = buildCsmfFacets(oneCause)
    expect(facets).toHaveLength(1)
    expect(facets[0].causes.map(c => c.cause)).toEqual(['prematurity'])
  })

  it('buildCsmfTableRows() does not throw and keeps the surviving cause', () => {
    const { causes, groups } = buildCsmfTableRows(oneCause)
    expect(causes).toEqual(['prematurity'])
    expect(groups).toHaveLength(1)
  })
})

// issue #101, R2 retraction: PRs #115/#119/#121 shipped a false-precision claim about a
// stalled run's interval that the package author later disproved. This guard scans every
// component this plan touches -- comments included -- so the retracted story cannot
// silently regress back into the frontend's prose or logic.
describe('Retraction guard: no false-precision framing survives in frontend/src (issue #101, R2)', () => {
  const __dir = dirname(fileURLToPath(import.meta.url))
  const RETRACTION_FILES = ['CSMFChart.js', 'JobDetail.jsx', 'MisclassificationMatrix.jsx']
  const retractionSrc = RETRACTION_FILES
    .map(f => readFileSync(resolve(__dir, f), 'utf-8'))
    .join('\n')
    .toLowerCase()

  const FORBIDDEN_RETRACTION_PATTERNS = [
    'ci_unreliable', 'ciunreliable', 'implausibly', 'not meaningful', 'falsely', 'intervals omitted', '7x',
  ]

  for (const pat of FORBIDDEN_RETRACTION_PATTERNS) {
    it(`contains no retracted phrase (case-insensitive): ${pat}`, () => {
      expect(retractionSrc).not.toContain(pat)
    })
  }
})
