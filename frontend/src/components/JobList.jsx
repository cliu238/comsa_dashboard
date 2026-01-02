import { useState, useEffect } from 'react';
import { listJobs } from '../api/client';

export default function JobList({ onSelectJob, refreshTrigger }) {
  const [jobs, setJobs] = useState([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    loadJobs();
  }, [refreshTrigger]);

  const loadJobs = async () => {
    try {
      const result = await listJobs();
      const sortedJobs = (result.jobs || []).sort((a, b) =>
        new Date(b.created_at) - new Date(a.created_at)
      );
      setJobs(sortedJobs);
    } catch (err) {
      console.error('Failed to load jobs:', err);
    } finally {
      setLoading(false);
    }
  };

  const getStatusBadge = (status) => {
    const colors = {
      pending: '#f59e0b',
      running: '#3b82f6',
      completed: '#10b981',
      failed: '#ef4444'
    };
    return (
      <span className="status-badge" style={{ backgroundColor: colors[status] || '#6b7280' }}>
        {status}
      </span>
    );
  };

  if (loading) return <div className="loading">Loading jobs...</div>;

  if (jobs.length === 0) {
    return (
      <div className="job-list empty">
        <p>No jobs yet. Submit a job or run a demo to get started.</p>
      </div>
    );
  }

  return (
    <div className="job-list">
      <h3>Recent Jobs</h3>
      <table>
        <thead>
          <tr>
            <th>Job ID</th>
            <th>Type</th>
            <th>Status</th>
            <th>Created</th>
          </tr>
        </thead>
        <tbody>
          {jobs.map((job) => (
            <tr key={job.job_id} onClick={() => onSelectJob(job.job_id)}>
              <td className="job-id">{job.job_id.slice(0, 8)}...</td>
              <td>{job.type}</td>
              <td>{getStatusBadge(job.status)}</td>
              <td>{new Date(job.created_at).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
