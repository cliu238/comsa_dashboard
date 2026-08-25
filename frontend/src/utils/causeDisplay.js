/**
 * Cause display utilities for preserving user's original cause names and ordering.
 * Issue #29: Results should reflect cause names exactly as they appear in uploaded VA data.
 */

const DEFAULT_CAUSE_NAMES = {
  congenital_malformation: 'Congenital Malformation',
  pneumonia: 'Pneumonia',
  sepsis_meningitis_inf: 'Sepsis/Meningitis',
  ipre: 'Intrapartum Events',
  prematurity: 'Prematurity',
  other: 'Other',
  malaria: 'Malaria',
  diarrhea: 'Diarrhea',
  severe_malnutrition: 'Severe Malnutrition',
  hiv: 'HIV',
  injury: 'Injury',
  other_infections: 'Other Infections',
  nn_causes: 'Neonatal Causes'
};

/**
 * Format a broad cause name for display.
 * Uses custom display names from the backend if provided, otherwise falls back to defaults.
 */
export function formatCauseDisplay(cause, displayNames) {
  if (displayNames && displayNames[cause]) return displayNames[cause];
  if (DEFAULT_CAUSE_NAMES[cause]) return DEFAULT_CAUSE_NAMES[cause];
  return cause.replace(/_/g, ' ').replace(/\b\w/g, l => l.toUpperCase());
}

/**
 * Normalize a cause-list field that crossed the R -> JSON boundary.
 * api/client.js unbox() collapses a one-item primitive array to a bare scalar, so
 * ANY variable-length cause list arrives either as an array or as a plain string.
 * Type-check it, never null-check it: a non-empty string is truthy but has no
 * .filter(). Anything else (missing, {}, number) reads as "no list".
 */
export function normalizeCauseList(value) {
  if (Array.isArray(value)) return value;
  if (typeof value === 'string') return [value];
  return [];
}

/**
 * Order causes according to the user's original data ordering.
 * If causeOrder is not provided, returns causes in their original order.
 *
 * Both arguments go through normalizeCauseList(): since issue #101 R1 filters
 * zero-death causes out of `cause_order`, a run where one broad cause survives
 * serialises it as a bare string, which used to throw `causeOrder.filter is not
 * a function` and blank the whole results view (there is no error boundary).
 */
export function orderCauses(causes, causeOrder) {
  const list = normalizeCauseList(causes);
  const order = normalizeCauseList(causeOrder);
  if (order.length === 0) return list;
  const ordered = order.filter(c => list.includes(c));
  const remaining = list.filter(c => !order.includes(c));
  return [...ordered, ...remaining];
}

/**
 * Sort causes by descending CSMF value. Zero-value causes sink to the bottom.
 * Missing or undefined entries in `values` are treated as having value 0.
 */
export function sortCausesByValue(causes, values) {
  return [...causes].sort((a, b) => (values[b] || 0) - (values[a] || 0));
}
