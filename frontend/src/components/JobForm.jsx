import { useState } from 'react';
import { submitJob, submitDemoJob } from '../api/client';

export default function JobForm({ onJobSubmitted }) {
  const [jobType, setJobType] = useState('pipeline');
  const [algorithm, setAlgorithm] = useState('InterVA');
  const [ageGroup, setAgeGroup] = useState('neonate');
  const [country, setCountry] = useState('Mozambique');
  const [file, setFile] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const result = await submitJob({
        file,
        jobType,
        algorithm,
        ageGroup,
        country
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

    try {
      const result = await submitDemoJob({ jobType, ageGroup });
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

        <div className="form-group">
          <label>Algorithm</label>
          <select value={algorithm} onChange={(e) => setAlgorithm(e.target.value)}>
            <option value="InterVA">InterVA (faster)</option>
            <option value="InSilicoVA">InSilicoVA (more accurate)</option>
          </select>
        </div>

        <div className="form-group">
          <label>Age Group</label>
          <select value={ageGroup} onChange={(e) => setAgeGroup(e.target.value)}>
            <option value="neonate">Neonate (0-27 days)</option>
            <option value="child">Child (1-59 months)</option>
          </select>
        </div>

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

        <div className="form-group">
          <label>VA Data File (CSV)</label>
          <input
            type="file"
            accept=".csv"
            onChange={(e) => setFile(e.target.files[0])}
          />
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
