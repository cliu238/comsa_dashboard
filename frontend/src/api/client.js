// API base URL is set from .env.production for deployed builds
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

// Recursively unbox single-element arrays and empty objects from R/plumber responses
function unbox(obj) {
  if (obj === null || obj === undefined) return obj;
  if (Array.isArray(obj)) {
    if (obj.length === 1 && !Array.isArray(obj[0]) && typeof obj[0] !== 'object') {
      return obj[0];
    }
    return obj.map(unbox);
  }
  if (typeof obj === 'object') {
    // Convert empty objects {} to null (R's NULL serializes to {})
    if (Object.keys(obj).length === 0) {
      return null;
    }
    const result = {};
    for (const [key, value] of Object.entries(obj)) {
      result[key] = unbox(value);
    }
    return result;
  }
  return obj;
}

async function fetchJson(url, options) {
  const res = await fetch(url, options);
  const data = await res.json();
  return unbox(data);
}

export async function submitJob({ file, jobType, algorithms, ageGroup, country, calibModelType, ensemble }) {
  const formData = new FormData();
  if (file) formData.append('file', file);

  const params = new URLSearchParams({
    job_type: jobType,
    algorithm: Array.isArray(algorithms) ? JSON.stringify(algorithms) : algorithms,
    age_group: ageGroup,
    country,
    calib_model_type: calibModelType,
    ensemble: String(ensemble)
  });

  return fetchJson(`${API_BASE}/jobs?${params}`, {
    method: 'POST',
    body: file ? formData : undefined
  });
}

export async function submitDemoJob({ jobType, algorithms, ageGroup, country, calibModelType, ensemble }) {
  const params = new URLSearchParams({
    job_type: jobType,
    algorithm: Array.isArray(algorithms) ? JSON.stringify(algorithms) : algorithms,
    age_group: ageGroup,
    country: country,
    calib_model_type: calibModelType,
    ensemble: String(ensemble)
  });

  return fetchJson(`${API_BASE}/jobs/demo?${params}`, {
    method: 'POST'
  });
}

export async function getJobStatus(jobId) {
  return fetchJson(`${API_BASE}/jobs/${jobId}/status`);
}

export async function getJobLog(jobId) {
  return fetchJson(`${API_BASE}/jobs/${jobId}/log`);
}

export async function getJobResults(jobId) {
  return fetchJson(`${API_BASE}/jobs/${jobId}/results`);
}

export async function listJobs() {
  return fetchJson(`${API_BASE}/jobs`);
}

export function getDownloadUrl(jobId, filename) {
  return `${API_BASE}/jobs/${jobId}/download/${filename}`;
}
