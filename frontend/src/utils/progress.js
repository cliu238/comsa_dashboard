// Parse progress information from job logs

const NULL_RESULT = { percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null };

function parsePhaseProgress(logText) {
  // InterVA: "..........60% completed"
  const intervaMatch = logText.match(/(\d+)% completed/g);
  if (intervaMatch) {
    const lastMatch = intervaMatch[intervaMatch.length - 1];
    return parseInt(lastMatch.match(/(\d+)/)[1]);
  }

  // Stan/vacalibration: "Chain X Iteration: 2500 / 5000"
  const stanMatch = logText.match(/Iteration:\s*(\d+)\s*\/\s*(\d+)/g);
  if (stanMatch) {
    const lastMatch = stanMatch[stanMatch.length - 1];
    const nums = lastMatch.match(/(\d+)\s*\/\s*(\d+)/);
    if (nums) {
      return Math.min(Math.round((parseInt(nums[1]) / parseInt(nums[2])) * 100), 99);
    }
  }

  // InSilicoVA: "Iteration: 2000" (bare, no slash)
  const totalMatch = logText.match(/(\d+) Iterations to Sample/i);
  const iterMatch = logText.match(/Iteration:\s*(\d+)/g);
  if (iterMatch) {
    const total = totalMatch ? parseInt(totalMatch[1]) : 4000;
    const lastIter = iterMatch[iterMatch.length - 1];
    const current = parseInt(lastIter.match(/(\d+)/)[1]);
    return Math.min(Math.round((current / total) * 100), 99);
  }

  return null;
}

function parsePipelineProgress(logs) {
  const logText = logs.join('\n');

  // Detect current phase from last === Step marker
  const stepMarkers = logText.match(/=== Step \d+: (\w+) ===/g);
  if (!stepMarkers) return null;

  const lastStep = stepMarkers[stepMarkers.length - 1];
  const stepName = lastStep.match(/=== Step \d+: (\w+) ===/)[1];
  const phase = stepName === 'openVA' ? 'openva' : 'calibration';

  // Count algorithms
  const algoRunMatches = logText.match(/Running (?:openVA|algorithm):\s*(\w+)/g) || [];
  const totalAlgorithms = algoRunMatches.length || 1;
  const completedMatches = logText.match(/openVA \w+ complete:/g) || [];
  const completedAlgorithms = completedMatches.length;

  // Current algorithm (last one started)
  let currentAlgo = null;
  if (algoRunMatches.length > 0) {
    const last = algoRunMatches[algoRunMatches.length - 1];
    currentAlgo = last.match(/Running (?:openVA|algorithm):\s*(\w+)/)[1];
  }

  // Parse progress for the current phase
  // For calibration phase, only look at logs after the calibration step marker
  let progressText = logText;
  if (phase === 'calibration') {
    const calibIdx = logText.lastIndexOf('=== Step 3: vacalibration ===');
    if (calibIdx >= 0) {
      progressText = logText.substring(calibIdx);
    }
  } else {
    // For openVA phase, only look at logs after the last "Running openVA/algorithm:" marker
    if (algoRunMatches.length > 0) {
      const lastAlgoMarker = algoRunMatches[algoRunMatches.length - 1];
      const lastAlgoIdx = logText.lastIndexOf(lastAlgoMarker);
      if (lastAlgoIdx >= 0) {
        progressText = logText.substring(lastAlgoIdx);
      }
    }
  }

  const phaseProgress = parsePhaseProgress(progressText);

  // Compute overall percentage
  const totalSegments = totalAlgorithms + 1; // algos + calibration
  const segmentWeight = 1 / totalSegments;
  let percentage = null;

  if (phaseProgress !== null) {
    if (phase === 'openva') {
      const completedWeight = completedAlgorithms * segmentWeight;
      percentage = Math.round((completedWeight + (phaseProgress / 100) * segmentWeight) * 100);
    } else {
      // calibration phase - all algos done
      percentage = Math.round((totalAlgorithms * segmentWeight + (phaseProgress / 100) * segmentWeight) * 100);
    }
  }

  // Build stage string
  let stage;
  if (phase === 'openva') {
    const algoIdx = completedAlgorithms + 1; // current algo number (1-based)
    if (phaseProgress !== null) {
      stage = `Phase 1/2: openVA (${algoIdx}/${totalAlgorithms}) — ${currentAlgo} ${phaseProgress}%`;
    } else {
      stage = `Phase 1/2: openVA (${algoIdx}/${totalAlgorithms}) — ${currentAlgo} Starting...`;
    }
  } else {
    if (phaseProgress !== null) {
      stage = `Phase 2/2: Calibration ${phaseProgress}%`;
    } else {
      stage = `Phase 2/2: Calibration Starting...`;
    }
  }

  return { percentage, stage, phase, subPhase: currentAlgo, phaseProgress };
}

export function parseProgress(logs) {
  if (!logs || logs.length === 0) {
    return { ...NULL_RESULT };
  }

  const logText = logs.join('\n');

  // Check for pipeline job (has === Step markers)
  if (/=== Step \d+:/.test(logText)) {
    const pipelineResult = parsePipelineProgress(logs);
    if (pipelineResult) return pipelineResult;
  }

  // Non-pipeline: existing logic
  // InterVA: "..........60% completed"
  const intervaMatch = logText.match(/(\d+)% completed/g);
  if (intervaMatch) {
    const lastMatch = intervaMatch[intervaMatch.length - 1];
    const pct = parseInt(lastMatch.match(/(\d+)/)[1]);
    return { percentage: pct, stage: `InterVA: ${pct}%`, phase: null, subPhase: null, phaseProgress: null };
  }

  // Stan/vacalibration: "Chain X Iteration: 2500 / 5000" or "Iteration: X / Y"
  // MUST check before InSilicoVA — both match "Iteration:" but Stan has " / total"
  const stanMatch = logText.match(/Iteration:\s*(\d+)\s*\/\s*(\d+)/g);
  if (stanMatch) {
    const lastMatch = stanMatch[stanMatch.length - 1];
    const nums = lastMatch.match(/(\d+)\s*\/\s*(\d+)/);
    if (nums) {
      const pct = Math.min(Math.round((parseInt(nums[1]) / parseInt(nums[2])) * 100), 99);
      return { percentage: pct, stage: `Calibration: ${pct}%`, phase: null, subPhase: null, phaseProgress: null };
    }
  }

  // InSilicoVA: "Iteration: 2000" with total iterations (typically 4000)
  const totalMatch = logText.match(/(\d+) Iterations to Sample/i);
  const iterMatch = logText.match(/Iteration:\s*(\d+)/g);
  if (iterMatch) {
    const total = totalMatch ? parseInt(totalMatch[1]) : 4000;
    const lastIter = iterMatch[iterMatch.length - 1];
    const current = parseInt(lastIter.match(/(\d+)/)[1]);
    const pct = Math.min(Math.round((current / total) * 100), 99);
    return { percentage: pct, stage: `InSilicoVA: ${pct}%`, phase: null, subPhase: null, phaseProgress: null };
  }

  // Check for specific stage markers
  if (logText.includes('Running InSilicoVA') || logText.includes('Running algorithm: InSilicoVA')) {
    return { percentage: null, stage: 'Running InSilicoVA...', phase: null, subPhase: null, phaseProgress: null };
  }
  if (logText.includes('Running InterVA') || logText.includes('Running algorithm: InterVA')) {
    return { percentage: null, stage: 'Running InterVA...', phase: null, subPhase: null, phaseProgress: null };
  }
  if (logText.includes('Running EAVA') || logText.includes('Running algorithm: EAVA')) {
    return { percentage: null, stage: 'Running EAVA...', phase: null, subPhase: null, phaseProgress: null };
  }
  if (logText.includes('Running calibration') || logText.includes('vacalibration')) {
    return { percentage: null, stage: 'Running calibration...', phase: null, subPhase: null, phaseProgress: null };
  }
  if (logText.includes('Mapping specific causes') || logText.includes('cause_map')) {
    return { percentage: null, stage: 'Mapping causes...', phase: null, subPhase: null, phaseProgress: null };
  }
  if (logText.includes('Loading') && logText.includes('data')) {
    return { percentage: null, stage: 'Loading data...', phase: null, subPhase: null, phaseProgress: null };
  }

  // Generic running state
  if (logText.includes('Starting') || logText.includes('Running')) {
    return { percentage: null, stage: 'Processing...', phase: null, subPhase: null, phaseProgress: null };
  }

  return { ...NULL_RESULT };
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
