import { useState, useEffect } from 'react';
import { getJobStatus, getJobLog, getJobResults, getDownloadUrl } from '../api/client';

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
        {status.error && <span className="error">Error: {status.error}</span>}
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
        {activeTab === 'log' && <LogTab log={log} />}
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

function LogTab({ log }) {
  return (
    <div className="log-tab">
      <pre>{log.length > 0 ? log.join('\n') : 'No log entries yet...'}</pre>
    </div>
  );
}

function ResultsTab({ results, jobId }) {
  if (!results) return <div>Loading results...</div>;

  const causes = Object.keys(results.calibrated_csmf || {});

  return (
    <div className="results-tab">
      <div className="summary">
        <p><strong>Records processed:</strong> {results.n_records}</p>
        <p><strong>Algorithm:</strong> {results.algorithm}</p>
        <p><strong>Age group:</strong> {results.age_group}</p>
        <p><strong>Country:</strong> {results.country}</p>
      </div>

      <h3>CSMF Comparison</h3>
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

      <h3>CSMF Chart</h3>
      <CSMFChart
        causes={causes}
        uncalibrated={results.uncalibrated_csmf}
        calibrated={results.calibrated_csmf}
      />

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

function CSMFChart({ causes, uncalibrated, calibrated }) {
  const maxVal = Math.max(
    ...causes.map(c => Math.max(uncalibrated[c] || 0, calibrated[c] || 0))
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
            <div
              className="bar calibrated"
              style={{ width: `${(calibrated[cause] / maxVal) * 100}%` }}
              title={`Calibrated: ${(calibrated[cause] * 100).toFixed(1)}%`}
            />
          </div>
        </div>
      ))}
      <div className="chart-legend">
        <span><span className="dot uncalibrated"></span> Uncalibrated</span>
        <span><span className="dot calibrated"></span> Calibrated</span>
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
