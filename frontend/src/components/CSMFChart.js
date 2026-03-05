/**
 * Compute chart data for CSMF bar chart with error bars.
 * Pure function — no React dependency — used by CSMFChart component and tests.
 */
export function computeCSMFChartData(causes, uncalibrated, calibrated, ciLower, ciUpper) {
  const maxVal = Math.max(
    ...causes.map(c => Math.max(
      uncalibrated[c] || 0,
      ciUpper?.[c] || 0
    ))
  );

  return causes.map(cause => ({
    cause,
    uncalibratedPct: (uncalibrated[cause] / maxVal) * 100,
    calibratedPct: (calibrated[cause] / maxVal) * 100,
    errorBarLowerPct: ciLower ? (ciLower[cause] / maxVal) * 100 : null,
    errorBarUpperPct: ciUpper ? (ciUpper[cause] / maxVal) * 100 : null,
  }));
}
