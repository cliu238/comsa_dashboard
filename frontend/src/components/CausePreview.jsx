// R hands us a length-1 vector as ["x"] and a NULL as {} — an EMPTY OBJECT, which
// is truthy in JS. `suggestion = if (is.na(s)) NULL else s` (backend/jobs/utils.R)
// therefore arrives as {} whenever no close match was found, and rendering that as
// a React child throws "Objects are not valid as a React child". Unwrap the vector
// and treat the empty object as absent.
function scalar(value) {
  if (value == null) return null;
  if (Array.isArray(value)) return value.length ? scalar(value[0]) : null;
  if (typeof value === 'object') return null;
  return value;
}

// Renders the backend's cause-mapping report for one algorithm. Purely
// presentational — all mapping decisions come from the backend report, so the
// frontend never re-implements the cause taxonomy.
export default function CausePreview({ report, algorithmLabel }) {
  if (!report) return null;
  if (report.error) {
    return <div className="cause-preview error" role="alert">{algorithmLabel}: {report.error}</div>;
  }
  const { total_records, calibrated_denominator, excluded_undetermined = [],
          unrecognized = [], mapping = [] } = report;
  return (
    <div className={`cause-preview${unrecognized.length ? ' has-errors' : ''}`}>
      <p className="cause-preview-headline">
        <strong>{algorithmLabel}:</strong> {calibrated_denominator} of {total_records} records will be calibrated.
      </p>

      {unrecognized.length > 0 && (
        <div className="cause-preview-unrecognized" role="alert">
          <p>{unrecognized.length} unrecognized cause(s) — fix these before submitting:</p>
          <ul>
            {unrecognized.map((u) => {
              const cause = scalar(u.cause);
              const suggestion = scalar(u.suggestion);
              return (
                <li key={cause}>
                  “{cause}” ({scalar(u.count)} records)
                  {suggestion
                    ? <> — did you mean <em>{suggestion}</em>?</>
                    : <> — no close match; relabel to a supported cause.</>}
                </li>
              );
            })}
          </ul>
        </div>
      )}

      {excluded_undetermined.length > 0 && (
        <p className="cause-preview-excluded" role="status">
          Excluded (undetermined cause, per vacalibration methodology):{' '}
          {excluded_undetermined.map((e) => `${e.cause} (${e.count})`).join(', ')}.
        </p>
      )}

      {/* Collapsed by default: three algorithms produced ~27 table rows inline and
          pushed Calibrate off-screen (issue #104). Everything that BLOCKS submission
          — unrecognized causes, undetermined exclusions — stays above, always visible. */}
      {mapping.length > 0 && (
        <details className="cause-preview-details">
          <summary>View cause mapping ({mapping.length} causes)</summary>
          <table className="cause-preview-table">
            <thead><tr><th>Your cause</th><th>Maps to</th><th>Records</th></tr></thead>
            <tbody>
              {mapping.map((m) => (
                <tr key={m.input_cause}>
                  <td>{m.input_cause}</td><td>{m.broad_cause}</td><td>{m.count}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </details>
      )}
    </div>
  );
}
