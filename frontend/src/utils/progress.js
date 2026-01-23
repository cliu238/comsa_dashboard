// Parse progress information from job logs

export function parseProgress(logs) {
  if (!logs || logs.length === 0) {
    return { percentage: null, stage: null };
  }

  const logText = logs.join('\n');

  // InterVA: "..........60% completed"
  const intervaMatch = logText.match(/(\d+)% completed/g);
  if (intervaMatch) {
    const lastMatch = intervaMatch[intervaMatch.length - 1];
    const pct = parseInt(lastMatch.match(/(\d+)/)[1]);
    return { percentage: pct, stage: `InterVA: ${pct}%` };
  }

  // InSilicoVA: "Iteration: 2000" with total iterations (typically 4000)
  const totalMatch = logText.match(/(\d+) Iterations to Sample/i);
  const iterMatch = logText.match(/Iteration:\s*(\d+)/g);
  if (iterMatch) {
    const total = totalMatch ? parseInt(totalMatch[1]) : 4000;
    const lastIter = iterMatch[iterMatch.length - 1];
    const current = parseInt(lastIter.match(/(\d+)/)[1]);
    const pct = Math.min(Math.round((current / total) * 100), 99);
    return { percentage: pct, stage: `InSilicoVA: ${pct}%` };
  }

  // Stan/vacalibration: "Chain X Iteration: 2500 / 5000" or "Iteration: X / Y"
  const stanMatch = logText.match(/Iteration:\s*(\d+)\s*\/\s*(\d+)/g);
  if (stanMatch) {
    const lastMatch = stanMatch[stanMatch.length - 1];
    const nums = lastMatch.match(/(\d+)\s*\/\s*(\d+)/);
    if (nums) {
      const pct = Math.min(Math.round((parseInt(nums[1]) / parseInt(nums[2])) * 100), 99);
      return { percentage: pct, stage: `Calibration: ${pct}%` };
    }
  }

  // Check for specific stage markers
  if (logText.includes('Running InSilicoVA') || logText.includes('Running algorithm: InSilicoVA')) {
    return { percentage: null, stage: 'Running InSilicoVA...' };
  }
  if (logText.includes('Running InterVA') || logText.includes('Running algorithm: InterVA')) {
    return { percentage: null, stage: 'Running InterVA...' };
  }
  if (logText.includes('Running EAVA') || logText.includes('Running algorithm: EAVA')) {
    return { percentage: null, stage: 'Running EAVA...' };
  }
  if (logText.includes('Running calibration') || logText.includes('vacalibration')) {
    return { percentage: null, stage: 'Running calibration...' };
  }
  if (logText.includes('Mapping specific causes') || logText.includes('cause_map')) {
    return { percentage: null, stage: 'Mapping causes...' };
  }
  if (logText.includes('Loading') && logText.includes('data')) {
    return { percentage: null, stage: 'Loading data...' };
  }

  // Generic running state
  if (logText.includes('Starting') || logText.includes('Running')) {
    return { percentage: null, stage: 'Processing...' };
  }

  return { percentage: null, stage: null };
}

// Calculate elapsed time from job start
export function getElapsedTime(startedAt) {
  if (!startedAt) return null;

  const start = typeof startedAt === 'string'
    ? new Date(startedAt)
    : Array.isArray(startedAt)
      ? new Date(startedAt[0] * 1000)
      : new Date(startedAt);

  const now = new Date();
  const elapsed = Math.floor((now - start) / 1000);

  if (elapsed < 60) {
    return `${elapsed}s`;
  } else if (elapsed < 3600) {
    const mins = Math.floor(elapsed / 60);
    const secs = elapsed % 60;
    return `${mins}m ${secs}s`;
  } else {
    const hours = Math.floor(elapsed / 3600);
    const mins = Math.floor((elapsed % 3600) / 60);
    return `${hours}h ${mins}m`;
  }
}
