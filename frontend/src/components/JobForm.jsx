import { useState, useEffect } from 'react';
import { submitJob, submitDemoJob, getJobStatus, getJobLog } from '../api/client';
import ProgressIndicator from './ProgressIndicator';
import CustomSelect from './CustomSelect';

export default function JobForm({ onJobSubmitted }) {
  const [jobType, setJobType] = useState('vacalibration');
  const [algorithms, setAlgorithms] = useState(['InterVA']);  // Array instead of single value
  const [ageGroup, setAgeGroup] = useState('neonate');
  const [country, setCountry] = useState('Mozambique');
  const [file, setFile] = useState(null);
  const [calibModelType, setCalibModelType] = useState('Mmatprior');
  const [ensemble, setEnsemble] = useState(true);
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

  // Sync algorithms state when switching between single/multi mode
  useEffect(() => {
    const needsSingleSelect = jobType === 'openva' || !ensemble;

    if (needsSingleSelect && algorithms.length > 1) {
      // Switching to single-select: keep only first algorithm
      setAlgorithms([algorithms[0]]);
    }
  }, [jobType, ensemble]);

  // Validation for ensemble requirements
  useEffect(() => {
    const needsMultiSelect = (jobType === 'pipeline' || jobType === 'vacalibration') && ensemble;

    if (needsMultiSelect && algorithms.length < 2) {
      setValidationError('Ensemble calibration requires at least 2 algorithms');
    } else if (algorithms.length === 0) {
      setValidationError('Please select at least one algorithm');
    } else {
      setValidationError(null);
    }
  }, [ensemble, algorithms, jobType]);

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

    if (ensemble && algorithms.length < 2 && (jobType === 'pipeline' || jobType === 'vacalibration')) {
      setError('Ensemble calibration requires at least 2 algorithms');
      setLoading(false);
      return;
    }

    try {
      const result = await submitJob({
        file,
        jobType,
        algorithms,
        ageGroup,
        country,
        calibModelType,
        ensemble
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

    if (ensemble && algorithms.length < 2 && (jobType === 'pipeline' || jobType === 'vacalibration')) {
      setError('Ensemble calibration requires at least 2 algorithms');
      setLoading(false);
      return;
    }

    try {
      const result = await submitDemoJob({ jobType, algorithms, ageGroup, country, calibModelType, ensemble });
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
          <label>Job Type</label>
          <CustomSelect
            value={jobType}
            onChange={setJobType}
            options={[
              { value: 'pipeline', label: 'Full Pipeline (openVA + Calibration)' },
              { value: 'openva', label: 'openVA Only' },
              { value: 'vacalibration', label: 'Calibration Only' }
            ]}
          />
        </div>

        {/* Algorithm Selection - show for all job types */}
        <div className="form-group">
          <label>
            Algorithm{((jobType === 'pipeline' || jobType === 'vacalibration') && ensemble) ? 's' : ''}
            {(jobType === 'pipeline' || jobType === 'vacalibration') && ensemble && (
              <span className="required"> * Select at least 2 for ensemble</span>
            )}
          </label>

          {/* Ensemble checkbox - only for pipeline/vacalibration */}
          {(jobType === 'pipeline' || jobType === 'vacalibration') && (
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
          )}

          {/* File-based algorithm hint - show when file is uploaded for vacalibration */}
          {jobType === 'vacalibration' && file && (
            <div className="file-algorithm-hint">
              <small className="form-hint">
                ⓘ If your data already contains algorithm information, the algorithm selection below will be used to match the data format
              </small>
            </div>
          )}

          {/* Dynamic UI: Dropdown for single-select, Checkboxes for multi-select */}
          {(jobType === 'pipeline' || jobType === 'vacalibration') && ensemble ? (
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

        <div className="form-group">
          <label>Age Group</label>
          <CustomSelect
            value={ageGroup}
            onChange={setAgeGroup}
            options={[
              { value: 'neonate', label: 'Neonate (0-27 days)' },
              { value: 'child', label: 'Child (1-59 months)' }
            ]}
          />
        </div>

        {/* Country: needed for vacalibration and pipeline, not for openva */}
        {jobType !== 'openva' && (
          <div className="form-group">
            <label>Country</label>
            <CustomSelect
              value={country}
              onChange={setCountry}
              options={[
                { value: 'Mozambique', label: 'Mozambique' },
                { value: 'Bangladesh', label: 'Bangladesh' },
                { value: 'Ethiopia', label: 'Ethiopia' },
                { value: 'Kenya', label: 'Kenya' },
                { value: 'Mali', label: 'Mali' },
                { value: 'Sierra Leone', label: 'Sierra Leone' },
                { value: 'South Africa', label: 'South Africa' },
                { value: 'other', label: 'Other' }
              ]}
            />
          </div>
        )}

        {/* Vacalibration-specific parameters */}
        {(jobType === 'vacalibration' || jobType === 'pipeline') && (
          <div className="form-group">
            <label>Uncertainty Propagation</label>
            <CustomSelect
              value={calibModelType}
              onChange={setCalibModelType}
              options={[
                { value: 'Mmatprior', label: 'Prior (Full Bayesian)' },
                { value: 'Mmatfixed', label: 'Fixed (No Uncertainty)' }
              ]}
            />
            <small className="form-hint">
              Controls how uncertainty in misclassification estimates is handled
            </small>
          </div>
        )}

        <div className="form-group">
          <label>VA Data File (CSV)</label>
          <input
            type="file"
            accept=".csv"
            onChange={(e) => setFile(e.target.files[0])}
          />
          <small className="form-hint">
            {jobType === 'vacalibration'
              ? 'Required columns: ID, cause (with cause names)'
              : 'WHO 2016 VA questionnaire format (columns: i004a, i004b, ...)'}
          </small>
          <div className="sample-download">
            {jobType === 'vacalibration' ? (
              <div className="sample-links">
                <span>Sample CSV (neonate, 1190 records):</span>
                <a href={`${import.meta.env.BASE_URL}sample_interva_neonate.csv`} download>InterVA</a>
                <a href={`${import.meta.env.BASE_URL}sample_insilicova_neonate.csv`} download>InSilicoVA</a>
                <a href={`${import.meta.env.BASE_URL}sample_eava_neonate.csv`} download>EAVA</a>
              </div>
            ) : (
              <a
                href={`${import.meta.env.BASE_URL}${ageGroup === 'neonate' ? 'sample_openva_neonate.csv' : 'sample_openva_child.csv'}`}
                download
              >
                Download sample CSV ({ageGroup === 'neonate' ? 'neonate' : 'child'})
              </a>
            )}
          </div>
        </div>

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
          <button type="submit" disabled={loading || !file || activeJob}>
            {loading ? 'Submitting...' : activeJob ? 'Job Running...' : 'Submit Job'}
          </button>
          <button type="button" onClick={handleDemo} disabled={loading || activeJob}>
            {loading ? 'Running...' : activeJob ? 'Job Running...' : 'Run Demo'}
          </button>
        </div>
      </form>
    </div>
  );
}
