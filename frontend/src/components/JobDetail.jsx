import { useState, useEffect, useRef } from 'react';
import { getJobStatus, getJobLog, getJobResults, getDownloadUrl } from '../api/client';
import { MisclassificationMatrix } from './MisclassificationMatrix.jsx';
import { exportCSMFTable, exportToPNG, generateFilename } from '../utils/export';

// Cache bust: v0.0.3 - Force rebuild with package.json change
export default function JobDetail({ jobId, onBack }) {
  const [status, setStatus] = useState(null);
  const [log, setLog] = useState([]);
  const [results, setResults] = useState(null);
  const [activeTab, setActiveTab] = useState('status');

  useEffect(() => {
    if (!jobId) return;

    loadStatus();
    loadLog();

    // Poll for updates while job is running
    const interval = setInterval(() => {
      loadStatus();
      loadLog();
    }, 2000);

    return () => clearInterval(interval);
  }, [jobId]);

  useEffect(() => {
    if (status?.status === 'completed') {
      loadResults();
    }
  }, [status?.status]);

  const loadStatus = async () => {
    try {
      const data = await getJobStatus(jobId);
      setStatus(data);
    } catch (err) {
      console.error('Failed to load status:', err);
    }
  };

  const loadLog = async () => {
    try {
      const data = await getJobLog(jobId);
      setLog(data.log || []);
    } catch (err) {
      console.error('Failed to load log:', err);
    }
  };

  const loadResults = async () => {
    try {
      const data = await getJobResults(jobId);
      if (!data.error) {
        setResults(data);
      }
    } catch (err) {
      console.error('Failed to load results:', err);
    }
  };

  if (!status) return <div className="loading">Loading...</div>;

  return (
    <div className="job-detail">
      <button className="back-btn" onClick={onBack}>&larr; Back</button>

      <h2>Job: {jobId.slice(0, 8)}...</h2>

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
        {activeTab === 'status' && <StatusTab status={status} />}
        {activeTab === 'log' && <LogTab log={log} jobId={jobId} status={status} />}
        {activeTab === 'results' && <ResultsTab results={results} jobId={jobId} />}
      </div>
    </div>
  );
}

function formatDate(value) {
  if (!value) return '-';
  if (typeof value === 'string') return value;
  if (Array.isArray(value)) return new Date(value[0] * 1000).toLocaleString();
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

function StatusTab({ status }) {
  return (
    <div className="status-tab">
      <table>
        <tbody>
          <tr><td>Status</td><td>{status.status}</td></tr>
          <tr><td>Type</td><td>{status.type}</td></tr>
          <tr><td>Created</td><td>{formatDate(status.created_at)}</td></tr>
          <tr><td>Started</td><td>{formatDate(status.started_at)}</td></tr>
          <tr><td>Completed</td><td>{formatDate(status.completed_at)}</td></tr>
        </tbody>
      </table>
    </div>
  );
}

function LogTab({ log, jobId, status }) {
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
        {status.country && <p><strong>Country:</strong> {status.country}</p>}
        {status.status && (
          <p>
            <strong>Status:</strong>{' '}
            <span className={`status ${status.status}`}>{status.status}</span>
          </p>
        )}
      </div>
      <h4>Execution Log:</h4>
      <pre>{log.length > 0 ? log.join('\n') : 'No log entries yet...'}</pre>
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
  const causes = Object.keys(results.csmf || {});

  // Convert to format expected by exportCSMFTable
  const exportData = {
    csmf: results.csmf,
    algorithm: results.algorithm || 'OpenVA'
  };

  return (
    <div className="results-tab">
      <div className="summary">
        <p><strong>Records processed:</strong> {results.n_records}</p>
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

      <h3>Download Files</h3>
      <div className="downloads">
        {results.files && Object.entries(results.files).map(([key, filename]) => (
          <a
            key={key}
            href={getDownloadUrl(jobId, filename)}
            download
            className="download-btn"
          >
            {filename}
          </a>
        ))}
      </div>
    </div>
  );
}

function CalibratedResults({ results, jobId }) {
  const causes = Object.keys(results.calibrated_csmf || {});
  const chartRef = useRef(null);

  // Handle both single algorithm (string) and multiple algorithms (array)
  const algorithmsDisplay = Array.isArray(results.algorithm)
    ? results.algorithm.join(' + ')
    : results.algorithm;
  const isEnsemble = Array.isArray(results.algorithm) && results.algorithm.length > 1;

  // Convert to format expected by exportCSMFTable
  const exportData = {
    csmf_uncalibrated: results.uncalibrated_csmf,
    csmf_calibrated: results.calibrated_csmf,
    csmf_intervals: {},
    algorithm: algorithmsDisplay
  };

  // Add confidence intervals
  causes.forEach(cause => {
    exportData.csmf_intervals[cause] = {
      lower: results.calibrated_ci_lower[cause],
      upper: results.calibrated_ci_upper[cause]
    };
  });

  return (
    <div className="results-tab">
      <div className="summary">
        <p><strong>Records processed:</strong> {results.n_records}</p>
        <p><strong>Algorithm(s):</strong> {algorithmsDisplay}</p>
        <p><strong>Age group:</strong> {results.age_group}</p>
        <p><strong>Country:</strong> {results.country}</p>
        {isEnsemble && (
          <p className="ensemble-indicator">
            <strong>✓ Ensemble Mode:</strong> Results calibrated across {results.algorithm.length} algorithms
          </p>
        )}
      </div>

      <div className="section-header">
        <h3>CSMF Comparison</h3>
        <div className="export-buttons">
          <button
            onClick={() => exportCSMFTable(exportData, jobId, algorithmsDisplay)}
            className="export-btn"
            title="Export CSMF comparison table as CSV"
          >
            CSV ↓
          </button>
        </div>
      </div>
      <table className="csmf-table">
        <thead>
          <tr>
            <th>Cause</th>
            <th>Uncalibrated</th>
            <th>Calibrated</th>
            <th>95% CI</th>
          </tr>
        </thead>
        <tbody>
          {causes.map((cause) => (
            <tr key={cause}>
              <td>{formatCause(cause)}</td>
              <td>{(results.uncalibrated_csmf[cause] * 100).toFixed(1)}%</td>
              <td>{(results.calibrated_csmf[cause] * 100).toFixed(1)}%</td>
              <td>
                [{(results.calibrated_ci_lower[cause] * 100).toFixed(1)}% - {(results.calibrated_ci_upper[cause] * 100).toFixed(1)}%]
              </td>
            </tr>
          ))}
        </tbody>
      </table>

      <div className="section-header">
        <h3>CSMF Chart</h3>
        <div className="export-buttons">
          <button
            onClick={() => exportToPNG(chartRef, generateFilename('csmf_chart', algorithmsDisplay, jobId, 'png'))}
            className="export-btn"
            title="Export CSMF chart as PNG"
          >
            PNG ↓
          </button>
        </div>
      </div>
      <div ref={chartRef}>
        <CSMFChart
          causes={causes}
          uncalibrated={results.uncalibrated_csmf}
          calibrated={results.calibrated_csmf}
          ciLower={results.calibrated_ci_lower}
          ciUpper={results.calibrated_ci_upper}
        />
      </div>

      {/* Misclassification Matrix */}
      {results.misclassification_matrix && (
        <MisclassificationMatrix matrixData={results.misclassification_matrix} jobId={jobId} />
      )}

      <h3>Download Files</h3>
      <div className="downloads">
        {results.files && Object.entries(results.files).map(([key, filename]) => (
          <a
            key={key}
            href={getDownloadUrl(jobId, filename)}
            download
            className="download-btn"
          >
            {filename}
          </a>
        ))}
      </div>
    </div>
  );
}

function CSMFChart({ causes, uncalibrated, calibrated, ciLower, ciUpper }) {
  const maxVal = Math.max(
    ...causes.map(c => Math.max(
      uncalibrated[c] || 0,
      calibrated[c] || 0,
      ciUpper?.[c] || 0
    ))
  );

  return (
    <div className="csmf-chart">
      {causes.map((cause) => (
        <div key={cause} className="chart-row">
          <div className="chart-label">{formatCause(cause)}</div>
          <div className="chart-bars">
            <div
              className="bar uncalibrated"
              style={{ width: `${(uncalibrated[cause] / maxVal) * 100}%` }}
              title={`Uncalibrated: ${(uncalibrated[cause] * 100).toFixed(1)}%`}
            />
            <div className="calibrated-container">
              {ciLower && ciUpper && (
                <div
                  className="ci-range"
                  style={{
                    left: `${(ciLower[cause] / maxVal) * 100}%`,
                    width: `${((ciUpper[cause] - ciLower[cause]) / maxVal) * 100}%`
                  }}
                  title={`95% CI: [${(ciLower[cause] * 100).toFixed(1)}% - ${(ciUpper[cause] * 100).toFixed(1)}%]`}
                />
              )}
              <div
                className="bar calibrated"
                style={{ width: `${(calibrated[cause] / maxVal) * 100}%` }}
                title={`Calibrated: ${(calibrated[cause] * 100).toFixed(1)}%`}
              />
            </div>
          </div>
        </div>
      ))}
      <div className="chart-legend">
        <span><span className="dot uncalibrated"></span> Uncalibrated</span>
        <span><span className="dot calibrated"></span> Calibrated</span>
        <span><span className="dot ci-range"></span> 95% CI</span>
      </div>
    </div>
  );
}

function formatCause(cause) {
  const map = {
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
  return map[cause] || cause;
}
