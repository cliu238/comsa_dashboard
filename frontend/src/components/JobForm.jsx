import { useState, useEffect } from 'react';
import { submitJob, submitDemoJob, getJobStatus, getJobLog } from '../api/client';
import ProgressIndicator from './ProgressIndicator';
import CustomSelect from './CustomSelect';
import { INPUT_TYPES, outputTypeOptions, deriveJobType, jobTypeToSelectors } from '../utils/jobTypeMapping';

let nextUploadId = 1;

const INITIAL_SELECTORS = jobTypeToSelectors('vacalibration');

export default function JobForm({ onJobSubmitted }) {
  const [inputType, setInputType] = useState(INITIAL_SELECTORS.inputType);
  const [outputType, setOutputType] = useState(INITIAL_SELECTORS.outputType);
  const jobType = deriveJobType(inputType, outputType);
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

  // When Input Type changes, snap Output Type to the first valid option for it.
  useEffect(() => {
    setOutputType(outputTypeOptions(inputType)[0].value);
  }, [inputType]);

  // Sync algorithms state when switching between single/multi mode.
  useEffect(() => {
    const needsSingleSelect =
      jobType === 'openva' ||
      (jobType === 'pipeline' && !ensemble);

    if (needsSingleSelect) {
      setAlgorithms(prev => prev.length > 1 ? [prev[0]] : prev);
    }

    // For openva/pipeline modes, collapse uploads to a single row.
    if (jobType !== 'vacalibration') {
      setUploads(prev => prev.length > 1 ? [prev[0]] : prev);
    }
  }, [jobType, ensemble]);

  // Auto-generate upload rows from checked algorithms (calibration-only mode:
  // always per-algorithm; pipeline/openva: single upload).
  useEffect(() => {
    if (jobType === 'vacalibration') {
      setUploads(prev => {
        return algorithms.map(algo => {
          const existing = prev.find(u => u.algorithm === algo);
          return existing || { id: nextUploadId++, algorithm: algo, file: null };
        });
      });
    }
  }, [algorithms, jobType]);

  // Validation for ensemble requirements
  useEffect(() => {
    if (algorithms.length === 0) {
      setValidationError('Please select at least one algorithm');
    } else if (jobType === 'pipeline' && ensemble && algorithms.length < 2) {
      // Pipeline still requires explicit validation (its ensemble checkbox is
      // user-toggled before the algorithm picker — different UX shape).
      setValidationError('Ensemble calibration requires at least 2 algorithms');
    } else {
      setValidationError(null);
    }
  }, [ensemble, algorithms, jobType]);

  // Effect B (algorithms-first flow): when the user crosses from 1 to 2+
  // algorithms in calibration-only mode, auto-enable the ensemble checkbox —
  // UNLESS the user has explicitly touched it (sticky behavior).
  useEffect(() => {
    if (
      jobType === 'vacalibration' &&
      algorithms.length >= 2 &&
      !ensembleUserTouched
    ) {
      setEnsemble(true);
    }
  }, [algorithms, jobType, ensembleUserTouched]);

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

  const handleAlgorithmSelect = (algo) => {
    setAlgorithms([algo]);  // Single selection - replace entire array
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

    if (ensemble && algorithms.length < 2 && jobType === 'pipeline') {
      setError('Ensemble calibration requires at least 2 algorithms');
      setLoading(false);
      return;
    }

    try {
      const result = await submitJob({
        uploads,
        jobType,
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

    if (ensemble && algorithms.length < 2 && jobType === 'pipeline') {
      setError('Ensemble calibration requires at least 2 algorithms');
      setLoading(false);
      return;
    }

    try {
      const result = await submitDemoJob({ jobType, algorithms, ageGroup, country, calibModelType, ensemble: ensemble && algorithms.length >= 2, nMCMC, nBurn, nThin });
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
      <h2>Submit New Job</h2>

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>Input Type <span className="required">*</span></label>
          <CustomSelect
            value={inputType}
            onChange={setInputType}
            options={INPUT_TYPES}
          />
        </div>

        <div className="form-group">
          <label>Output Type <span className="required">*</span></label>
          {inputType === 'individual' ? (
            <CustomSelect
              value={outputType}
              onChange={setOutputType}
              options={outputTypeOptions('individual')}
            />
          ) : (
            <div className="output-type-locked">Cause Distribution</div>
          )}
        </div>

        {/* Country: needed for vacalibration and pipeline, not for openva */}
        {jobType !== 'openva' && (
          <div className="form-group">
            <label>Country</label>
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
                { value: 'other', label: 'Other' }
              ]}
            />
          </div>
        )}

        <div className="form-group">
          <label>Age Group</label>
          <CustomSelect
            value={ageGroup}
            onChange={setAgeGroup}
            options={[
              { value: 'neonate', label: 'Neonate (0-27 days)' },
              { value: 'child', label: 'Children (1-59 months)' }
            ]}
          />
        </div>

        {/* Algorithm Selection - split by job type */}
        {jobType === 'openva' && (
          <div className="form-group">
            <label>Computer-Coded Verbal Autopsy (CCVA) Algorithm</label>
            <CustomSelect
              value={algorithms[0] || 'InterVA'}
              onChange={handleAlgorithmSelect}
              options={[
                { value: 'InterVA', label: 'InterVA (fastest, ~30sec)' },
                { value: 'InSilicoVA', label: 'InSilicoVA (most accurate, ~2-3min)' },
                { value: 'EAVA', label: 'EAVA (deterministic, ~1min)' }
              ]}
            />
            {validationError && <small className="validation-error">{validationError}</small>}
          </div>
        )}

        {jobType === 'pipeline' && (
          <div className="form-group">
            <label>
              Computer-Coded Verbal Autopsy (CCVA) Algorithm{ensemble ? 's' : ''}
              {ensemble && (
                <span className="required"> * Select at least 2 for ensemble</span>
              )}
            </label>

            <div className="ensemble-toggle">
              <label>
                <input
                  type="checkbox"
                  checked={ensemble}
                  onChange={(e) => setEnsemble(e.target.checked)}
                />
                {' '}Ensemble Mode (combine multiple algorithms)
              </label>
            </div>

            {ensemble ? (
              <div className="algorithm-checkboxes">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={algorithms.includes('InterVA')}
                    onChange={() => handleAlgorithmToggle('InterVA')}
                  />
                  InterVA (fastest, ~30sec)
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={algorithms.includes('InSilicoVA')}
                    onChange={() => handleAlgorithmToggle('InSilicoVA')}
                  />
                  InSilicoVA (most accurate, ~2-3min)
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={algorithms.includes('EAVA')}
                    onChange={() => handleAlgorithmToggle('EAVA')}
                  />
                  EAVA (deterministic, ~1min)
                </label>
                {algorithms.length > 1 && (
                  <small className="form-hint warning">
                    Running {algorithms.length} algorithms will take approximately{' '}
                    {algorithms.length === 2 ? '2-4 minutes' : '4-6 minutes'}
                  </small>
                )}
              </div>
            ) : (
              <CustomSelect
                value={algorithms[0] || 'InterVA'}
                onChange={handleAlgorithmSelect}
                options={[
                  { value: 'InterVA', label: 'InterVA (fastest, ~30sec)' },
                  { value: 'InSilicoVA', label: 'InSilicoVA (most accurate, ~2-3min)' },
                  { value: 'EAVA', label: 'EAVA (deterministic, ~1min)' }
                ]}
              />
            )}

            {validationError && <small className="validation-error">{validationError}</small>}
          </div>
        )}

        {jobType === 'vacalibration' && (
          <div className="form-group">
            <label>Computer-Coded Verbal Autopsy (CCVA) Algorithms *</label>

            <div className="algorithm-checkboxes">
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={algorithms.includes('InterVA')}
                  onChange={() => handleAlgorithmToggle('InterVA')}
                />
                InterVA (fastest, ~30sec)
              </label>
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={algorithms.includes('InSilicoVA')}
                  onChange={() => handleAlgorithmToggle('InSilicoVA')}
                />
                InSilicoVA (most accurate, ~2-3min)
              </label>
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={algorithms.includes('EAVA')}
                  onChange={() => handleAlgorithmToggle('EAVA')}
                />
                EAVA (deterministic, ~1min)
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
                  {' '}Estimated runtime: {algorithms.length === 2 ? '2-4 minutes' : '4-6 minutes'}.
                </small>
              )}
            </div>

            {validationError && <small className="validation-error">{validationError}</small>}
          </div>
        )}

        {/* Vacalibration-specific parameters */}
        {(jobType === 'vacalibration' || jobType === 'pipeline') && (
          <div className="form-group">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={calibModelType === 'Mmatprior'}
                onChange={(e) => setCalibModelType(e.target.checked ? 'Mmatprior' : 'Mmatfixed')}
              />
              {' '}Propagate uncertainty in CCVA misclassification
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
        )}

        {jobType === 'vacalibration' ? (
          <div className="form-group">
            <label>VA Data Files (one CSV per selected algorithm)</label>
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
            <small className="form-hint">
              Upload one CSV file per selected algorithm. Required columns: ID, cause.
            </small>
            <div className="sample-download">
              <div className="sample-links">
                <span>Sample CSV (neonate, 1190 records):</span>
                <a href={`${import.meta.env.BASE_URL}sample_interva_neonate.csv`} download>InterVA</a>
                <a href={`${import.meta.env.BASE_URL}sample_insilicova_neonate.csv`} download>InSilicoVA</a>
                <a href={`${import.meta.env.BASE_URL}sample_eava_neonate.csv`} download>EAVA</a>
              </div>
            </div>
          </div>
        ) : (
          <div className="form-group">
            <label>VA Data File (CSV)</label>
            <input
              type="file"
              accept=".csv"
              onChange={(e) => updateUpload(0, 'file', e.target.files[0])}
            />
            <small className="form-hint">
              WHO 2016 VA questionnaire format (columns: i004a, i004b, ...)
            </small>
            <div className="sample-download">
              <a
                href={`${import.meta.env.BASE_URL}${ageGroup === 'neonate' ? 'sample_openva_neonate.csv' : 'sample_openva_child.csv'}`}
                download
              >
                Download sample CSV ({ageGroup === 'neonate' ? 'neonate' : 'child'})
              </a>
            </div>
          </div>
        )}

        {/* MCMC Specifics - only for jobs with calibration */}
        {(jobType === 'vacalibration' || jobType === 'pipeline') && (
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
        )}

        {/* Demo info */}
        <div className="demo-info">
          <small className="form-hint">
            💡 No file? Click "Run Demo" to test with COMSA Mozambique sample data
            ({jobType === 'vacalibration'
              ? '1190 neonatal records'
              : ageGroup === 'neonate' ? '200 neonatal records' : '1736 child records'})
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
          <button type="submit" disabled={loading || activeJob || (
            jobType === 'vacalibration'
              ? uploads.some(u => !u.file)
              : !uploads[0]?.file
          )}>
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
