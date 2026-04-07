// API base URL is set from .env.production for deployed builds
const API_BASE = import.meta.env.VITE_API_BASE_URL || 'http://localhost:8000';

// Recursively unbox single-element arrays and empty objects from R/plumber responses
export function unbox(obj) {
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

function getAuthHeaders() {
  const headers = {};
  if (typeof localStorage !== 'undefined') {
    const token = localStorage.getItem('token');
    if (token) {
      headers['Authorization'] = `Bearer ${token}`;
    }
  }
  return headers;
}

async function fetchJson(url, options = {}) {
  const headers = { ...getAuthHeaders(), ...options.headers };
  const res = await fetch(url, { ...options, headers });

  if (res.status === 401 && typeof localStorage !== 'undefined') {
    localStorage.removeItem('token');
    window.dispatchEvent(new Event('auth:logout'));
  }

  const data = await res.json();
  return unbox(data);
}

export async function submitJob({ uploads, jobType, algorithms, ageGroup, country, calibModelType, ensemble, nMCMC, nBurn, nThin }) {
  const formData = new FormData();

  // Multi-file: ensemble vacalibration sends per-algorithm file keys
  const hasFiles = uploads && uploads.some(u => u.file);
  if (hasFiles && ensemble && jobType === 'vacalibration') {
    uploads.forEach(({ algorithm, file }) => {
      if (file && algorithm) {
        formData.append(`file_${algorithm.toLowerCase()}`, file);
      }
    });
  } else if (hasFiles) {
    // Single file for non-ensemble or pipeline
    const firstFile = uploads.find(u => u.file)?.file;
    if (firstFile) formData.append('file', firstFile);
  }

  const params = new URLSearchParams({
    job_type: jobType,
    algorithm: Array.isArray(algorithms) ? JSON.stringify(algorithms) : algorithms,
    age_group: ageGroup,
    country,
    calib_model_type: calibModelType,
    ensemble: String(ensemble),
    n_mcmc: String(nMCMC),
    n_burn: String(nBurn),
    n_thin: String(nThin)
  });

  return fetchJson(`${API_BASE}/jobs?${params}`, {
    method: 'POST',
    body: hasFiles ? formData : undefined
  });
}

export async function submitDemoJob({ jobType, algorithms, ageGroup, country, calibModelType, ensemble, nMCMC, nBurn, nThin }) {
  const params = new URLSearchParams({
    job_type: jobType,
    algorithm: Array.isArray(algorithms) ? JSON.stringify(algorithms) : algorithms,
    age_group: ageGroup,
    country: country,
    calib_model_type: calibModelType,
    ensemble: String(ensemble),
    n_mcmc: String(nMCMC),
    n_burn: String(nBurn),
    n_thin: String(nThin)
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

export async function loginUser(email, password) {
  const res = await fetch(`${API_BASE}/auth/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Login failed');
  return unbox(data);
}

export async function registerUser({ email, password, name, organization }) {
  const res = await fetch(`${API_BASE}/auth/register`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ email, password, name, organization })
  });
  const data = await res.json();
  if (!res.ok) throw new Error(data.error || 'Registration failed');
  return unbox(data);
}

export async function fetchCurrentUser() {
  return fetchJson(`${API_BASE}/auth/me`);
}

export async function updateProfile({ name, organization }) {
  const res = await fetch(`${API_BASE}/auth/me`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...getAuthHeaders() },
    body: JSON.stringify({ name, organization })
  });
  const data = await res.json();
  return unbox(data);
}

export async function fetchAdminUsers() {
  return fetchJson(`${API_BASE}/admin/users`);
}

export async function updateAdminUser(userId, fields) {
  const res = await fetch(`${API_BASE}/admin/users/${userId}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json', ...getAuthHeaders() },
    body: JSON.stringify(fields)
  });
  const data = await res.json();
  return unbox(data);
}

export async function fetchAdminJobs() {
  return fetchJson(`${API_BASE}/admin/jobs`);
}
