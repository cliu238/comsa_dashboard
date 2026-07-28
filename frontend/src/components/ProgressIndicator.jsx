import { parseProgress, getElapsedTime, parseAlgorithmProgress } from '../utils/progress';
import { formatAlgorithmName } from '../utils/labels';

export default function ProgressIndicator({ logs, startedAt, compact = false }) {
  const { percentage, stage, phase } = parseProgress(logs);
  const elapsed = getElapsedTime(startedAt);
  const isPipeline = phase !== null;
  // One bar per algorithm once calibration starts (issue #104); null before that.
  const algorithms = compact ? null : parseAlgorithmProgress(logs);

  if (compact) {
    // Compact version for JobList — uses overall percentage, no segmentation
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

      {algorithms && algorithms.length > 0 ? (
        <div className="progress-algorithms">
          {algorithms.map((a) => (
            <div className="progress-algo" key={a.name}>
              <div className="progress-algo-head">
                <span className="progress-algo-label">{formatAlgorithmName(a.name)}</span>
                <span className="progress-algo-value">{a.done ? 'Done' : `${a.percentage}%`}</span>
              </div>
              <div className="progress-bar">
                <div className="progress-fill" style={{ width: `${a.percentage}%` }} />
              </div>
            </div>
          ))}
        </div>
      ) : isPipeline && percentage !== null ? (
        <div className="progress-segmented">
          <div
            className="progress-segmented-fill"
            style={{ width: `${percentage}%` }}
          />
        </div>
      ) : percentage !== null ? (
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

      {!algorithms && percentage !== null && (
        <div className="progress-percentage">{isPipeline ? `Overall: ${percentage}%` : `${percentage}%`}</div>
      )}
    </div>
  );
}
