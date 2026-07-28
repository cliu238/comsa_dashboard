import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { parseProgress, getElapsedTime, parseAlgorithmProgress } from './progress.js'

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
    ]
    const result = parseProgress(logs)
    expect(result.phase).toBe('openva')
    expect(result.subPhase).toBe('InterVA')
    expect(result.phaseProgress).toBe(60)
    // Single algo pipeline: openVA=50%, calibration=50%. At 60% of openVA = 30% overall
    expect(result.percentage).toBe(30)
    expect(result.stage).toContain('openVA')
    expect(result.stage).toContain('InterVA')
    expect(result.stage).toContain('60%')
  })

  it('detects openVA phase in 2-algo ensemble', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      'Running openVA: InSilicoVA',
      'Iteration: 2000',
    ]
    const result = parseProgress(logs)
    expect(result.phase).toBe('openva')
    expect(result.subPhase).toBe('InSilicoVA')
    expect(result.phaseProgress).toBe(50)
    // 2 algos + calib = 3 segments. Algo1 done (33%) + algo2 at 50% of 33% = 33+17 = 50%
    expect(result.percentage).toBe(50)
    expect(result.stage).toContain('2/2')
  })

  it('detects calibration phase in pipeline', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      '=== Step 3: vacalibration ===',
      'Chain 1 Iteration: 2500 / 5000',
    ]
    const result = parseProgress(logs)
    expect(result.phase).toBe('calibration')
    expect(result.phaseProgress).toBe(50)
    // Single algo pipeline: openVA done (50%) + calibration at 50% of 50% = 75%
    expect(result.percentage).toBe(75)
    expect(result.stage).toContain('Calibration')
  })

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
    ]
    const result = parseProgress(logs)
    // 3 algos + calib = 4 segments, each 25%. All 3 algos done (75%) + calib at 50% of 25% = 88%
    expect(result.percentage).toBe(88)
  })

  it('returns null phase for non-pipeline logs', () => {
    const result = parseProgress(['..........60% completed'])
    expect(result.phase).toBeNull()
    expect(result.subPhase).toBeNull()
    expect(result.phaseProgress).toBeNull()
  })

  it('handles pipeline with phase marker but no progress yet', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
    ]
    const result = parseProgress(logs)
    expect(result.phase).toBe('openva')
    expect(result.subPhase).toBe('InterVA')
    expect(result.phaseProgress).toBeNull()
    expect(result.percentage).toBeNull()
    expect(result.stage).toContain('openVA')
    expect(result.stage).toContain('Starting')
  })

  it('handles step marker with no algorithm started yet', () => {
    const logs = [
      '=== Step 1: openVA ===',
    ]
    const result = parseProgress(logs)
    expect(result.phase).toBe('openva')
    expect(result.subPhase).toBeNull()
    expect(result.phaseProgress).toBeNull()
    expect(result.percentage).toBeNull()
    expect(result.stage).toBe('Phase 1/2: openVA — Starting...')
    expect(result.stage).not.toContain('null')
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

  it('treats a space-separated R timestamp (no timezone) as UTC, not local', () => {
    // R writes "YYYY-MM-DD HH:MM:SS.ffffff" in UTC with no tz suffix.
    const now = new Date('2026-05-30T13:48:30Z')
    vi.setSystemTime(now)
    const result = getElapsedTime('2026-05-30 13:48:14.922977')
    // now=30.000s, start=14.922977s → elapsed=15.077s → floor=15s, NOT a negative number
    expect(result).toBe('15s')
  })

  it('never returns a negative elapsed time (clamped to 0)', () => {
    const now = new Date('2026-05-30T13:48:14Z')
    vi.setSystemTime(now)
    // start is a few seconds after "now" — must clamp, not show negative
    const result = getElapsedTime('2026-05-30 13:48:20')
    expect(result).toBe('0s')
  })
})

// --- Issue #104 item 3: separate progress per algorithm ---------------------
// vacalibration prints "* Calibrating <algo>" before each algorithm's Stan run
// and "* Ensemble calibration" for the combined pass. Verified against the real
// log of job 901322df on the dev deployment.
describe('parseAlgorithmProgress (issue #104)', () => {
  it('returns null when the log has no per-algorithm calibration markers', () => {
    expect(parseAlgorithmProgress(['Starting vacalibration', 'Loaded 1190 records'])).toBeNull();
    expect(parseAlgorithmProgress([])).toBeNull();
    expect(parseAlgorithmProgress(null)).toBeNull();
  });

  it('reports the in-flight algorithm from its own Stan iterations', () => {
    const got = parseAlgorithmProgress([
      '* Calibrating interva',
      '** Not calibrating: other',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration:    1 / 7000 [  0%]  (Warmup)',
      'Chain 1: Iteration: 3500 / 7000 [ 50%]  (Sampling)',
    ]);
    expect(got).toEqual([{ name: 'interva', percentage: 50, done: false }]);
  });

  it('ignores a previous algorithm\'s trailing iteration line flushed after the next marker', () => {
    // Real buffering artifact: interva's "7000 / 7000" lands AFTER "* Calibrating
    // eava". Naive segmentation would show eava at 100% before it has begun.
    const got = parseAlgorithmProgress([
      '* Calibrating interva',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 5500 / 7000 [ 78%]  (Sampling)',
      '* Calibrating eava',
      '** Not calibrating: other',
      'Chain 1: Iteration: 7000 / 7000 [100%]  (Sampling)',
    ]);
    expect(got).toEqual([
      { name: 'interva', percentage: 100, done: true },   // superseded => complete
      { name: 'eava', percentage: 0, done: false },       // not started, NOT 100
    ]);
  });

  it('marks a stage complete once a later stage starts', () => {
    const got = parseAlgorithmProgress([
      '* Calibrating interva',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 1750 / 7000 [ 25%]  (Sampling)',
      '* Calibrating eava',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 3500 / 7000 [ 50%]  (Sampling)',
    ]);
    expect(got[0]).toEqual({ name: 'interva', percentage: 100, done: true });
    expect(got[1]).toEqual({ name: 'eava', percentage: 50, done: false });
  });

  it('includes the ensemble pass as its own stage', () => {
    const got = parseAlgorithmProgress([
      '* Calibrating interva',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 7000 / 7000 [100%]  (Sampling)',
      '* Ensemble calibration',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 700 / 7000 [ 10%]  (Sampling)',
    ]);
    expect(got.map(s => s.name)).toEqual(['interva', 'ensemble']);
    expect(got[1].percentage).toBe(10);
  });

  it('caps an in-flight stage at 99 so only a finished stage reads 100', () => {
    const got = parseAlgorithmProgress([
      '* Calibrating interva',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 7000 / 7000 [100%]  (Sampling)',
    ]);
    expect(got[0]).toEqual({ name: 'interva', percentage: 99, done: false });
  });

  it('marks every stage complete once calibration reports completion', () => {
    const got = parseAlgorithmProgress([
      '* Calibrating interva',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 3500 / 7000 [ 50%]  (Sampling)',
      '* VA-Calibration complete',
    ]);
    expect(got.every(s => s.done && s.percentage === 100)).toBe(true);
  });

  it('handles the real job 901322df log shape end to end', () => {
    const got = parseAlgorithmProgress([
      '* Preparing VA data for calibration',
      '* Using the misclassification matrix of Mozambique for calibration',
      '* Calibrating interva', '** Not calibrating: other',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 5500 / 7000 [ 78%]  (Sampling)',
      '* Calibrating eava', '** Not calibrating: other',
      'Chain 1: Iteration: 7000 / 7000 [100%]  (Sampling)',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 7000 / 7000 [100%]  (Sampling)',
      '* Calibrating insilicova', '** Not calibrating: congenital_malformation, other',
      "SAMPLING FOR MODEL 'anon_model' NOW (CHAIN 1).",
      'Chain 1: Iteration: 2100 / 7000 [ 30%]  (Sampling)',
    ]);
    expect(got.map(s => s.name)).toEqual(['interva', 'eava', 'insilicova']);
    expect(got[0].done).toBe(true);
    expect(got[1].done).toBe(true);
    expect(got[2]).toEqual({ name: 'insilicova', percentage: 30, done: false });
    // "* Preparing ..." lines are not algorithms
    expect(got.some(s => /Preparing|Using/.test(s.name))).toBe(false);
  });
});
