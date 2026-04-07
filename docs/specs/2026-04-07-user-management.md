# Spec: User Management System

**Issue**: #60
**Date**: 2026-04-07
**Status**: Draft

## Problem

The COMSA Dashboard has no user isolation. All jobs, uploads, and results are globally visible and accessible by anyone. There is no authentication, no authorization, and no concept of ownership. This prevents multi-user deployment.

### Current State

| Layer | State |
|-------|-------|
| Backend (R plumber) | No auth filter. All endpoints open. CORS allows `*`. |
| Frontend (React) | No login/register. No routing library. Tab-based navigation. |
| Database (PostgreSQL) | 3 tables: `jobs`, `job_logs`, `job_files`. No user concept. |
| API client | Native `fetch`, no auth headers. Base URL from `VITE_API_BASE_URL`. |

## Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Auth method | JWT (stateless) | Fits REST API; no session table needed; plumber filter validates per-request |
| Password hashing | `sodium::password_store()` (Argon2id) | `libsodium` already in Dockerfile; Argon2id is stronger than bcrypt |
| Database | PostgreSQL (existing) | Already running for job tracking |
| Frontend routing | `react-router-dom` | Needed for login/register/admin pages; current tab system maps to routes |
| Team/org sharing | Schema-ready, not implemented | `organization` as free text now; add FK later |
| Token expiry | 24 hours | Simple; no refresh token flow initially |

---

## Database Schema

### Migration: `backend/migrations/002_users.sql`

```sql
-- User management tables
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    name VARCHAR(255),
    organization VARCHAR(255),
    role VARCHAR(50) NOT NULL DEFAULT 'user',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT valid_role CHECK (role IN ('user', 'admin'))
);

CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- Link jobs to users
ALTER TABLE jobs ADD COLUMN user_id UUID REFERENCES users(id);
CREATE INDEX idx_jobs_user_id ON jobs(user_id);

COMMENT ON TABLE users IS 'Platform users with authentication credentials';
COMMENT ON COLUMN users.role IS 'User role: user (default) or admin';
COMMENT ON COLUMN jobs.user_id IS 'Owner of the job. NULL for legacy/pre-auth jobs';
```

### Seed admin user (run after migration)

```sql
-- Password set via backend endpoint or manual hash
INSERT INTO users (email, password_hash, name, role)
VALUES ('admin@comsa.org', '<hashed_password>', 'Admin', 'admin');
```

---

## Backend Auth Module

### New files

```
backend/
├── auth/
│   ├── passwords.R    # hash_password(), verify_password()
│   ├── tokens.R       # create_token(), verify_token()
│   └── middleware.R    # plumber auth filter, require_admin()
```

### `backend/auth/passwords.R`

```r
library(sodium)

hash_password <- function(password) {
  sodium::password_store(charToRaw(password))
}

verify_password <- function(password, hash) {
  sodium::password_verify(hash, charToRaw(password))
}
```

### `backend/auth/tokens.R`

```r
library(jose)
library(jsonlite)

# Secret loaded from environment
.jwt_secret <- NULL

get_jwt_secret <- function() {
  if (is.null(.jwt_secret)) {
    secret <- Sys.getenv("JWT_SECRET", "")
    if (nchar(secret) == 0) stop("JWT_SECRET environment variable not set")
    .jwt_secret <<- charToRaw(secret)
  }
  .jwt_secret
}

create_token <- function(user_id, email, role) {
  now <- as.numeric(Sys.time())
  payload <- jwt_claim(
    sub = user_id,
    email = email,
    role = role,
    iat = now,
    exp = now + 86400  # 24 hours
  )
  jwt_encode_hmac(payload, secret = get_jwt_secret())
}

verify_token <- function(token) {
  tryCatch({
    jwt_decode_hmac(token, secret = get_jwt_secret())
  }, error = function(e) {
    NULL
  })
}
```

### `backend/auth/middleware.R` — Plumber auth filter

```r
source("auth/tokens.R")

# Endpoints that don't require authentication
PUBLIC_ENDPOINTS <- c(
  "/health",
  "/auth/login",
  "/auth/register"
)

#' Auth filter — add to plumber.R after CORS filter
#' Extracts JWT from Authorization header, attaches user to req
auth_filter <- function(req, res) {
  # Skip auth for public endpoints
  path <- req$PATH_INFO
  if (path %in% PUBLIC_ENDPOINTS || grepl("^/auth/", path)) {
    return(plumber::forward())
  }

  # Extract token from Authorization: Bearer <token>
  auth_header <- req$HTTP_AUTHORIZATION
  if (is.null(auth_header) || !grepl("^Bearer ", auth_header)) {
    res$status <- 401
    return(list(error = "Missing or invalid Authorization header"))
  }

  token <- sub("^Bearer ", "", auth_header)
  claims <- verify_token(token)

  if (is.null(claims)) {
    res$status <- 401
    return(list(error = "Invalid or expired token"))
  }

  # Attach user info to request
  req$user <- list(
    id = claims$sub,
    email = claims$email,
    role = claims$role
  )

  plumber::forward()
}

# Helper: check admin role
require_admin <- function(req, res) {
  if (is.null(req$user) || req$user$role != "admin") {
    res$status <- 403
    return(list(error = "Admin access required"))
  }
  TRUE
}
```

### Integration in `plumber.R`

Add after existing CORS filter:

```r
source("auth/middleware.R")

#* Authenticate requests
#* @filter auth
auth_filter
```

---

## API Endpoints

### Auth Endpoints (new)

#### `POST /auth/register`

```
Request:
{
  "email": "user@example.com",
  "password": "securepass123",
  "name": "Jane Doe",
  "organization": "JHU"
}

Response 201:
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "Jane Doe",
  "organization": "JHU",
  "role": "user"
}

Response 409:
{ "error": "Email already registered" }
```

#### `POST /auth/login`

```
Request:
{
  "email": "user@example.com",
  "password": "securepass123"
}

Response 200:
{
  "token": "eyJhbGciOi...",
  "user": {
    "id": "uuid",
    "email": "user@example.com",
    "name": "Jane Doe",
    "role": "user"
  }
}

Response 401:
{ "error": "Invalid email or password" }
```

#### `GET /auth/me`

```
Headers: Authorization: Bearer <token>

Response 200:
{
  "id": "uuid",
  "email": "user@example.com",
  "name": "Jane Doe",
  "organization": "JHU",
  "role": "user",
  "created_at": "2026-04-07T..."
}
```

#### `PUT /auth/me`

```
Headers: Authorization: Bearer <token>

Request:
{
  "name": "Jane Smith",
  "organization": "WHO"
}

Response 200:
{ "id": "uuid", "email": "...", "name": "Jane Smith", "organization": "WHO", ... }
```

### Modified Job Endpoints

#### `POST /jobs` — add `user_id` from `req$user$id`

No request change. Backend reads `req$user$id` and stores in `jobs.user_id`.

#### `GET /jobs` — filter by user

```
-- Current query:
SELECT * FROM jobs ORDER BY created_at DESC

-- New query:
SELECT * FROM jobs WHERE user_id = $1 ORDER BY created_at DESC
```

Admins can pass `?all=true` to see all jobs.

#### `GET /jobs/<id>/status`, `GET /jobs/<id>/results`, etc.

Add ownership check:

```r
job <- load_job(job_id)
if (job$user_id != req$user$id && req$user$role != "admin") {
  res$status <- 403
  return(list(error = "Access denied"))
}
```

### Admin Endpoints (new)

#### `GET /admin/users`

```
Headers: Authorization: Bearer <admin_token>

Response 200:
{
  "users": [
    {
      "id": "uuid",
      "email": "user@example.com",
      "name": "Jane Doe",
      "organization": "JHU",
      "role": "user",
      "is_active": true,
      "created_at": "...",
      "job_count": 12
    }
  ]
}
```

#### `PUT /admin/users/<id>`

```
Request:
{
  "is_active": false,
  "role": "admin"
}

Response 200:
{ "id": "uuid", "email": "...", "is_active": false, "role": "admin", ... }
```

#### `GET /admin/jobs`

Same as `GET /jobs` but returns all jobs regardless of ownership. Includes `user_email` in response.

---

## Frontend Changes

### New dependency

```bash
npm install react-router-dom
```

### Route structure

```
/              → Dashboard (JobForm + JobList, protected)
/login         → LoginPage (public)
/register      → RegisterPage (public)
/jobs/:id      → JobDetail (protected)
/demos         → DemoGallery (protected)
/admin         → AdminDashboard (protected, admin only)
/admin/users   → AdminUsers (protected, admin only)
```

### Auth context — `frontend/src/auth/AuthContext.jsx`

```jsx
const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [token, setToken] = useState(localStorage.getItem('token'));

  // On mount: validate stored token via GET /auth/me
  // login(email, password): POST /auth/login, store token
  // logout(): clear token + user
  // register(data): POST /auth/register

  return (
    <AuthContext.Provider value={{ user, token, login, logout, register }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
```

### API client changes — `frontend/src/api/client.js`

Add auth header to all requests:

```js
function getHeaders() {
  const headers = { 'Content-Type': 'application/json' };
  const token = localStorage.getItem('token');
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  return headers;
}
```

Handle 401 responses globally (redirect to login).

### Protected route wrapper

```jsx
function ProtectedRoute({ children, adminOnly = false }) {
  const { user } = useAuth();
  if (!user) return <Navigate to="/login" />;
  if (adminOnly && user.role !== 'admin') return <Navigate to="/" />;
  return children;
}
```

### New pages

| Page | File | Description |
|------|------|-------------|
| LoginPage | `src/pages/LoginPage.jsx` | Email + password form, link to register |
| RegisterPage | `src/pages/RegisterPage.jsx` | Email, password, name, organization form |
| AdminDashboard | `src/pages/AdminDashboard.jsx` | User list table, job overview, enable/disable users |

---

## Migration Strategy

### Grace period approach

To avoid a big-bang cutover, deploy auth in stages:

1. **Phase 1-2 (backend)**: Auth filter deployed but with a grace period — if no `Authorization` header is present, allow the request through with `req$user = NULL`. Jobs created without auth get `user_id = NULL`.

2. **Phase 3-4 (frontend)**: Ship login/register UI. New jobs get `user_id` attached.

3. **Phase 5 (enforce)**: Remove grace period. All requests require auth. Legacy jobs (`user_id = NULL`) visible only in admin dashboard.

### Legacy job handling

```sql
-- Option A: assign to admin user
UPDATE jobs SET user_id = (SELECT id FROM users WHERE role = 'admin' LIMIT 1)
WHERE user_id IS NULL;

-- Option B: leave NULL, show in admin dashboard only
-- (simpler, recommended)
```

---

## Phased Rollout

### Phase 1: Database + Auth Module
- `002_users.sql` migration
- `backend/auth/passwords.R`, `tokens.R`, `middleware.R`
- Auth filter in plumber.R (grace period mode)
- Seed admin user
- **Env var**: add `JWT_SECRET` to `.env`, k8s secrets
- **Deliverable**: backend accepts JWT but doesn't require it

### Phase 2: Auth API Endpoints
- `POST /auth/register`, `POST /auth/login`
- `GET /auth/me`, `PUT /auth/me`
- **Deliverable**: users can register and get tokens via API

### Phase 3: Job Isolation
- `save_job()` includes `user_id`
- `GET /jobs` filters by `user_id`
- Ownership check on job detail/results/download endpoints
- Background worker passes `user_id` in job metadata
- **Deliverable**: new jobs are scoped to users

### Phase 4: Frontend Auth
- Add `react-router-dom`
- Refactor App.jsx from tabs to routes
- Auth context + protected routes
- Login + Register pages
- API client auth headers + 401 handling
- **Deliverable**: full auth flow in the UI

### Phase 5: Admin Dashboard + Enforcement
- Admin endpoints: `GET /admin/users`, `PUT /admin/users/:id`, `GET /admin/jobs`
- Admin page in frontend
- Remove auth grace period (require JWT on all protected endpoints)
- **Deliverable**: admin can manage users; anonymous access disabled

---

## Security Considerations

| Concern | Mitigation |
|---------|------------|
| Password storage | Argon2id via `sodium::password_store()` — memory-hard, GPU-resistant |
| Token signing | HMAC-SHA256 via `jose` package; secret from `JWT_SECRET` env var |
| Token expiry | 24h; user must re-login after expiry |
| Token in transit | HTTPS required in production (k8s ingress handles TLS) |
| Token storage (frontend) | `localStorage` — acceptable for 24h tokens; HttpOnly cookie is an option for later hardening |
| CORS | Tighten from `*` to specific frontend origin after Phase 4 |
| Password requirements | Minimum 8 characters; enforced on both frontend and backend |
| Account enumeration | Login returns same error for wrong email vs wrong password |
| Disabled accounts | Auth filter checks `is_active` before granting access |
| SQL injection | Parameterized queries (existing pattern with `$1`, `$2` placeholders) |

---

## New Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `JWT_SECRET` | Yes | — | HMAC secret for signing JWTs. Min 32 characters. |

Add to: `.env`, `.env.local`, k8s `comsa-db-credentials` secret.

---

## Files Summary

### New files
```
backend/auth/passwords.R
backend/auth/tokens.R
backend/auth/middleware.R
backend/migrations/002_users.sql
frontend/src/auth/AuthContext.jsx
frontend/src/pages/LoginPage.jsx
frontend/src/pages/RegisterPage.jsx
frontend/src/pages/AdminDashboard.jsx
frontend/src/components/ProtectedRoute.jsx
```

### Modified files
```
backend/plumber.R          — add auth filter, auth endpoints, admin endpoints
backend/db/connection.R    — add user CRUD functions (save_user, load_user, etc.)
backend/jobs/processor.R   — pass user_id to job
frontend/src/App.jsx       — replace tabs with react-router
frontend/src/api/client.js — add auth headers, 401 handling
frontend/package.json      — add react-router-dom
```
