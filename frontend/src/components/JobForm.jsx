import { useState, useEffect } from 'react';
import { submitJob, submitDemoJob, getJobStatus, getJobLog, previewMapping } from '../api/client';
import ProgressIndicator from './ProgressIndicator';
import CustomSelect from './CustomSelect';
import CausePreview from './CausePreview';

let nextUploadId = 1;

// The form only submits calibration jobs: CCVA output -> calibrated cause
// distribution. (Individual VA records input / top-cause output were removed in
// issue #79 — they did not run smoothly in this interface.)
const JOB_TYPE = 'vacalibration';

// Fixed display order for the CCVA algorithms, matching the selection-panel
// checkbox order. Upload rows are sorted by this so the two lists always agree
// regardless of the order the user checked the boxes (issue #88).
const ALGORITHM_DISPLAY_ORDER = ['EAVA', 'InSilicoVA', 'InterVA'];
const algoOrderIndex = (algo) => {
  const i = ALGORITHM_DISPLAY_ORDER.indexOf(algo);
  return i === -1 ? ALGORITHM_DISPLAY_ORDER.length : i;
};

// Broad causes accepted for calibration, per age group (issue #92). Standard
// algorithm-specific cause names are auto-mapped to these; any cause that maps
// to none of them is reported as an error, not silently dropped.
const SUPPORTED_CAUSES = {
  neonate: ['Congenital Malformation', 'Pneumonia', 'Sepsis/Meningitis', 'Intrapartum Events', 'Prematurity', 'Other'],
  child: ['Malaria', 'Pneumonia', 'Diarrhea', 'Severe Malnutrition', 'HIV', 'Injury', 'Other Infections', 'Neonatal Causes', 'Other'],
};

export default function JobForm({ onJobSubmitted }) {
  const [algorithms, setAlgorithms] = useState(['InterVA']);  // Array instead of single value
  const [ageGroup, setAgeGroup] = useState('neonate');
  const [country, setCountry] = useState('Mozambique');
  const [uploads, setUploads] = useState([{ id: nextUploadId++, algorithm: '', file: null }]);
  const [calibModelType, setCalibModelType] = useState('Mmatprior');
  const [ensemble, setEnsemble] = useState(false);
  const [ensembleUserTouched, setEnsembleUserTouched] = useState(false);
  const [showAdvanced, setShowAdvanced] = useState(false);
  const [nMCMC, setNMCMC] = useState(5000);
  const [nBurn, setNBurn] = useState(2000);
  const [nThin, setNThin] = useState(1);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [validationError, setValidationError] = useState(null);
  const [activeJob, setActiveJob] = useState(null);
  const [activeJobLog, setActiveJobLog] = useState([]);
  const [previewReports, setPreviewReports] = useState({});
  const [previewPending, setPreviewPending] = useState(false);
  const [previewNotice, setPreviewNotice] = useState(null);
  // Block on both an explicit has_errors flag and a structured per-file error
  // (e.g. parse/column failure), so a preview error can never leave Submit live.
  const previewHasErrors = Object.values(previewReports).some(r => r && (r.has_errors || r.error));

  // Poll active job status
  useEffect(() => {
    if (!activeJob) return;

    const pollJob = async () => {
      try {
        const [statusData, logData] = await Promise.all([
          getJobStatus(activeJob),
          getJobLog(activeJob)
        ]);

        setActiveJobLog(logData.log || []);

        // Job completed or failed
        if (statusData.status === 'completed' || statusData.status === 'failed') {
          setActiveJob(null);
          setActiveJobLog([]);
        }
      } catch (err) {
        console.error('Failed to poll job:', err);
      }
    };

    pollJob();
    const interval = setInterval(pollJob, 5000);

    return () => clearInterval(interval);
  }, [activeJob]);

  // Auto-generate one upload row per checked algorithm (checkboxes are the
  // source of truth; preserve files already attached to a kept algorithm).
  useEffect(() => {
    setUploads(prev =>
      [...algorithms]
        .sort((a, b) => algoOrderIndex(a) - algoOrderIndex(b))
        .map(algo => {
          const existing = prev.find(u => u.algorithm === algo);
          return existing || { id: nextUploadId++, algorithm: algo, file: null };
        })
    );
  }, [algorithms]);

  // Ask the backend how the uploaded causes will map, BEFORE submitting. The
  // backend is the single source of truth for cause mapping (the frontend never
  // maps causes itself). Re-runs whenever attached files or age group change.
  useEffect(() => {
    const withFiles = uploads.filter(u => u.file && u.algorithm);
    if (withFiles.length === 0) {
      setPreviewReports({}); setPreviewPending(false); setPreviewNotice(null);
      return;
    }
    let cancelled = false;
    setPreviewPending(true);
    setPreviewNotice(null);
    previewMapping({ uploads: withFiles, ageGroup })
      // A top-level `error` (e.g. a rejected age_group) is not a per-file cause
      // report, so it must not be swallowed into an empty report set that looks
      // like "preview clean" — and it is a validation rejection, not an outage,
      // so show the backend's own message. Issue #105.
      .then(res => {
        if (cancelled) return;
        setPreviewPending(false);
        if (res.error) {
          setPreviewReports({});
          setPreviewNotice(`Couldn't preview cause mapping: ${res.error} Your file will still be validated when you submit.`);
          return;
        }
        setPreviewReports(res.reports || {});
      })
      // Network/server failure is degraded gracefully: surface a non-blocking
      // notice rather than silently clearing, but keep Submit live — the /jobs
      // endpoint re-validates on submit, so a transient preview blip must not
      // strand the user.
      .catch(() => {
        if (cancelled) return;
        setPreviewReports({}); setPreviewPending(false);
        setPreviewNotice("Couldn't preview cause mapping (service unavailable). Your file will still be validated when you submit.");
      });
    return () => { cancelled = true; };
  }, [uploads, ageGroup]);

  // Validation: at least one algorithm must be selected.
  useEffect(() => {
    setValidationError(algorithms.length === 0 ? 'Please select at least one algorithm' : null);
  }, [algorithms]);

  // When the user crosses from 1 to 2+ algorithms, auto-enable the ensemble
  // checkbox — UNLESS the user has explicitly touched it (sticky behavior).
  useEffect(() => {
    if (algorithms.length >= 2 && !ensembleUserTouched) {
      setEnsemble(true);
    }
  }, [algorithms, ensembleUserTouched]);

  const handleAlgorithmToggle = (algo) => {
    setAlgorithms(prev => {
      if (prev.includes(algo)) {
        const updated = prev.filter(a => a !== algo);
        return updated.length > 0 ? updated : prev;  // Prevent empty array
      } else {
        return [...prev, algo];
      }
    });
  };

  const updateUpload = (index, field, value) => {
    setUploads(prev => prev.map((u, i) => i === index ? { ...u, [field]: value } : u));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    // Validation
    if (algorithms.length === 0) {
      setError('Please select at least one algorithm');
      setLoading(false);
      return;
    }

    try {
      const result = await submitJob({
        uploads,
        jobType: JOB_TYPE,
        algorithms,
        ageGroup,
        country,
        calibModelType,
        ensemble: ensemble && algorithms.length >= 2,
        nMCMC,
        nBurn,
        nThin
      });

      if (result.error) {
        setError(result.error);
      } else {
        setActiveJob(result.job_id);
        onJobSubmitted(result.job_id);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleDemo = async () => {
    setLoading(true);
    setError(null);

    // Validation
    if (algorithms.length === 0) {
      setError('Please select at least one algorithm');
      setLoading(false);
      return;
    }

    try {
      const result = await submitDemoJob({ jobType: JOB_TYPE, algorithms, ageGroup, country, calibModelType, ensemble: ensemble && algorithms.length >= 2, nMCMC, nBurn, nThin });
      if (result.error) {
        setError(result.error);
      } else {
        setActiveJob(result.job_id);
        onJobSubmitted(result.job_id);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="job-form">
      <h2>Submit Job</h2>
      <p className="required-legend"><span className="required">*</span> Required fields</p>

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>Input Type <span className="required">*</span></label>
          <div className="output-type-locked">Output from CCVA</div>
        </div>

        <div className="form-group">
          <label>Output Type <span className="required">*</span></label>
          <div className="output-type-locked">Cause Distribution</div>
        </div>

        <div className="form-group">
          <label>Country <span className="required">*</span></label>
          <CustomSelect
            value={country}
            onChange={setCountry}
            options={[
              { value: 'Bangladesh', label: 'Bangladesh' },
              { value: 'Ethiopia', label: 'Ethiopia' },
              { value: 'Kenya', label: 'Kenya' },
              { value: 'Mali', label: 'Mali' },
              { value: 'Mozambique', label: 'Mozambique' },
              { value: 'Sierra Leone', label: 'Sierra Leone' },
              { value: 'South Africa', label: 'South Africa' },
              { value: 'other', label: 'All the countries' }
            ]}
          />
        </div>

        <div className="form-group">
          <label>Age Group <span className="required">*</span></label>
          <CustomSelect
            value={ageGroup}
            onChange={setAgeGroup}
            options={[
              { value: 'neonate', label: 'Neonate (0-27 days)' },
              { value: 'child', label: 'Children (1-59 months)' }
            ]}
          />
        </div>

        <div className="form-group">
          <label>Computer-Coded Verbal Autopsy (CCVA) Algorithms <span className="required">*</span></label>

          <div className="algorithm-checkboxes">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={algorithms.includes('EAVA')}
                onChange={() => handleAlgorithmToggle('EAVA')}
              />
              EAVA
            </label>
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={algorithms.includes('InSilicoVA')}
                onChange={() => handleAlgorithmToggle('InSilicoVA')}
              />
              InSilicoVA
            </label>
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={algorithms.includes('InterVA')}
                onChange={() => handleAlgorithmToggle('InterVA')}
              />
              InterVA
            </label>
          </div>

          {/* Ensemble row: always rendered, disabled when <2 algos */}
          <div className="ensemble-toggle">
            <label>
              <input
                type="checkbox"
                checked={ensemble && algorithms.length >= 2}
                disabled={algorithms.length < 2}
                onChange={(e) => {
                  setEnsembleUserTouched(true);
                  setEnsemble(e.target.checked);
                }}
              />
              {' '}Combine algorithms?
            </label>
            {algorithms.length < 2 ? (
              <small className="form-hint">Requires 2+ algorithms</small>
            ) : (
              <small className="form-hint">
                Runs per-algorithm calibration plus an additional combined ensemble result.
              </small>
            )}
          </div>

          {validationError && <small className="validation-error">{validationError}</small>}
        </div>

        <div className="form-group">
          <label>Uncertainty in CCVA misclassification</label>
          <label className="checkbox-label">
            <input
              type="checkbox"
              checked={calibModelType === 'Mmatprior'}
              onChange={(e) => setCalibModelType(e.target.checked ? 'Mmatprior' : 'Mmatfixed')}
            />
            {' '}Propagate
          </label>
          <small className="form-hint">
            Controls whether to propagate uncertainty in{' '}
            <a
              href="https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices"
              target="_blank"
              rel="noopener noreferrer"
            >
              CCVA misclassification estimate
            </a>
          </small>
        </div>

        <div className="form-group">
          <label>Upload VA Data <span className="required">*</span></label>
          {uploads.map((upload, index) => (
            <div key={upload.id} className="upload-row">
              <span className="upload-algo-label">{upload.algorithm}</span>
              <input
                type="file"
                accept=".csv"
                onChange={(e) => updateUpload(index, 'file', e.target.files[0])}
              />
              {upload.file && <span className="file-name">{upload.file.name}</span>}
            </div>
          ))}
          {previewPending && <p className="cause-preview-pending" role="status">Checking cause mapping…</p>}
          {previewNotice && (
            <p className="cause-preview-unavailable" role="status">
              {previewNotice}
            </p>
          )}
          {Object.entries(previewReports).map(([algo, report]) => (
            <CausePreview key={algo} report={report}
              algorithmLabel={algo.charAt(0).toUpperCase() + algo.slice(1)} />
          ))}
          <small className="form-hint">
            Upload one CSV file per selected algorithm. Required columns: ID, cause.
          </small>
          <small className="form-hint">
            Supported causes ({ageGroup === 'neonate' ? 'neonate' : '1-59 months'}):{' '}
            {SUPPORTED_CAUSES[ageGroup].join(', ')}. Standard algorithm cause names are
            auto-mapped; any unrecognized cause is reported (records are never silently dropped).
          </small>
          <small className="form-hint">
            See the{' '}
            <a
              href="https://github.com/sandy-pramanik/vacalibration"
              target="_blank"
              rel="noopener noreferrer"
            >
              vacalibration example code
            </a>
            {' '}for how to prepare, run, and save input data.
          </small>
          <div className="sample-download">
            <div className="sample-links">
              <span>Sample CSV (neonate):</span>
              <a href={`${import.meta.env.BASE_URL}sample_eava_neonate.csv`} download>EAVA</a>
              <a href={`${import.meta.env.BASE_URL}sample_insilicova_neonate.csv`} download>InSilicoVA</a>
              <a href={`${import.meta.env.BASE_URL}sample_interva_neonate.csv`} download>InterVA</a>
            </div>
            <div className="sample-links">
              <span>Sample CSV (1-59 months):</span>
              <a href={`${import.meta.env.BASE_URL}sample_eava_child.csv`} download>EAVA</a>
              <a href={`${import.meta.env.BASE_URL}sample_insilicova_child.csv`} download>InSilicoVA</a>
              <a href={`${import.meta.env.BASE_URL}sample_interva_child.csv`} download>InterVA</a>
            </div>
          </div>
        </div>

        {/* MCMC Specifics */}
        <div className="form-group">
          <button
            type="button"
            className="advanced-toggle"
            onClick={() => setShowAdvanced(!showAdvanced)}
          >
            {showAdvanced ? '▾' : '▸'} MCMC Specifics
          </button>
          {showAdvanced && (
            <div className="advanced-settings">
              <div className="advanced-row">
                <label>
                  MCMC Iterations
                  <input
                    type="number"
                    value={nMCMC}
                    min={0}
                    step={1000}
                    onChange={(e) => setNMCMC(Number(e.target.value))}
                  />
                </label>
                <label>
                  Burn-in
                  <input
                    type="number"
                    value={nBurn}
                    min={0}
                    step={1000}
                    onChange={(e) => setNBurn(Number(e.target.value))}
                  />
                </label>
                <label>
                  Thinning
                  <input
                    type="number"
                    value={nThin}
                    min={1}
                    step={1}
                    onChange={(e) => setNThin(Number(e.target.value))}
                  />
                </label>
              </div>
              <small className="form-hint">
                Higher iteration improves accuracy but requires more time.<br />
                Burn-in discards early samples to warm up MCMC chain.<br />
                Thinning reduces dependency between subsequent MCMC samples.
              </small>
            </div>
          )}
        </div>

        {/* Demo info */}
        <div className="demo-info">
          <small className="form-hint">
            💡 No file? Click "Run Demo" to test with COMSA Mozambique sample data
            (1190 neonatal records)
          </small>
        </div>

        {error && <div className="error">{error}</div>}

        {/* Show progress indicator when a job is running */}
        {activeJob && (
          <div className="form-progress">
            <ProgressIndicator logs={activeJobLog} startedAt={new Date()} />
            <p className="form-progress-note">
              Job <code title={activeJob}>{activeJob.slice(0, 8)}...</code> is running.
              View details in the job list.
            </p>
          </div>
        )}

        <div className="form-actions">
          <button type="submit" disabled={loading || activeJob || uploads.some(u => !u.file) || previewHasErrors || previewPending}>
            {loading ? 'Calibrating...' : activeJob ? 'Job Running...' : 'Calibrate'}
          </button>
          <button type="button" onClick={handleDemo} disabled={loading || activeJob}>
            {loading ? 'Running...' : activeJob ? 'Job Running...' : 'Run Demo'}
          </button>
        </div>
      </form>
    </div>
  );
}
