/**
 * CSMF view-model builders. Pure functions (no React) used by the results chart,
 * the consolidated table, and tests. Handles the per-algorithm (ensemble) shape
 * and the single-algorithm fallback in one place.
 */
import { orderCauses } from '../utils/causeDisplay.js';
import { formatAlgorithmName } from '../utils/labels.js';

const ENSEMBLE_KEY = 'ensemble';

// Sort comparator that pushes the ensemble entry to the end, others stable.
function ensembleLast(a, b) {
  return (a === ENSEMBLE_KEY ? 1 : 0) - (b === ENSEMBLE_KEY ? 1 : 0);
}

function orderedCauses(results) {
  return orderCauses(Object.keys(results.calibrated_csmf || {}), results.cause_order);
}

/**
 * Build per-algorithm facets for the CSMF figure.
 * Each facet: { label, causes: [{ cause, uncalibrated, calibrated, ciLower, ciUpper }] }
 * Values are raw [0,1] fractions (the chart fixes the y-axis to [0,1]).
 */
export function buildCsmfFacets(results) {
  if (!results) return [];
  const causes = orderedCauses(results);

  const makeFacet = (label, uncal, cal, lo, hi) => ({
    label,
    causes: causes.map(cause => ({
      cause,
      uncalibrated: uncal?.[cause] ?? 0,
      calibrated: cal?.[cause] ?? 0,
      ciLower: lo?.[cause] ?? null,
      ciUpper: hi?.[cause] ?? null,
    })),
  });

  if (results.per_algorithm) {
    return Object.keys(results.per_algorithm).sort(ensembleLast).map(key => {
      const d = results.per_algorithm[key];
      return makeFacet(formatAlgorithmName(key), d.uncalibrated_csmf, d.calibrated_csmf, d.calibrated_ci_lower, d.calibrated_ci_upper);
    });
  }

  const algo = Array.isArray(results.algorithm) ? results.algorithm[0] : results.algorithm;
  return [makeFacet(formatAlgorithmName(algo), results.uncalibrated_csmf, results.calibrated_csmf, results.calibrated_ci_lower, results.calibrated_ci_upper)];
}

/**
 * Whisker offsets for a CI drawn INSIDE the calibrated bar.
 * The bar's height equals `calibrated` (as a fraction of the plot), so percentages
 * on the absolutely-positioned whisker child are relative to the bar — divide by
 * `calibrated` to convert plot-coordinate fractions into bar-relative percentages.
 * Returns null when CI is missing or the bar has zero height (nothing to anchor to).
 */
export function csmfWhisker(calibrated, ciLower, ciUpper) {
  if (ciLower == null || ciUpper == null || !calibrated) return null;
  return {
    bottomPct: (ciLower / calibrated) * 100,
    heightPct: ((ciUpper - ciLower) / calibrated) * 100,
  };
}

const pct = v => (v == null ? null : Math.round(v * 100));

/**
 * Build the consolidated CSMF table view-model.
 * Returns { causes, groups: [{ algorithm, rows: [{ type, cells: [{cause, mean, lower, upper}] }] }] }
 * Uncalibrated cells carry mean only (backend provides no uncalibrated CI);
 * Calibrated cells carry mean + lower/upper. All values are integer percents.
 */
export function buildCsmfTableRows(results) {
  if (!results) return { causes: [], groups: [] };
  const causes = orderedCauses(results);

  const makeGroup = (label, uncal, cal, lo, hi) => ({
    algorithm: label,
    rows: [
      { type: 'Uncalibrated', cells: causes.map(c => ({ cause: c, mean: pct(uncal?.[c]), lower: null, upper: null })) },
      { type: 'Calibrated', cells: causes.map(c => ({ cause: c, mean: pct(cal?.[c]), lower: pct(lo?.[c]), upper: pct(hi?.[c]) })) },
    ],
  });

  if (results.per_algorithm) {
    const groups = Object.keys(results.per_algorithm).sort(ensembleLast).map(key => {
      const d = results.per_algorithm[key];
      return makeGroup(formatAlgorithmName(key), d.uncalibrated_csmf, d.calibrated_csmf, d.calibrated_ci_lower, d.calibrated_ci_upper);
    });
    return { causes, groups };
  }

  const algo = Array.isArray(results.algorithm) ? results.algorithm[0] : results.algorithm;
  return { causes, groups: [makeGroup(formatAlgorithmName(algo), results.uncalibrated_csmf, results.calibrated_csmf, results.calibrated_ci_lower, results.calibrated_ci_upper)] };
}
