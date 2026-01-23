import { parseProgress, getElapsedTime } from '../utils/progress';

export default function ProgressIndicator({ logs, startedAt, compact = false }) {
  const { percentage, stage } = parseProgress(logs);
  const elapsed = getElapsedTime(startedAt);

  if (compact) {
    // Compact version for JobList
    return (
      <div className="progress-compact">
        {percentage !== null ? (
          <div className="progress-bar-mini">
            <div
              className="progress-fill"
              style={{ width: `${percentage}%` }}
            />
            <span className="progress-text">{percentage}%</span>
          </div>
        ) : (
          <span className="progress-spinner-mini" />
        )}
      </div>
    );
  }

  // Full version for JobDetail
  return (
    <div className="progress-indicator">
      <div className="progress-header">
        <span className="progress-stage">{stage || 'Processing...'}</span>
        {elapsed && <span className="progress-elapsed">{elapsed}</span>}
      </div>

      {percentage !== null ? (
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{ width: `${percentage}%` }}
          />
        </div>
      ) : (
        <div className="progress-indeterminate">
          <div className="progress-indeterminate-bar" />
        </div>
      )}

      {percentage !== null && (
        <div className="progress-percentage">{percentage}%</div>
      )}
    </div>
  );
}
