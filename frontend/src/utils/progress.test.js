import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { parseProgress, getElapsedTime } from './progress.js'

describe('parseProgress', () => {
  it('returns nulls for empty logs', () => {
    expect(parseProgress(null)).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })
    expect(parseProgress([])).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })
    expect(parseProgress(undefined)).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })
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
    expect(result).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })
  })
})

describe('parseProgress - pipeline jobs', () => {
  it('detects openVA phase with single algorithm', () => {
    const logs = [
      'Starting pipeline: openVA -> vacalibration',
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      '..........60% completed',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('openva');
    expect(result.subPhase).toBe('InterVA');
    expect(result.phaseProgress).toBe(60);
    // Single algo pipeline: openVA=50%, calibration=50%. At 60% of openVA = 30% overall
    expect(result.percentage).toBe(30);
    expect(result.stage).toContain('openVA');
    expect(result.stage).toContain('InterVA');
    expect(result.stage).toContain('60%');
  });

  it('detects openVA phase in 2-algo ensemble', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      'Running openVA: InSilicoVA',
      'Iteration: 2000',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('openva');
    expect(result.subPhase).toBe('InSilicoVA');
    expect(result.phaseProgress).toBe(50);
    // 2 algos + calib = 3 segments. Algo1 done (33%) + algo2 at 50% of 33% = 33+17 = 50%
    expect(result.percentage).toBe(50);
    expect(result.stage).toContain('2/2');
  });

  it('detects calibration phase in pipeline', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      '=== Step 3: vacalibration ===',
      'Chain 1 Iteration: 2500 / 5000',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('calibration');
    expect(result.phaseProgress).toBe(50);
    // Single algo pipeline: openVA done (50%) + calibration at 50% of 50% = 75%
    expect(result.percentage).toBe(75);
    expect(result.stage).toContain('Calibration');
  });

  it('shows 3-algo ensemble overall progress in calibration phase', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      'Running openVA: InSilicoVA',
      'openVA InSilicoVA complete: 100 causes assigned',
      'Running openVA: EAVA',
      'openVA EAVA complete: 100 causes assigned',
      '=== Step 3: vacalibration ===',
      'Chain 1 Iteration: 2500 / 5000',
    ];
    const result = parseProgress(logs);
    // 3 algos + calib = 4 segments, each 25%. All 3 algos done (75%) + calib at 50% of 25% = 88%
    expect(result.percentage).toBe(88);
  });

  it('returns null phase for non-pipeline logs', () => {
    const result = parseProgress(['..........60% completed']);
    expect(result.phase).toBeNull();
    expect(result.subPhase).toBeNull();
    expect(result.phaseProgress).toBeNull();
  });

  it('handles pipeline with phase marker but no progress yet', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('openva');
    expect(result.subPhase).toBe('InterVA');
    expect(result.phaseProgress).toBeNull();
    expect(result.percentage).toBeNull();
    expect(result.stage).toContain('openVA');
    expect(result.stage).toContain('Starting');
  });

  it('handles step marker with no algorithm started yet', () => {
    const logs = [
      '=== Step 1: openVA ===',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('openva');
    expect(result.subPhase).toBeNull();
    expect(result.phaseProgress).toBeNull();
    expect(result.percentage).toBeNull();
    expect(result.stage).toBe('Phase 1/2: openVA — Starting...');
    expect(result.stage).not.toContain('null');
  });
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
