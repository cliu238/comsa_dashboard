import { useState, useEffect } from 'react';
import { submitJob, submitDemoJob } from '../api/client';

export default function JobForm({ onJobSubmitted }) {
  const [jobType, setJobType] = useState('pipeline');
  const [algorithms, setAlgorithms] = useState(['InterVA']);  // Array instead of single value
  const [ageGroup, setAgeGroup] = useState('neonate');
  const [country, setCountry] = useState('Mozambique');
  const [file, setFile] = useState(null);
  const [calibModelType, setCalibModelType] = useState('Mmatprior');
  const [ensemble, setEnsemble] = useState(true);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [validationError, setValidationError] = useState(null);

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
          <select value={jobType} onChange={(e) => setJobType(e.target.value)}>
            <option value="pipeline">Full Pipeline (openVA + Calibration)</option>
            <option value="openva">openVA Only</option>
            <option value="vacalibration">Calibration Only</option>
          </select>
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
            <select
              value={algorithms[0] || 'InterVA'}
              onChange={(e) => handleAlgorithmSelect(e.target.value)}
              className="form-control"
            >
              <option value="InterVA">InterVA (fastest, ~30sec)</option>
              <option value="InSilicoVA">InSilicoVA (most accurate, ~2-3min)</option>
              <option value="EAVA">EAVA (deterministic, ~1min)</option>
            </select>
          )}

          {validationError && <small className="validation-error">{validationError}</small>}
        </div>

        <div className="form-group">
          <label>Age Group</label>
          <select value={ageGroup} onChange={(e) => setAgeGroup(e.target.value)}>
            <option value="neonate">Neonate (0-27 days)</option>
            <option value="child">Child (1-59 months)</option>
          </select>
        </div>

        {/* Country: needed for vacalibration and pipeline, not for openva */}
        {jobType !== 'openva' && (
          <div className="form-group">
            <label>Country</label>
            <select value={country} onChange={(e) => setCountry(e.target.value)}>
              <option value="Mozambique">Mozambique</option>
              <option value="Bangladesh">Bangladesh</option>
              <option value="Ethiopia">Ethiopia</option>
              <option value="Kenya">Kenya</option>
              <option value="Mali">Mali</option>
              <option value="Sierra Leone">Sierra Leone</option>
              <option value="South Africa">South Africa</option>
              <option value="other">Other</option>
            </select>
          </div>
        )}

        {/* Vacalibration-specific parameters */}
        {(jobType === 'vacalibration' || jobType === 'pipeline') && (
          <div className="form-group">
            <label>Uncertainty Propagation</label>
            <select
              value={calibModelType}
              onChange={(e) => setCalibModelType(e.target.value)}
            >
              <option value="Mmatprior">Prior (Full Bayesian)</option>
              <option value="Mmatfixed">Fixed (No Uncertainty)</option>
            </select>
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
              <a href={`${import.meta.env.BASE_URL}sample_vacalibration.csv`} download>
                Download sample CSV
              </a>
            ) : (
              <a
                href={`${import.meta.env.BASE_URL}${ageGroup === 'neonate' ? 'sample_openva_neonate.csv' : 'sample_openva.csv'}`}
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
            💡 No file? Click "Run Demo" to test with sample {ageGroup} data
            ({ageGroup === 'neonate' ? '200 neonatal VA records' : 'child VA records'})
          </small>
        </div>

        {error && <div className="error">{error}</div>}

        <div className="form-actions">
          <button type="submit" disabled={loading || !file}>
            {loading ? 'Submitting...' : 'Submit Job'}
          </button>
          <button type="button" onClick={handleDemo} disabled={loading}>
            {loading ? 'Running...' : 'Run Demo'}
          </button>
        </div>
      </form>
    </div>
  );
}
