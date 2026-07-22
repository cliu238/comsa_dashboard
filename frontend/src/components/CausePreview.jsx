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
            {unrecognized.map((u) => (
              <li key={u.cause}>
                “{u.cause}” ({u.count} records)
                {u.suggestion
                  ? <> — did you mean <em>{u.suggestion}</em>?</>
                  : <> — no close match; relabel to a supported cause.</>}
              </li>
            ))}
          </ul>
        </div>
      )}

      {excluded_undetermined.length > 0 && (
        <p className="cause-preview-excluded" role="status">
          Excluded (undetermined cause, per vacalibration methodology):{' '}
          {excluded_undetermined.map((e) => `${e.cause} (${e.count})`).join(', ')}.
        </p>
      )}

      {mapping.length > 0 && (
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
      )}
    </div>
  );
}
