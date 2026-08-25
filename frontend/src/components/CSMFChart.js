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
    // issue #101, R2 retraction: pathCorrectionStalled means this row's OWN lambda hit
    // the identity ceiling, so its point estimate is a no-op -- no calibration was
    // applied (never true for the ensemble, which has no lambda of its own). The
    // package author confirmed a stalled row's interval EQUALS the same input's
    // uncalibrated sampling error, so it is drawn/printed like any other -- there used
    // to be a second flag claiming otherwise; it is deleted, and the older wire field
    // that used to carry it is never read.
    // calibrationDeclined means vacalibration reported it could not calibrate this row
    // at all (one or fewer causes remained after exclusion) -- distinct from a stall.
    // Strict `=== true` and `typeof === 'number'`, not `??`: these values reach us via
    // api/client.js unbox(), and anything it does not collapse to a plain scalar must
    // read as "unknown" rather than as a flag. Older jobs lack the fields entirely.
    lambda: typeof src.lambda_calibpath === 'number' ? src.lambda_calibpath : null,
    pathCorrectionStalled: src.path_correction_stalled === true,
    calibrationDeclined: src.calibration_declined === true,
    // Both shapes are real: api/client.js unbox() collapses a one-item primitive array
    // to a scalar, so exactly one stalled algorithm arrives as "eava" while two arrive
    // as ["eava", "insilicova"]. Any array field crossing this boundary needs both.
    stalledConstituents: Array.isArray(src.stalled_constituents) ? src.stalled_constituents
      : typeof src.stalled_constituents === 'string' ? [src.stalled_constituents]
      : null,
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
 * Returns null when CI is missing or the bar has zero height (nothing to anchor to).
 * issue #101, R2 retraction: a stalled run's interval is the genuine uncertainty of
 * its own uncalibrated estimate (sampling error only), confirmed correct against the
 * package author's own account, so it is drawn like any other interval. There is no
 * stall-based suppression here any more; only a point mass (below) is still skipped.
 */
export function csmfWhisker(calibrated, ciLower, ciUpper) {
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

  // issue #101, R2 retraction: this table sits directly under the chart and shares its
  // numbers, so a stalled run's interval is printed here exactly as the chart draws it
  // — it is the genuine uncertainty of the uncalibrated estimate, correctly sized.
  // The row is still relabelled via `type` so the reader knows no calibration reached it.
  const makeGroup = (label, src) => {
    const stalled = src.path_correction_stalled === true;
    // calibration_declined must be read here too, not only by the chart facet and the
    // summary banner: this table is what exportConsolidatedCSMF() writes to disk, so a
    // declined run used to leave the building with uncalibrated numbers under the row
    // type "Calibrated". Same strict `=== true` as everywhere else on this boundary.
    // The two flags are mutually exclusive (a declined run's lambda is NA, a stalled
    // run's is at the ceiling), so the order below only decides an impossible tie.
    const declined = src.calibration_declined === true;
    // A point-mass interval claims perfect certainty, so drop it here exactly as the
    // chart does — vacalibration returns lower == upper == postmean for every cause it
    // did not calibrate, and `other` is excluded by default, so every run has one.
    // Decided on the RAW bounds, matching csmfWhisker: deciding on rounded percents
    // would suppress a real interval like 0.0131–0.0134 that the chart draws, which is
    // the same chart/table disagreement in reverse. pct() is for display only.
    const cell = (c) => {
      const rawLo = src.calibrated_ci_lower?.[c];
      const rawHi = src.calibrated_ci_upper?.[c];
      const degenerate = rawLo == null || rawHi == null || !(rawHi > rawLo);
      return { cause: c, mean: pct(src.calibrated_csmf?.[c]),
               lower: degenerate ? null : pct(rawLo),
               upper: degenerate ? null : pct(rawHi) };
    };
    return {
      algorithm: label,
      rows: [
        { type: 'Uncalibrated', cells: causes.map(c => ({ cause: c, mean: pct(src.uncalibrated_csmf?.[c]), lower: null, upper: null })) },
        {
          type: declined ? 'Calibrated (none applied — vacalibration could not calibrate this dataset)'
                : stalled ? 'Calibrated (none applied — interval is the uncalibrated estimate)'
                : 'Calibrated',
          cells: causes.map(cell),
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
