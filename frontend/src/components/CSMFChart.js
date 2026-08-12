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

  const makeFacet = (label, src) => ({
    label,
    // issue #101: lambda at the 0.99 ceiling means path correction found no usable
    // value, so the "calibrated" bars equal the uncalibrated ones and the intervals
    // are ~7x too tight. Older jobs predate the field, hence the `=== true` default.
    // The lambda is type-checked rather than null-checked because jsonlite puts
    // non-numbers on the wire: an R NULL becomes `{}` and an R NA becomes the string
    // "NA", both of which survive `?? null` and then throw on `.toFixed()`.
    lambda: typeof src.lambda_calibpath === 'number' ? src.lambda_calibpath : null,
    pathCorrectionStalled: src.path_correction_stalled === true,
    causes: causes.map(cause => ({
      cause,
      uncalibrated: src.uncalibrated_csmf?.[cause] ?? 0,
      calibrated: src.calibrated_csmf?.[cause] ?? 0,
      ciLower: src.calibrated_ci_lower?.[cause] ?? null,
      ciUpper: src.calibrated_ci_upper?.[cause] ?? null,
    })),
  });

  if (results.per_algorithm) {
    return Object.keys(results.per_algorithm).sort(ensembleLast)
      .map(key => makeFacet(formatAlgorithmName(key), results.per_algorithm[key]));
  }

  const algo = Array.isArray(results.algorithm) ? results.algorithm[0] : results.algorithm;
  return [makeFacet(formatAlgorithmName(algo), results)];
}

/**
 * Whisker offsets for a CI drawn INSIDE the calibrated bar.
 * The bar's height equals `calibrated` (as a fraction of the plot), so percentages
 * on the absolutely-positioned whisker child are relative to the bar — divide by
 * `calibrated` to convert plot-coordinate fractions into bar-relative percentages.
 * Returns null when CI is missing or the bar has zero height (nothing to anchor to),
 * and when path correction stalled (issue #101) — at lambda = 0.99 the inflated prior
 * concentration makes the intervals ~7x tighter than the same input with
 * path_correction = FALSE, so drawing them would assert certainty the model never had.
 */
export function csmfWhisker(calibrated, ciLower, ciUpper, pathCorrectionStalled) {
  if (pathCorrectionStalled) return null;
  if (ciLower == null || ciUpper == null || !calibrated) return null;
  // A point-mass interval claims perfect certainty. vacalibration returns lower ==
  // upper == postmean for every cause it did not calibrate ("other" is excluded by
  // default, so every run has at least one), independently of the stall above.
  if (!(ciUpper > ciLower)) return null;
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

  // issue #101: this table sits directly under the chart and shares its numbers, so a
  // stalled run must not print the intervals the chart suppresses. The row is relabelled
  // rather than silently stripped, so the omission is visible.
  const makeGroup = (label, src) => {
    const stalled = src.path_correction_stalled === true;
    return {
      algorithm: label,
      rows: [
        { type: 'Uncalibrated', cells: causes.map(c => ({ cause: c, mean: pct(src.uncalibrated_csmf?.[c]), lower: null, upper: null })) },
        {
          type: stalled ? 'Calibrated (not calibrated: no usable path correction)' : 'Calibrated',
          cells: causes.map(c => ({
            cause: c,
            mean: pct(src.calibrated_csmf?.[c]),
            lower: stalled ? null : pct(src.calibrated_ci_lower?.[c]),
            upper: stalled ? null : pct(src.calibrated_ci_upper?.[c]),
          })),
        },
      ],
    };
  };

  if (results.per_algorithm) {
    const groups = Object.keys(results.per_algorithm).sort(ensembleLast)
      .map(key => makeGroup(formatAlgorithmName(key), results.per_algorithm[key]));
    return { causes, groups };
  }

  const algo = Array.isArray(results.algorithm) ? results.algorithm[0] : results.algorithm;
  return { causes, groups: [makeGroup(formatAlgorithmName(algo), results)] };
}
