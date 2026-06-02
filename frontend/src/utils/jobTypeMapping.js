/**
 * Maps the issue #73 "Input Type" / "Output Type" selectors onto the backend
 * job_type string the API already understands ('openva' | 'pipeline' |
 * 'vacalibration'). Pure functions — single source of truth for the cascade.
 */

export const INPUT_TYPES = [
  { value: 'individual', label: 'Individual VA Records' },
  { value: 'ccva_output', label: 'Output from CCVA' },
];

const TOP_CAUSE = { value: 'top_cause', label: 'Individual Top Cause of Death' };
const DISTRIBUTION = { value: 'distribution', label: 'Cause Distribution' };

/** Output Type options depend on the chosen Input Type. */
export function outputTypeOptions(inputType) {
  if (inputType === 'individual') return [TOP_CAUSE, DISTRIBUTION];
  return [DISTRIBUTION]; // 'ccva_output' is locked to a single option
}

/** Derive the backend job_type from the two selectors. */
export function deriveJobType(inputType, outputType) {
  if (inputType === 'individual') {
    return outputType === 'top_cause' ? 'openva' : 'pipeline';
  }
  return 'vacalibration';
}

/** Inverse mapping: which selectors produce a given job_type. */
export function jobTypeToSelectors(jobType) {
  switch (jobType) {
    case 'openva':
      return { inputType: 'individual', outputType: 'top_cause' };
    case 'pipeline':
      return { inputType: 'individual', outputType: 'distribution' };
    case 'vacalibration':
    default:
      return { inputType: 'ccva_output', outputType: 'distribution' };
  }
}
