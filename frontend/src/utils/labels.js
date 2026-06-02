/**
 * Display-label helpers for algorithm and age-group names.
 * Single source of truth so the summary, figures, and tables stay consistent.
 */

const ALGORITHM_NAMES = {
  interva: 'InterVA',
  insilicova: 'InSilicoVA',
  eava: 'EAVA',
  ensemble: 'Ensemble',
};

export function formatAlgorithmName(algo) {
  if (!algo) return '';
  const key = String(algo).toLowerCase();
  return ALGORITHM_NAMES[key] || String(algo).toUpperCase();
}

/** Format one algorithm or an array of them as a comma-separated proper-name list. */
export function formatAlgorithmList(algorithms) {
  const arr = Array.isArray(algorithms) ? algorithms : [algorithms];
  return arr.map(formatAlgorithmName).join(', ');
}

const AGE_GROUP_LABELS = {
  neonate: 'Neonate (0-27 days)',
  child: 'Children (1-59 months)',
};

export function formatAgeGroup(ageGroup) {
  if (!ageGroup) return '';
  return AGE_GROUP_LABELS[String(ageGroup).toLowerCase()] || ageGroup;
}
