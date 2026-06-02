import { parseTimestamp } from './progress.js';

/**
 * Format a job timestamp in the viewer's local time WITH an explicit timezone
 * label, so it is unambiguous which zone is shown (issue #73, item #5).
 * Accepts ISO strings, tz-less R UTC strings, and the R [epoch_seconds] array
 * format (parsing is delegated to parseTimestamp).
 */
export function formatTimestamp(value) {
  if (value === null || value === undefined || value === '') return '-';
  const d = parseTimestamp(value);
  if (Number.isNaN(d.getTime())) return '-';
  return d.toLocaleString(undefined, { timeZoneName: 'short' });
}
