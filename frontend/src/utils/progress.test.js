import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { parseProgress, getElapsedTime } from './progress.js'

describe('parseProgress', () => {
  it('returns nulls for empty logs', () => {
    expect(parseProgress(null)).toEqual({ percentage: null, stage: null })
    expect(parseProgress([])).toEqual({ percentage: null, stage: null })
    expect(parseProgress(undefined)).toEqual({ percentage: null, stage: null })
  })

  it('parses InterVA percentage', () => {
    const result = parseProgress(['..........60% completed'])
    expect(result.percentage).toBe(60)
    expect(result.stage).toBe('InterVA: 60%')
  })

  it('picks last InterVA percentage when multiple present', () => {
    const result = parseProgress([
      '..........20% completed',
      '..........60% completed',
      '..........90% completed',
    ])
    expect(result.percentage).toBe(90)
    expect(result.stage).toBe('InterVA: 90%')
  })

  it('parses InSilicoVA iteration without total', () => {
    const result = parseProgress(['Iteration: 2000'])
    // Default total is 4000
    expect(result.percentage).toBe(50)
    expect(result.stage).toBe('InSilicoVA: 50%')
  })

  it('parses InSilicoVA iteration with total', () => {
    const result = parseProgress([
      '8000 Iterations to Sample',
      'Iteration: 4000',
    ])
    expect(result.percentage).toBe(50)
    expect(result.stage).toBe('InSilicoVA: 50%')
  })

  it('parses Stan/vacalibration iteration fraction correctly', () => {
    const result = parseProgress(['Chain 1 Iteration: 2500 / 5000'])
    expect(result.percentage).toBe(50)
    expect(result.stage).toBe('Calibration: 50%')
  })

  it('distinguishes InSilicoVA (bare) from Stan (with slash) iterations', () => {
    const insilico = parseProgress(['Iteration: 2000'])
    expect(insilico.stage).toBe('InSilicoVA: 50%')

    const stan = parseProgress(['Iteration: 2500 / 5000'])
    expect(stan.stage).toBe('Calibration: 50%')
  })

  it('caps percentage at 99', () => {
    // Even at max iteration, capped to 99
    const result = parseProgress(['Iteration: 4000'])
    expect(result.percentage).toBe(99) // 4000/4000 = 100, capped to 99
  })

  it('detects Running InSilicoVA stage', () => {
    const result = parseProgress(['Running InSilicoVA'])
    expect(result.stage).toBe('Running InSilicoVA...')
    expect(result.percentage).toBeNull()
  })

  it('detects Running algorithm: InterVA stage', () => {
    const result = parseProgress(['Running algorithm: InterVA'])
    expect(result.stage).toBe('Running InterVA...')
    expect(result.percentage).toBeNull()
  })

  it('detects Running EAVA stage', () => {
    const result = parseProgress(['Running EAVA'])
    expect(result.stage).toBe('Running EAVA...')
  })

  it('detects calibration stage', () => {
    const result = parseProgress(['Running calibration step'])
    expect(result.stage).toBe('Running calibration...')
  })

  it('detects cause_map stage', () => {
    const result = parseProgress(['Mapping specific causes to broad'])
    expect(result.stage).toBe('Mapping causes...')
  })

  it('detects Loading data stage', () => {
    const result = parseProgress(['Loading input data file'])
    expect(result.stage).toBe('Loading data...')
  })

  it('detects generic Starting fallback', () => {
    const result = parseProgress(['Starting job processing'])
    expect(result.stage).toBe('Processing...')
  })

  it('returns nulls for unrecognized log content', () => {
    const result = parseProgress(['some random log output'])
    expect(result).toEqual({ percentage: null, stage: null })
  })
})

describe('getElapsedTime', () => {
  beforeEach(() => {
    vi.useFakeTimers()
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  it('returns null for null input', () => {
    expect(getElapsedTime(null)).toBeNull()
  })

  it('formats seconds for string date', () => {
    const now = new Date('2024-01-01T00:01:00Z')
    vi.setSystemTime(now)
    const result = getElapsedTime('2024-01-01T00:00:30Z')
    expect(result).toBe('30s')
  })

  it('formats minutes and seconds', () => {
    const now = new Date('2024-01-01T00:05:30Z')
    vi.setSystemTime(now)
    const result = getElapsedTime('2024-01-01T00:00:00Z')
    expect(result).toBe('5m 30s')
  })

  it('formats hours and minutes', () => {
    const now = new Date('2024-01-01T02:15:00Z')
    vi.setSystemTime(now)
    const result = getElapsedTime('2024-01-01T00:00:00Z')
    expect(result).toBe('2h 15m')
  })

  it('handles R array timestamp format [seconds]', () => {
    // R timestamps sometimes come as [epoch_seconds]
    const epochSeconds = new Date('2024-01-01T00:00:00Z').getTime() / 1000
    const now = new Date('2024-01-01T00:00:45Z')
    vi.setSystemTime(now)
    const result = getElapsedTime([epochSeconds])
    expect(result).toBe('45s')
  })
})
