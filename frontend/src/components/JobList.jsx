import { useState, useEffect } from 'react';
import { listJobs, getJobLog } from '../api/client';
import ProgressIndicator from './ProgressIndicator';

const JOBS_PER_PAGE = 10;

export default function JobList({ onSelectJob, refreshTrigger }) {
  const [jobs, setJobs] = useState([]);
  const [loading, setLoading] = useState(true);
  const [jobLogs, setJobLogs] = useState({});
  const [currentPage, setCurrentPage] = useState(1);

  useEffect(() => {
    loadJobs();
  }, [refreshTrigger]);

  // Auto-refresh when jobs are running
  useEffect(() => {
    const hasRunningJobs = jobs.some(j => j.status === 'running' || j.status === 'pending');
    if (!hasRunningJobs) return;

    const interval = setInterval(() => {
      loadJobs();
      loadRunningJobLogs();
    }, 5000);

    return () => clearInterval(interval);
  }, [jobs]);

  const loadJobs = async () => {
    try {
      const result = await listJobs();
      const sortedJobs = (result.jobs || []).sort((a, b) =>
        new Date(b.created_at) - new Date(a.created_at)
      );
      setJobs(sortedJobs);

      // Load logs for running jobs
      const runningJobs = sortedJobs.filter(j => j.status === 'running' || j.status === 'pending');
      if (runningJobs.length > 0) {
        loadRunningJobLogs(runningJobs);
      }
    } catch (err) {
      console.error('Failed to load jobs:', err);
    } finally {
      setLoading(false);
    }
  };

  const loadRunningJobLogs = async (runningJobs) => {
    const jobsToLoad = runningJobs || jobs.filter(j => j.status === 'running' || j.status === 'pending');
    if (jobsToLoad.length === 0) return;

    try {
      const logPromises = jobsToLoad.map(async (job) => {
        const logData = await getJobLog(job.job_id);
        return { id: job.job_id, log: logData.log || [] };
      });

      const results = await Promise.all(logPromises);
      const newLogs = {};
      results.forEach(r => {
        newLogs[r.id] = r.log;
      });
      setJobLogs(prev => ({ ...prev, ...newLogs }));
    } catch (err) {
      console.error('Failed to load job logs:', err);
    }
  };

  const getStatusBadge = (job) => {
    const colors = {
      pending: '#f59e0b',
      running: '#3b82f6',
      completed: '#10b981',
      failed: '#ef4444'
    };
    const isRunning = job.status === 'running' || job.status === 'pending';

    return (
      <div className="status-with-progress">
        <span className="status-badge" style={{ backgroundColor: colors[job.status] || '#6b7280' }}>
          {job.status}
        </span>
        {isRunning && jobLogs[job.job_id] && (
          <ProgressIndicator logs={jobLogs[job.job_id]} compact={true} />
        )}
      </div>
    );
  };

  // Pagination
  const totalPages = Math.ceil(jobs.length / JOBS_PER_PAGE);
  const startIndex = (currentPage - 1) * JOBS_PER_PAGE;
  const paginatedJobs = jobs.slice(startIndex, startIndex + JOBS_PER_PAGE);

  // Reset to page 1 if current page exceeds total
  useEffect(() => {
    if (currentPage > totalPages && totalPages > 0) {
      setCurrentPage(1);
    }
  }, [jobs.length, currentPage, totalPages]);

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
          {paginatedJobs.map((job) => (
            <tr key={job.job_id} onClick={() => onSelectJob(job.job_id)}>
              <td className="job-id">{job.job_id.slice(0, 8)}...</td>
              <td>{job.type}</td>
              <td>{getStatusBadge(job)}</td>
              <td>{new Date(job.created_at).toLocaleString()}</td>
            </tr>
          ))}
        </tbody>
      </table>
      {totalPages > 1 && (
        <div className="pagination">
          <button
            onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
            disabled={currentPage === 1}
          >
            Prev
          </button>
          <span className="page-info">{currentPage} / {totalPages}</span>
          <button
            onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
            disabled={currentPage === totalPages}
          >
            Next
          </button>
        </div>
      )}
    </div>
  );
}
