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
 * Order causes according to the user's original data ordering.
 * If causeOrder is not provided, returns causes in their original order.
 */
export function orderCauses(causes, causeOrder) {
  if (!causeOrder) return causes;
  const ordered = causeOrder.filter(c => causes.includes(c));
  const remaining = causes.filter(c => !causeOrder.includes(c));
  return [...ordered, ...remaining];
}

/**
 * Sort causes by descending CSMF value. Zero-value causes sink to the bottom.
 */
export function sortCausesByValue(causes, values) {
  return [...causes].sort((a, b) => (values[b] || 0) - (values[a] || 0));
}
