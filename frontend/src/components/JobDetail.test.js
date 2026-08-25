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

describe('Summary block wording (issue #72)', () => {
  it('does not render a "Records processed" line', () => {
    expect(jobDetailSrc).not.toContain('Records processed')
  })

  it('uses the shared formatAlgorithmList for algorithm display', () => {
    expect(jobDetailSrc).toContain('formatAlgorithmList(')
  })

  it('uses the shared formatAgeGroup for the age group label', () => {
    expect(jobDetailSrc).toContain('formatAgeGroup(')
  })
})

describe('Consolidated CSMF table (issue #72)', () => {
  it('renders a consolidated table via buildCsmfTableRows', () => {
    expect(jobDetailSrc).toContain('buildCsmfTableRows(')
  })

  it('removes the per-algorithm <details> breakdown', () => {
    expect(jobDetailSrc).not.toContain('per-algorithm-section')
    expect(jobDetailSrc).not.toContain('Per-Algorithm Breakdown')
  })
})

describe('CSMF chart full-width above table (issue #78)', () => {
  it('no longer wraps the chart in the half-width side-by-side panel', () => {
    expect(jobDetailSrc).not.toContain('results-side-by-side')
  })

  it('renders the CSMF chart above the consolidated comparison table', () => {
    const chart = jobDetailSrc.indexOf('Cause-Specific Mortality Fractions (CSMF) Chart')
    const table = jobDetailSrc.indexOf('CSMF Comparison')
    expect(chart).toBeGreaterThan(-1)
    expect(table).toBeGreaterThan(-1)
    expect(chart).toBeLessThan(table)
  })
})

describe('Redundant downloads removed (issue #72)', () => {
  it('removes the bulk "Download Files" section', () => {
    expect(jobDetailSrc).not.toContain('Download Files')
  })

  it('removes the calibration_plot.pdf section', () => {
    expect(jobDetailSrc).not.toContain('calibration_plot.pdf')
    expect(jobDetailSrc).not.toContain('calibration-plot-section')
  })
})

describe('Combined PDF report (issue #91)', () => {
  it('imports exportCombinedPDF from the export utils', () => {
    expect(jobDetailSrc).toContain('exportCombinedPDF')
  })

  it('offers a "Download PDF Report" button in the calibrated results', () => {
    expect(jobDetailSrc).toContain('Download PDF Report')
  })

  it('captures all four sections (inputs, misclassification, chart, table) via refs', () => {
    // The report bundles every result section; each must be ref-wrapped so it can
    // be captured. Empty refs are skipped by exportCombinedPDF at runtime.
    expect(jobDetailSrc).toContain('summaryRef')
    expect(jobDetailSrc).toContain('misclassRef')
    for (const ref of ['summaryRef', 'misclassRef', 'chartRef', 'csmfTableRef']) {
      expect(jobDetailSrc).toContain(`{ ref: ${ref} }`)
    }
  })

  it('names the combined report file with a calibration_report prefix', () => {
    expect(jobDetailSrc).toContain("generateFilename('calibration_report'")
  })
})

describe('Ensemble vs independent multi-algorithm indicator (issue #83)', () => {
  it('bases the ensemble indicator on the actual ensemble flag, not algorithm count', () => {
    // Previously isEnsemble was `results.algorithm.length > 1`, which mislabeled
    // an independent (ensemble-OFF) multi-algorithm run as "Ensemble Mode".
    expect(jobDetailSrc).toContain("results.ensemble === true")
    expect(jobDetailSrc).not.toMatch(/isEnsemble\s*=\s*Array\.isArray\(results\.algorithm\)\s*&&\s*results\.algorithm\.length\s*>\s*1/)
  })

  it('shows a distinct "Independent calibration" indicator for multi-algo without ensemble', () => {
    expect(jobDetailSrc).toContain('isIndependentMulti')
    expect(jobDetailSrc).toContain('Independent calibration')
  })
})

// issue #101, R2 retraction: the package author confirmed a stalled run's interval
// equals the same input's uncalibrated sampling error -- it is not falsely narrow.
// PRs #115/#119/#121 shipped the opposite claim; this section retracts it.
describe('path-correction stall notice (issue #101, R2 retraction)', () => {
  it('calls csmfWhisker with three arguments -- no stall flag suppresses the whisker', () => {
    expect(jobDetailSrc).toContain('csmfWhisker(calibrated, ciLower, ciUpper)')
  })

  it('renders the corrected stalled-row notice', () => {
    expect(jobDetailSrc).toContain('facet.pathCorrectionStalled ? (')
    expect(jobDetailSrc).toContain('No calibration was applied')
  })

  it('keys the ensemble-constituent note on stalledConstituents, not on the retracted ciUnreliable', () => {
    expect(jobDetailSrc).toContain('facet.stalledConstituents?.length ? (')
    expect(jobDetailSrc).not.toContain('ciUnreliable')
  })

  it('never tells the user the stalled-constituent note is about interval width or says "not calibrated"', () => {
    const idx = jobDetailSrc.indexOf('facet.stalledConstituents?.length ? (')
    const block = jobDetailSrc.slice(idx, idx + 400)
    expect(block).not.toMatch(/not calibrated/i)
    expect(block).not.toMatch(/interval/i)
  })

  it('type-checks lambda before formatting it', () => {
    expect(jobDetailSrc).toContain("typeof facet.lambda === 'number'")
  })

  it('passes pathCorrectionStalled (not the retracted ciUnreliable) to MisclassificationMatrix', () => {
    expect(jobDetailSrc).toContain('pathCorrectionStalled=')
  })
})

describe('zero-death cause disclosure (issue #101, R1)', () => {
  it('references zero_count_causes', () => {
    expect(jobDetailSrc).toContain('zero_count_causes')
  })

  it('normalizes both wire shapes (array, or a bare unboxed string)', () => {
    // api/client.js unbox() collapses a one-item array to a scalar, same as
    // stalled_constituents elsewhere in this file (see CSMFChart.js).
    expect(jobDetailSrc).toMatch(
      /Array\.isArray\(results\.zero_count_causes\)\s*\?\s*results\.zero_count_causes\s*:\s*typeof results\.zero_count_causes === 'string'\s*\?\s*\[results\.zero_count_causes\]\s*:\s*\[\]/
    )
  })

  it('maps the excluded causes through formatCauseDisplay', () => {
    const disclosureIdx = jobDetailSrc.indexOf('zero_count_causes')
    const nearby = jobDetailSrc.slice(disclosureIdx, disclosureIdx + 700)
    expect(nearby).toContain('formatCauseDisplay(')
  })

  it('renders a calibration_declined line using strict === true', () => {
    expect(jobDetailSrc).toContain('results.calibration_declined === true')
  })

  it('does not use ?? for the boundary-crossing calibration_declined flag', () => {
    const idx = jobDetailSrc.indexOf('results.calibration_declined')
    const line = jobDetailSrc.slice(Math.max(0, idx - 40), idx + 40)
    expect(line).not.toContain('??')
  })
})
