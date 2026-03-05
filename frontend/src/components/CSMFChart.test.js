import { describe, it, expect } from 'vitest'
import { computeCSMFChartData } from './CSMFChart.js'

const causes = ['prematurity', 'sepsis_meningitis_inf', 'pneumonia']
const uncalibrated = { prematurity: 0.40, sepsis_meningitis_inf: 0.35, pneumonia: 0.25 }
const calibrated   = { prematurity: 0.30, sepsis_meningitis_inf: 0.45, pneumonia: 0.25 }
const ciLower      = { prematurity: 0.20, sepsis_meningitis_inf: 0.30, pneumonia: 0.15 }
const ciUpper      = { prematurity: 0.42, sepsis_meningitis_inf: 0.55, pneumonia: 0.35 }

describe('computeCSMFChartData', () => {
  it('returns one entry per cause', () => {
    const data = computeCSMFChartData(causes, uncalibrated, calibrated, ciLower, ciUpper)
    expect(data).toHaveLength(3)
    expect(data.map(d => d.cause)).toEqual(causes)
  })

  it('computes maxVal from max of uncalibrated, calibrated, and ciUpper', () => {
    // ciUpper for sepsis is 0.55 — highest value overall
    const data = computeCSMFChartData(causes, uncalibrated, calibrated, ciLower, ciUpper)
    // All percentages should be relative to 0.55
    const prematurityCalibratedPct = (0.30 / 0.55) * 100
    expect(data[0].calibratedPct).toBeCloseTo(prematurityCalibratedPct, 5)
  })

  it('error bar lower position is independent of calibrated bar (not clipped)', () => {
    const data = computeCSMFChartData(causes, uncalibrated, calibrated, ciLower, ciUpper)
    // For prematurity: ciLower=0.20, calibrated=0.30
    // Lower error bar must be at ciLower position, NOT clipped to calibrated
    const prem = data.find(d => d.cause === 'prematurity')
    expect(prem.errorBarLowerPct).toBeLessThan(prem.calibratedPct)
    expect(prem.errorBarLowerPct).toBeCloseTo((0.20 / 0.55) * 100, 5)
  })

  it('error bar upper position extends beyond calibrated bar', () => {
    const data = computeCSMFChartData(causes, uncalibrated, calibrated, ciLower, ciUpper)
    const prem = data.find(d => d.cause === 'prematurity')
    expect(prem.errorBarUpperPct).toBeGreaterThan(prem.calibratedPct)
    expect(prem.errorBarUpperPct).toBeCloseTo((0.42 / 0.55) * 100, 5)
  })

  it('handles missing CI data gracefully', () => {
    const data = computeCSMFChartData(causes, uncalibrated, calibrated, null, null)
    data.forEach(d => {
      expect(d.errorBarLowerPct).toBeNull()
      expect(d.errorBarUpperPct).toBeNull()
      expect(d.calibratedPct).toBeGreaterThan(0)
      expect(d.uncalibratedPct).toBeGreaterThan(0)
    })
  })

  it('calibrated bar does not overflow when calibrated > uncalibrated and CI is null', () => {
    // Edge case: calibrated exceeds uncalibrated, no CI data
    const highCalibrated = { prematurity: 0.60, sepsis_meningitis_inf: 0.20, pneumonia: 0.20 }
    const lowUncalibrated = { prematurity: 0.30, sepsis_meningitis_inf: 0.40, pneumonia: 0.30 }
    const data = computeCSMFChartData(causes, lowUncalibrated, highCalibrated, null, null)
    data.forEach(d => {
      expect(d.calibratedPct).toBeLessThanOrEqual(100)
      expect(d.uncalibratedPct).toBeLessThanOrEqual(100)
    })
  })

  it('all percentage values are between 0 and 100', () => {
    const data = computeCSMFChartData(causes, uncalibrated, calibrated, ciLower, ciUpper)
    data.forEach(d => {
      expect(d.uncalibratedPct).toBeGreaterThanOrEqual(0)
      expect(d.uncalibratedPct).toBeLessThanOrEqual(100)
      expect(d.calibratedPct).toBeGreaterThanOrEqual(0)
      expect(d.calibratedPct).toBeLessThanOrEqual(100)
      if (d.errorBarLowerPct !== null) {
        expect(d.errorBarLowerPct).toBeGreaterThanOrEqual(0)
        expect(d.errorBarLowerPct).toBeLessThanOrEqual(100)
      }
      if (d.errorBarUpperPct !== null) {
        expect(d.errorBarUpperPct).toBeGreaterThanOrEqual(0)
        expect(d.errorBarUpperPct).toBeLessThanOrEqual(100)
      }
    })
  })
})
