import { useState, useEffect, useRef, useCallback } from 'react';
import { getJobStatus, getJobLog, getJobResults } from '../api/client';
import { MisclassificationMatrix } from './MisclassificationMatrix.jsx';
import { exportCSMFTable, exportConsolidatedCSMF, exportToPNG, exportToPDF, generateFilename } from '../utils/export';
import { buildCsmfFacets, buildCsmfTableRows, csmfWhisker } from './CSMFChart.js';
import { formatCauseDisplay, sortCausesByValue } from '../utils/causeDisplay.js';
import { formatAlgorithmList, formatAgeGroup } from '../utils/labels.js';
import ProgressIndicator from './ProgressIndicator';
import { formatTimestamp } from '../utils/datetime';

// Cache bust: v0.0.3 - Force rebuild with package.json change
export default function JobDetail({ jobId, onBack }) {
  const [status, setStatus] = useState(null);
  const [log, setLog] = useState([]);
  const [results, setResults] = useState(null);
  const [activeTab, setActiveTab] = useState('status');

  const loadStatus = useCallback(async () => {
    try {
      const data = await getJobStatus(jobId);
      setStatus(data);
    } catch (err) {
      console.error('Failed to load status:', err);
    }
  }, [jobId]);

  const loadLog = useCallback(async () => {
    try {
      const data = await getJobLog(jobId);
      const rawLog = data.log || [];
      setLog(Array.isArray(rawLog) ? rawLog : [rawLog]);
    } catch (err) {
      console.error('Failed to load log:', err);
    }
  }, [jobId]);

  const loadResults = useCallback(async () => {
    try {
      const data = await getJobResults(jobId);
      if (!data.error) {
        setResults(data);
      }
    } catch (err) {
      console.error('Failed to load results:', err);
    }
  }, [jobId]);

  useEffect(() => {
    if (!jobId) return;

    // Defer initial fetch to a callback (satisfies react-hooks/set-state-in-effect)
    const initial = setTimeout(() => {
      loadStatus();
      loadLog();
    }, 0);

    // Poll for updates while job is running (3 second interval)
    const interval = setInterval(() => {
      if (status?.status === 'pending' || status?.status === 'running') {
        loadStatus();
        loadLog();
      }
    }, 3000);

    return () => {
      clearTimeout(initial);
      clearInterval(interval);
    };
  }, [jobId, status?.status, loadStatus, loadLog]);

  useEffect(() => {
    if (status?.status !== 'completed') return;
    const timeout = setTimeout(loadResults, 0);
    return () => clearTimeout(timeout);
  }, [status?.status, loadResults]);

  if (!status) return <div className="loading">Loading...</div>;

  return (
    <div className="job-detail">
      <button className="back-btn" onClick={onBack}>&larr; Back</button>

      <h2 title={jobId}>Job: {jobId.slice(0, 8)}...</h2>

      <div className="job-meta">
        <span className={`status ${status.status}`}>{status.status}</span>
        <span>Type: {status.type}</span>
        {(() => {
          // Check if error should be displayed
          if (!status.error) return null;

          // Handle array format from R: ["{}"]
          if (Array.isArray(status.error)) {
            const firstElement = status.error[0];
            if (firstElement === '{}' || firstElement === 'null' || !firstElement) return null;
            if (typeof firstElement === 'object' && Object.keys(firstElement).length === 0) return null;
          }

          // Handle object format: {}
          if (typeof status.error === 'object' && Object.keys(status.error).length === 0) return null;

          // Display error
          const errorText = typeof status.error === 'string' ? status.error :
                           Array.isArray(status.error) ? (status.error[0]?.message || status.error[0]) :
                           status.error.message || JSON.stringify(status.error);

          return <span className="error">Error: {errorText}</span>;
        })()}
      </div>

      <div className="tabs">
        <button
          className={activeTab === 'status' ? 'active' : ''}
          onClick={() => setActiveTab('status')}
        >
          Status
        </button>
        <button
          className={activeTab === 'log' ? 'active' : ''}
          onClick={() => setActiveTab('log')}
        >
          Log
        </button>
        <button
          className={activeTab === 'results' ? 'active' : ''}
          onClick={() => setActiveTab('results')}
          disabled={status.status !== 'completed'}
        >
          Results
        </button>
      </div>

      <div className="tab-content">
        {activeTab === 'status' && <StatusTab status={status} log={log} />}
        {activeTab === 'log' && <LogTab log={log} jobId={jobId} status={status} />}
        {activeTab === 'results' && <ResultsTab results={results} jobId={jobId} />}
      </div>
    </div>
  );
}

function StatusTab({ status, log }) {
  const isRunning = status.status === 'running' || status.status === 'pending';

  return (
    <div className="status-tab">
      {isRunning && (
        <ProgressIndicator logs={log} startedAt={status.started_at} />
      )}
      <table>
        <tbody>
          <tr><td>Status</td><td>{status.status}</td></tr>
          <tr><td>Type</td><td>{status.type}</td></tr>
          <tr><td>Created</td><td>{formatTimestamp(status.created_at)}</td></tr>
          <tr><td>Started</td><td>{formatTimestamp(status.started_at)}</td></tr>
          <tr><td>Completed</td><td>{formatTimestamp(status.completed_at)}</td></tr>
        </tbody>
      </table>
    </div>
  );
}

function LogTab({ log, jobId, status }) {
  const logEndRef = useRef(null);
  const isRunning = status?.status === 'pending' || status?.status === 'running';

  // Auto-scroll to bottom when new log entries arrive (only while running)
  useEffect(() => {
    if (isRunning && logEndRef.current) {
      logEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [log.length, isRunning]);

  const getAlgorithmInfo = () => {
    if (!status.algorithm) return null;
    if (Array.isArray(status.algorithm)) {
      return status.algorithm.join(' + ');
    }
    return status.algorithm;
  };

  const algorithm = getAlgorithmInfo();

  return (
    <div className="log-tab">
      <div className="log-header">
        <p><strong>Job ID:</strong> {jobId}</p>
        {status.type && <p><strong>Job Type:</strong> {status.type}</p>}
        {algorithm && <p><strong>Algorithm:</strong> {algorithm}</p>}
        {status.age_group && <p><strong>Age Group:</strong> {status.age_group}</p>}
        {status.country && <p><strong>Country:</strong> {status.country === 'other' ? 'All the countries' : status.country}</p>}
        {status.status && (
          <p>
            <strong>Status:</strong>{' '}
            <span className={`status ${status.status}`}>{status.status}</span>
          </p>
        )}
      </div>
      <h4>Execution Log:</h4>
      <pre>{log.length > 0 ? log.join('\n') : 'No log entries yet...'}<span ref={logEndRef} /></pre>
    </div>
  );
}

function ResultsTab({ results, jobId }) {
  if (!results) return <div>Loading results...</div>;

  // Check if this is an openVA-only result (has csmf but not calibrated_csmf)
  const isOpenVAOnly = results.csmf && !results.calibrated_csmf;

  if (isOpenVAOnly) {
    return <OpenVAResults results={results} jobId={jobId} />;
  }

  return <CalibratedResults results={results} jobId={jobId} />;
}

function OpenVAResults({ results, jobId }) {
  const causes = sortCausesByValue(Object.keys(results.csmf || {}), results.csmf || {});

  // Convert to format expected by exportCSMFTable
  const exportData = {
    csmf: results.csmf,
    algorithm: results.algorithm || 'OpenVA'
  };

  return (
    <div className="results-tab">
      <div className="summary">
        <p><strong>Algorithm:</strong> {formatAlgorithmList(results.algorithm || 'OpenVA')}</p>
      </div>

      <div className="section-header">
        <h3>Cause-Specific Mortality Fractions (CSMF)</h3>
        <div className="export-buttons">
          <button
            onClick={() => exportCSMFTable(exportData, jobId, results.algorithm || 'OpenVA')}
            className="export-btn"
            title="Export CSMF table as CSV"
          >
            CSV ↓
          </button>
        </div>
      </div>
      <table className="csmf-table">
        <thead>
          <tr>
            <th>Cause</th>
            <th>CSMF</th>
            <th>Count</th>
          </tr>
        </thead>
        <tbody>
          {causes.map((cause) => (
            <tr key={cause}>
              <td>{cause}</td>
              <td>{(results.csmf[cause] * 100).toFixed(1)}%</td>
              <td>{results.cause_counts?.[cause] || '-'}</td>
            </tr>
          ))}
        </tbody>
      </table>

    </div>
  );
}

function CalibratedResults({ results, jobId }) {
  const displayNames = results.cause_display_names || null;
  const chartRef = useRef(null);
  const csmfTableRef = useRef(null);

  const algorithmsDisplay = formatAlgorithmList(results.algorithm);
  const isEnsemble = Array.isArray(results.algorithm) && results.algorithm.length > 1;
  const tableData = buildCsmfTableRows(results);

  return (
    <div className="results-tab">
      <div className="summary">
        <p><strong>Algorithm(s):</strong> {algorithmsDisplay}</p>
        <p><strong>Age group:</strong> {formatAgeGroup(results.age_group)}</p>
        <p><strong>Country:</strong> {results.country === 'other' ? 'All the countries' : results.country}</p>
        {isEnsemble && (
          <p className="ensemble-indicator">
            <strong>✓ Ensemble Mode:</strong> Results calibrated across {results.algorithm.length} algorithms
          </p>
        )}
      </div>

      {/* Misclassification Matrix (full width) */}
      {results.misclassification_matrix && (
        <MisclassificationMatrix matrixData={results.misclassification_matrix} jobId={jobId} causeDisplayNames={displayNames} causeOrder={results.cause_order} />
      )}

      {/* CSMF Chart (full width, above the comparison table so all facets —
          incl. Ensemble when running multiple CCVAs — stay viewable; issue #78) */}
      <div className="section-header">
        <h3>Cause-Specific Mortality Fractions (CSMF) Chart</h3>
        <div className="export-buttons">
          <button onClick={() => exportToPNG(chartRef, generateFilename('csmf_chart', algorithmsDisplay, jobId, 'png'))} className="export-btn" title="Export as PNG">PNG ↓</button>
          <button onClick={() => exportToPDF(chartRef, generateFilename('csmf_chart', algorithmsDisplay, jobId, 'pdf'))} className="export-btn" title="Export as PDF">PDF ↓</button>
        </div>
      </div>
      <div ref={chartRef}>
        <CSMFChart results={results} causeDisplayNames={displayNames} />
      </div>

      {/* Consolidated CSMF table: each algorithm x {Uncalibrated, Calibrated} */}
      <div className="section-header">
        <h3>CSMF Comparison</h3>
        <div className="export-buttons">
          <button onClick={() => exportConsolidatedCSMF(tableData, jobId, algorithmsDisplay)} className="export-btn" title="Export as CSV">CSV ↓</button>
          <button onClick={() => exportToPNG(csmfTableRef, generateFilename('csmf_table', algorithmsDisplay, jobId, 'png'))} className="export-btn" title="Export as PNG">PNG ↓</button>
          <button onClick={() => exportToPDF(csmfTableRef, generateFilename('csmf_table', algorithmsDisplay, jobId, 'pdf'))} className="export-btn" title="Export as PDF">PDF ↓</button>
        </div>
      </div>
      <div ref={csmfTableRef}>
        <table className="csmf-table consolidated">
          <thead>
            <tr>
              <th>Algorithm</th>
              <th>Type</th>
              {tableData.causes.map(cause => (
                <th key={cause}>{formatCauseDisplay(cause, displayNames)}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {tableData.groups.map(group => (
              group.rows.map((row, rowIdx) => (
                <tr key={`${group.algorithm}-${row.type}`} className={group.algorithm === 'Ensemble' ? 'ensemble-row' : ''}>
                  {rowIdx === 0 && <td className="algo-cell" rowSpan={group.rows.length}>{group.algorithm}</td>}
                  <td className="type-cell">{row.type}</td>
                  {row.cells.map(cell => (
                    <td key={cell.cause}>
                      {cell.mean == null ? '-' : (
                        cell.lower != null && cell.upper != null
                          ? `${cell.mean}% (${cell.lower}–${cell.upper})`
                          : `${cell.mean}%`
                      )}
                    </td>
                  ))}
                </tr>
              ))
            ))}
          </tbody>
        </table>
      </div>

    </div>
  );
}

const Y_TICKS = [1, 0.75, 0.5, 0.25, 0];

function CSMFChart({ results, causeDisplayNames }) {
  const facets = buildCsmfFacets(results);
  if (facets.length === 0) return null;

  return (
    <div className="csmf-figure">
      <div className="csmf-facets">
        {facets.map(facet => (
          <div key={facet.label} className="csmf-facet">
            <div className="csmf-facet-title">{facet.label}</div>
            <div className="csmf-plot">
              <div className="csmf-yaxis">
                {Y_TICKS.map(t => (
                  <span key={t} className="csmf-ytick" style={{ bottom: `${t * 100}%` }}>
                    {t === 1 ? '1.0' : t === 0 ? '0' : t.toFixed(2).slice(1)}
                  </span>
                ))}
              </div>
              <div className="csmf-plotarea">
                {Y_TICKS.map(t => (
                  <div key={t} className="csmf-gridline" style={{ bottom: `${t * 100}%` }} />
                ))}
                <div className="csmf-bars">
                  {facet.causes.map(({ cause, uncalibrated, calibrated, ciLower, ciUpper }) => (
                    <div key={cause} className="csmf-group" title={formatCauseDisplay(cause, causeDisplayNames)}>
                      <div className="csmf-bar uncal" style={{ height: `${uncalibrated * 100}%` }}
                        title={`Uncalibrated: ${(uncalibrated * 100).toFixed(1)}%`} />
                      <div className="csmf-bar cal" style={{ height: `${calibrated * 100}%` }}
                        title={`Calibrated: ${(calibrated * 100).toFixed(1)}%`}>
                        {(() => {
                          const w = csmfWhisker(calibrated, ciLower, ciUpper);
                          return w && (
                            <div className="csmf-whisker"
                              style={{ bottom: `${w.bottomPct}%`, height: `${w.heightPct}%` }}
                              title={`95% CI: [${(ciLower * 100).toFixed(1)}% - ${(ciUpper * 100).toFixed(1)}%]`} />
                          );
                        })()}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
            <div className="csmf-xlabels">
              {facet.causes.map(({ cause }) => (
                <span key={cause} className="csmf-xlabel">{formatCauseDisplay(cause, causeDisplayNames)}</span>
              ))}
            </div>
          </div>
        ))}
      </div>
      <div className="csmf-legend">
        <span><span className="csmf-dot uncal" /> Uncalibrated</span>
        <span><span className="csmf-dot cal" /> Calibrated</span>
        <span><span className="csmf-dot ci" /> 95% CI</span>
      </div>
    </div>
  );
}

