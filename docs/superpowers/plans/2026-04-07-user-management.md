# User Management System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add JWT-based user authentication, per-user job isolation, and an admin dashboard to the COMSA Dashboard.

**Architecture:** R plumber backend gets an auth filter (JWT via `jose` + password hashing via `sodium`), user CRUD in PostgreSQL, and ownership checks on job endpoints. React frontend gets `react-router-dom` for page routing, an auth context for login state, and protected route wrappers. Grace period migration allows backend and frontend to ship independently.

**Tech Stack:** R (`jose`, `sodium`, `plumber`, `RPostgres`), React 19, `react-router-dom`, PostgreSQL, JWT (HMAC-SHA256)

**Spec:** `docs/specs/2026-04-07-user-management.md`

---

## File Structure

### New files
```
backend/auth/passwords.R       — hash_password(), verify_password() using sodium
backend/auth/tokens.R          — create_token(), verify_token() using jose
backend/auth/middleware.R       — plumber auth filter, require_admin() helper
backend/auth/users.R            — user CRUD: save_user(), find_user_by_email(), find_user_by_id(), list_users(), update_user()
backend/migrations/002_users.sql — users table + jobs.user_id column

frontend/src/auth/AuthContext.jsx   — React context: user state, login/logout/register
frontend/src/components/ProtectedRoute.jsx — Route guard (redirects to /login)
frontend/src/pages/LoginPage.jsx    — Login form
frontend/src/pages/RegisterPage.jsx — Registration form
frontend/src/pages/AdminPage.jsx    — Admin user management table
```

### Modified files
```
backend/plumber.R              — add auth filter, auth endpoints (/auth/*), admin endpoints (/admin/*), ownership checks on job endpoints
backend/Dockerfile             — add jose R package install
frontend/src/main.jsx          — wrap App in BrowserRouter + AuthProvider
frontend/src/App.jsx           — replace tab navigation with react-router Routes
frontend/src/api/client.js     — add Authorization header, 401 handling
frontend/package.json          — add react-router-dom dependency
```

---

## Task 1: Database Migration

**Files:**
- Create: `backend/migrations/002_users.sql`

- [ ] **Step 1: Write the migration SQL**

```sql
-- 002_users.sql: User management and job ownership

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

ALTER TABLE jobs ADD COLUMN user_id UUID REFERENCES users(id);
CREATE INDEX idx_jobs_user_id ON jobs(user_id);

COMMENT ON TABLE users IS 'Platform users with authentication credentials';
COMMENT ON COLUMN users.role IS 'User role: user (default) or admin';
COMMENT ON COLUMN jobs.user_id IS 'Owner of the job. NULL for legacy/pre-auth jobs';
```

- [ ] **Step 2: Run the migration against local database**

Requires SSH tunnel: `ssh -L 5433:172.23.53.49:5432 -N cliu238@dslogin01.pha.jhu.edu`

```bash
cd backend
psql -h localhost -p 5433 -U eric -d comsa_dashboard -f migrations/002_users.sql
```

Expected: tables created, no errors.

- [ ] **Step 3: Verify schema**

```bash
psql -h localhost -p 5433 -U eric -d comsa_dashboard -c "\d users"
psql -h localhost -p 5433 -U eric -d comsa_dashboard -c "\d jobs" | grep user_id
```

Expected: `users` table with all columns. `jobs` table shows `user_id` column of type `uuid`.

- [ ] **Step 4: Commit**

```bash
git add backend/migrations/002_users.sql
git commit -m "feat(db): add users table and jobs.user_id column (#60)"
```

---

## Task 2: Password Hashing Module

**Files:**
- Create: `backend/auth/passwords.R`

- [ ] **Step 1: Write the failing test**

Create a quick inline test at the bottom of the file (will be removed after verification):

```bash
cd backend
Rscript -e '
library(sodium)
source("auth/passwords.R")

# Test: hash and verify correct password
hash <- hash_password("testpass123")
stopifnot(verify_password("testpass123", hash))

# Test: reject wrong password
stopifnot(!verify_password("wrongpass", hash))

# Test: different hashes for same password (salt)
hash2 <- hash_password("testpass123")
stopifnot(hash != hash2)

cat("All password tests passed\n")
'
```

Expected: fails because `auth/passwords.R` doesn't exist yet.

- [ ] **Step 2: Create passwords.R**

```r
# backend/auth/passwords.R
# Password hashing using sodium (Argon2id)

library(sodium)

hash_password <- function(password) {
  sodium::password_store(charToRaw(password))
}

verify_password <- function(password, hash) {
  tryCatch(
    sodium::password_verify(hash, charToRaw(password)),
    error = function(e) FALSE
  )
}
```

- [ ] **Step 3: Run the test**

```bash
cd backend
Rscript -e '
library(sodium)
source("auth/passwords.R")
hash <- hash_password("testpass123")
stopifnot(verify_password("testpass123", hash))
stopifnot(!verify_password("wrongpass", hash))
hash2 <- hash_password("testpass123")
stopifnot(hash != hash2)
cat("All password tests passed\n")
'
```

Expected: `All password tests passed`

- [ ] **Step 4: Commit**

```bash
git add backend/auth/passwords.R
git commit -m "feat(auth): add Argon2id password hashing module (#60)"
```

---

## Task 3: JWT Token Module

**Files:**
- Create: `backend/auth/tokens.R`
- Modify: `backend/Dockerfile` (add `jose` package)

- [ ] **Step 1: Install jose locally**

```bash
R -e "install.packages('jose', repos='https://cloud.r-project.org')"
```

- [ ] **Step 2: Write the failing test**

```bash
cd backend
JWT_SECRET=test-secret-key-min-32-characters-long Rscript -e '
library(jose)
source("auth/tokens.R")

# Test: create and verify token
token <- create_token("user-123", "test@example.com", "user")
stopifnot(is.character(token))
stopifnot(nchar(token) > 0)

claims <- verify_token(token)
stopifnot(!is.null(claims))
stopifnot(claims$sub == "user-123")
stopifnot(claims$email == "test@example.com")
stopifnot(claims$role == "user")

# Test: reject tampered token
bad_claims <- verify_token(paste0(token, "tampered"))
stopifnot(is.null(bad_claims))

# Test: missing secret fails
.jwt_secret <<- NULL
tryCatch({
  Sys.setenv(JWT_SECRET = "")
  get_jwt_secret()
  stop("Should have failed")
}, error = function(e) {
  stopifnot(grepl("JWT_SECRET", e$message))
})

cat("All token tests passed\n")
'
```

Expected: fails because `auth/tokens.R` doesn't exist yet.

- [ ] **Step 3: Create tokens.R**

```r
# backend/auth/tokens.R
# JWT token creation and verification using jose (HMAC-SHA256)

library(jose)

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
  tryCatch(
    jwt_decode_hmac(token, secret = get_jwt_secret()),
    error = function(e) NULL
  )
}
```

- [ ] **Step 4: Run the test**

```bash
cd backend
JWT_SECRET=test-secret-key-min-32-characters-long Rscript -e '
library(jose)
source("auth/tokens.R")
token <- create_token("user-123", "test@example.com", "user")
stopifnot(is.character(token) && nchar(token) > 0)
claims <- verify_token(token)
stopifnot(!is.null(claims))
stopifnot(claims$sub == "user-123")
stopifnot(claims$email == "test@example.com")
stopifnot(claims$role == "user")
bad_claims <- verify_token(paste0(token, "tampered"))
stopifnot(is.null(bad_claims))
cat("All token tests passed\n")
'
```

Expected: `All token tests passed`

- [ ] **Step 5: Add jose to Dockerfile**

In `backend/Dockerfile`, modify the R package install line (line 30) to include `jose`:

```dockerfile
RUN R -e "options(warn=2); install.packages(c('plumber', 'jsonlite', 'uuid', 'future', 'RPostgres', 'pool', 'jose'), repos='https://cloud.r-project.org')"
```

- [ ] **Step 6: Add JWT_SECRET to .env**

Add to `.env` (or `.env.local`):

```
JWT_SECRET=change-me-to-a-real-secret-at-least-32-chars
```

- [ ] **Step 7: Commit**

```bash
git add backend/auth/tokens.R backend/Dockerfile
git commit -m "feat(auth): add JWT token module and jose dependency (#60)"
```

---

## Task 4: User CRUD Functions

**Files:**
- Create: `backend/auth/users.R`

- [ ] **Step 1: Write users.R**

```r
# backend/auth/users.R
# User database operations

source("auth/passwords.R")

save_user <- function(email, password, name = NULL, organization = NULL, role = "user") {
  conn <- get_db_connection()
  hash <- hash_password(password)

  query <- "
    INSERT INTO users (email, password_hash, name, organization, role)
    VALUES ($1, $2, $3, $4, $5)
    RETURNING id, email, name, organization, role, is_active, created_at
  "

  result <- dbGetQuery(conn, query, params = list(email, hash, name, organization, role))
  as.list(result[1, ])
}

find_user_by_email <- function(email) {
  conn <- get_db_connection()

  query <- "SELECT * FROM users WHERE email = $1"
  result <- dbGetQuery(conn, query, params = list(email))

  if (nrow(result) == 0) return(NULL)
  as.list(result[1, ])
}

find_user_by_id <- function(user_id) {
  conn <- get_db_connection()

  query <- "SELECT id, email, name, organization, role, is_active, created_at, updated_at FROM users WHERE id = $1::uuid"
  result <- dbGetQuery(conn, query, params = list(user_id))

  if (nrow(result) == 0) return(NULL)
  as.list(result[1, ])
}

list_users <- function() {
  conn <- get_db_connection()

  query <- "
    SELECT u.id, u.email, u.name, u.organization, u.role, u.is_active, u.created_at,
           COUNT(j.id) as job_count
    FROM users u
    LEFT JOIN jobs j ON j.user_id = u.id
    GROUP BY u.id
    ORDER BY u.created_at DESC
  "

  dbGetQuery(conn, query)
}

update_user <- function(user_id, fields) {
  conn <- get_db_connection()
  allowed <- c("name", "organization", "role", "is_active")
  fields <- fields[names(fields) %in% allowed]

  if (length(fields) == 0) return(find_user_by_id(user_id))

  set_clauses <- paste0(names(fields), " = $", seq_along(fields) + 1)
  set_clauses <- c(set_clauses, paste0("updated_at = NOW()"))

  query <- sprintf(
    "UPDATE users SET %s WHERE id = $1::uuid RETURNING id, email, name, organization, role, is_active, created_at, updated_at",
    paste(set_clauses, collapse = ", ")
  )

  params <- c(list(user_id), unname(fields))
  result <- dbGetQuery(conn, query, params = params)

  if (nrow(result) == 0) return(NULL)
  as.list(result[1, ])
}
```

- [ ] **Step 2: Verify it loads without error**

```bash
cd backend
Rscript -e '
source("db/connection.R")
source("auth/users.R")
cat("users.R loaded successfully\n")
'
```

Expected: `users.R loaded successfully` (may show DB connection messages)

- [ ] **Step 3: Commit**

```bash
git add backend/auth/users.R
git commit -m "feat(auth): add user CRUD database functions (#60)"
```

---

## Task 5: Auth Middleware (Grace Period)

**Files:**
- Create: `backend/auth/middleware.R`

- [ ] **Step 1: Write middleware.R**

```r
# backend/auth/middleware.R
# Plumber authentication filter with grace period support

source("auth/tokens.R")

# Grace period: if TRUE, allow unauthenticated requests through (req$user = NULL)
# Set to FALSE after frontend auth ships (Phase 5)
AUTH_GRACE_PERIOD <- TRUE

PUBLIC_ENDPOINTS <- c(
  "/health",
  "/auth/login",
  "/auth/register"
)

auth_filter <- function(req, res) {
  path <- req$PATH_INFO

  # Always skip auth for public endpoints
  if (path %in% PUBLIC_ENDPOINTS) {
    return(plumber::forward())
  }

  auth_header <- req$HTTP_AUTHORIZATION

  # No auth header present
  if (is.null(auth_header) || !grepl("^Bearer ", auth_header)) {
    if (AUTH_GRACE_PERIOD) {
      req$user <- NULL
      return(plumber::forward())
    }
    res$status <- 401
    return(list(error = "Missing or invalid Authorization header"))
  }

  # Validate token
  token <- sub("^Bearer ", "", auth_header)
  claims <- verify_token(token)

  if (is.null(claims)) {
    res$status <- 401
    return(list(error = "Invalid or expired token"))
  }

  # Check if user is active (requires DB lookup)
  user <- find_user_by_id(claims$sub)
  if (is.null(user) || !user$is_active) {
    res$status <- 401
    return(list(error = "Account disabled or not found"))
  }

  req$user <- list(
    id = claims$sub,
    email = claims$email,
    role = claims$role
  )

  plumber::forward()
}

require_admin <- function(req, res) {
  if (is.null(req$user) || req$user$role != "admin") {
    res$status <- 403
    return(list(error = "Admin access required"))
  }
  TRUE
}

# Helper: check if current user owns the job or is admin
check_job_access <- function(job, req, res) {
  if (is.null(req$user)) return(TRUE)  # Grace period: no user = allow
  if (req$user$role == "admin") return(TRUE)
  if (is.null(job$user_id)) return(TRUE)  # Legacy job with no owner
  if (job$user_id == req$user$id) return(TRUE)
  res$status <- 403
  return(list(error = "Access denied"))
}
```

- [ ] **Step 2: Commit**

```bash
git add backend/auth/middleware.R
git commit -m "feat(auth): add plumber auth filter with grace period (#60)"
```

---

## Task 6: Integrate Auth into plumber.R

**Files:**
- Modify: `backend/plumber.R`

- [ ] **Step 1: Add auth sources and filter**

At the top of `backend/plumber.R`, after `source("jobs/processor.R")` (line 12), add:

```r
# Source auth modules
source("auth/users.R")
source("auth/middleware.R")
```

After the CORS filter block (after line 69), add the auth filter:

```r
#* Authenticate requests via JWT
#* @filter auth
auth_filter
```

- [ ] **Step 2: Add auth endpoints**

After the health check endpoint (after line 75), add:

```r
#* Register a new user
#* @post /auth/register
function(req, res) {
  body <- jsonlite::fromJSON(req$postBody)

  email <- body$email
  password <- body$password
  name <- body$name
  organization <- body$organization

  if (is.null(email) || is.null(password)) {
    res$status <- 400
    return(list(error = "Email and password are required"))
  }

  if (nchar(password) < 8) {
    res$status <- 400
    return(list(error = "Password must be at least 8 characters"))
  }

  existing <- find_user_by_email(email)
  if (!is.null(existing)) {
    res$status <- 409
    return(list(error = "Email already registered"))
  }

  user <- tryCatch(
    save_user(email, password, name, organization),
    error = function(e) {
      res$status <- 500
      return(list(error = "Failed to create user"))
    }
  )

  res$status <- 201
  list(
    id = user$id,
    email = user$email,
    name = user$name,
    organization = user$organization,
    role = user$role
  )
}

#* Login and receive JWT token
#* @post /auth/login
function(req, res) {
  body <- jsonlite::fromJSON(req$postBody)

  email <- body$email
  password <- body$password

  if (is.null(email) || is.null(password)) {
    res$status <- 400
    return(list(error = "Email and password are required"))
  }

  user <- find_user_by_email(email)
  if (is.null(user) || !verify_password(password, user$password_hash)) {
    res$status <- 401
    return(list(error = "Invalid email or password"))
  }

  if (!user$is_active) {
    res$status <- 401
    return(list(error = "Account is disabled"))
  }

  token <- create_token(user$id, user$email, user$role)

  list(
    token = token,
    user = list(
      id = user$id,
      email = user$email,
      name = user$name,
      role = user$role
    )
  )
}

#* Get current user profile
#* @get /auth/me
function(req, res) {
  if (is.null(req$user)) {
    res$status <- 401
    return(list(error = "Not authenticated"))
  }

  user <- find_user_by_id(req$user$id)
  if (is.null(user)) {
    res$status <- 404
    return(list(error = "User not found"))
  }

  list(
    id = user$id,
    email = user$email,
    name = user$name,
    organization = user$organization,
    role = user$role,
    created_at = as.character(user$created_at)
  )
}

#* Update current user profile
#* @put /auth/me
function(req, res) {
  if (is.null(req$user)) {
    res$status <- 401
    return(list(error = "Not authenticated"))
  }

  body <- jsonlite::fromJSON(req$postBody)
  fields <- list()
  if (!is.null(body$name)) fields$name <- body$name
  if (!is.null(body$organization)) fields$organization <- body$organization

  user <- update_user(req$user$id, fields)
  list(
    id = user$id,
    email = user$email,
    name = user$name,
    organization = user$organization,
    role = user$role
  )
}
```

- [ ] **Step 3: Add admin endpoints**

At the end of `backend/plumber.R`, before the closing, add:

```r
#* List all users (admin only)
#* @get /admin/users
function(req, res) {
  admin_check <- require_admin(req, res)
  if (is.list(admin_check)) return(admin_check)

  users_df <- list_users()
  list(users = lapply(seq_len(nrow(users_df)), function(i) as.list(users_df[i, ])))
}

#* Update a user (admin only)
#* @param user_id:str User ID
#* @put /admin/users/<user_id>
function(user_id, req, res) {
  admin_check <- require_admin(req, res)
  if (is.list(admin_check)) return(admin_check)

  body <- jsonlite::fromJSON(req$postBody)
  fields <- list()
  if (!is.null(body$is_active)) fields$is_active <- as.logical(body$is_active)
  if (!is.null(body$role)) fields$role <- body$role

  user <- update_user(user_id, fields)
  if (is.null(user)) {
    res$status <- 404
    return(list(error = "User not found"))
  }

  list(
    id = user$id,
    email = user$email,
    name = user$name,
    organization = user$organization,
    role = user$role,
    is_active = user$is_active
  )
}

#* List all jobs across users (admin only)
#* @get /admin/jobs
function(req, res) {
  admin_check <- require_admin(req, res)
  if (is.list(admin_check)) return(admin_check)

  conn <- get_db_connection()
  query <- "
    SELECT j.id as job_id, j.type, j.status, j.created_at, j.user_id,
           u.email as user_email
    FROM jobs j
    LEFT JOIN users u ON j.user_id = u.id
    ORDER BY j.created_at DESC
  "
  result <- dbGetQuery(conn, query)
  list(jobs = lapply(seq_len(nrow(result)), function(i) as.list(result[i, ])))
}
```

- [ ] **Step 4: Add user_id to job submission**

In `POST /jobs` endpoint (around line 177 where the job list is created), add `user_id`:

```r
  job <- list(
    id = job_id,
    type = job_type,
    status = "pending",
    algorithm = algorithms,
    age_group = age_group,
    country = country,
    calib_model_type = calib_model_type,
    ensemble = ensemble_bool,
    n_mcmc = as.integer(n_mcmc),
    n_burn = as.integer(n_burn),
    n_thin = as.integer(n_thin),
    created_at = format(Sys.time()),
    started_at = NULL,
    completed_at = NULL,
    error = NULL,
    result = NULL,
    log = character(),
    user_id = if (!is.null(req$user)) req$user$id else NULL
  )
```

Do the same for `POST /jobs/demo` (around line 415) and `POST /demos/launch` (around line 488) — add `user_id = if (!is.null(req$user)) req$user$id else NULL` to the job list.

- [ ] **Step 5: Add user_id to save_job() in connection.R**

In `backend/db/connection.R`, modify `save_job()` to include `user_id` in the INSERT and UPSERT. Add `$15` parameter for `user_id` column:

In the INSERT query (around line 166), add `user_id` column and `$15::uuid` value. In the params list (around line 183), add `job$user_id` as the 15th parameter.

- [ ] **Step 6: Filter job listing by user**

In `GET /jobs` endpoint in `plumber.R`, modify to filter by user:

```r
#* List all jobs
#* @get /jobs
function(req, res) {
  tryCatch({
    conn <- get_db_connection()

    if (!is.null(req$user) && req$user$role != "admin") {
      query <- "SELECT id FROM jobs WHERE user_id = $1::uuid ORDER BY created_at DESC"
      result <- dbGetQuery(conn, query, params = list(req$user$id))
      job_ids <- result$id
    } else {
      job_ids <- list_job_ids()
    }

    jobs <- lapply(job_ids, function(id) {
      tryCatch({
        job <- load_job(id)
        if (is.null(job)) return(NULL)
        list(
          job_id = jsonlite::unbox(job$id),
          type = jsonlite::unbox(job$type),
          status = jsonlite::unbox(job$status),
          created_at = jsonlite::unbox(as.character(job$created_at))
        )
      }, error = function(e) {
        message("Error loading job ", id, ": ", e$message)
        NULL
      })
    })

    jobs <- Filter(Negate(is.null), jobs)
    list(jobs = jobs)
  }, error = function(e) {
    message("Error in jobs list endpoint: ", e$message)
    list(error = paste("Failed to list jobs:", e$message))
  })
}
```

- [ ] **Step 7: Add ownership check to job detail endpoints**

In `GET /jobs/<job_id>/status`, `GET /jobs/<job_id>/results`, `GET /jobs/<job_id>/log`, and `GET /jobs/<job_id>/download/<filename>`, add after loading the job:

```r
  access <- check_job_access(job, req, res)
  if (is.list(access)) return(access)
```

For the download endpoint which uses `job_exists()`, change to use `load_job()` and add the access check.

- [ ] **Step 8: Test the backend starts**

```bash
cd backend
JWT_SECRET=test-secret-key-min-32-characters-long Rscript -e '
source("plumber.R")
cat("plumber.R loads successfully with auth modules\n")
'
```

Expected: loads without error.

- [ ] **Step 9: Commit**

```bash
git add backend/plumber.R backend/db/connection.R
git commit -m "feat(auth): integrate auth filter, endpoints, and job isolation into plumber API (#60)"
```

---

## Task 7: Test Backend Auth Endpoints

**Files:**
- (No new files — uses curl against running server)

- [ ] **Step 1: Start backend**

```bash
cd backend
JWT_SECRET=test-secret-key-min-32-characters-long Rscript run.R &
sleep 3
```

- [ ] **Step 2: Test registration**

```bash
curl -s -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123","name":"Test User","organization":"JHU"}' | python3 -m json.tool
```

Expected: 201 response with user object (id, email, name, organization, role).

- [ ] **Step 3: Test login**

```bash
curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}' | python3 -m json.tool
```

Expected: 200 response with `token` and `user` object. Save the token for next steps.

- [ ] **Step 4: Test /auth/me with token**

```bash
TOKEN=<paste token from step 3>
curl -s http://localhost:8000/auth/me \
  -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

Expected: 200 with user profile.

- [ ] **Step 5: Test duplicate registration**

```bash
curl -s -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"anotherpass","name":"Dup User"}' | python3 -m json.tool
```

Expected: 409 `"Email already registered"`.

- [ ] **Step 6: Test wrong password login**

```bash
curl -s -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"wrongpass"}' | python3 -m json.tool
```

Expected: 401 `"Invalid email or password"`.

- [ ] **Step 7: Test grace period (no token still works)**

```bash
curl -s http://localhost:8000/jobs | python3 -m json.tool
```

Expected: 200 with jobs list (grace period allows unauthenticated access).

- [ ] **Step 8: Clean up test user (optional) and stop server**

```bash
psql -h localhost -p 5433 -U eric -d comsa_dashboard -c "DELETE FROM users WHERE email = 'test@example.com';"
kill %1  # stop background server
```

---

## Task 8: Frontend — Add react-router-dom

**Files:**
- Modify: `frontend/package.json` (via npm)
- Modify: `frontend/src/main.jsx`

- [ ] **Step 1: Install react-router-dom**

```bash
cd frontend
npm install react-router-dom
```

- [ ] **Step 2: Update main.jsx to add BrowserRouter**

Replace `frontend/src/main.jsx` contents:

```jsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import './index.css'
import App from './App.jsx'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <App />
    </BrowserRouter>
  </StrictMode>,
)
```

- [ ] **Step 3: Verify dev server starts**

```bash
cd frontend
npm run dev &
sleep 3
curl -s http://localhost:5173/comsa-dashboard/ | head -5
kill %1
```

Expected: HTML response with React root div.

- [ ] **Step 4: Commit**

```bash
cd frontend
git add package.json package-lock.json src/main.jsx
git commit -m "feat(frontend): add react-router-dom and BrowserRouter (#60)"
```

---

## Task 9: Frontend — Auth Context

**Files:**
- Create: `frontend/src/auth/AuthContext.jsx`
- Modify: `frontend/src/api/client.js`
- Modify: `frontend/src/main.jsx`

- [ ] **Step 1: Add auth header support to API client**

In `frontend/src/api/client.js`, modify `fetchJson` to include auth headers:

```js
function getAuthHeaders() {
  const headers = {};
  const token = localStorage.getItem('token');
  if (token) {
    headers['Authorization'] = `Bearer ${token}`;
  }
  return headers;
}

async function fetchJson(url, options = {}) {
  const headers = { ...getAuthHeaders(), ...options.headers };
  const res = await fetch(url, { ...options, headers });

  if (res.status === 401) {
    localStorage.removeItem('token');
    window.dispatchEvent(new Event('auth:logout'));
  }

  const data = await res.json();
  return unbox(data);
}
```

Add auth API functions at the end of `client.js`:

```js
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
```

- [ ] **Step 2: Create AuthContext.jsx**

```jsx
// frontend/src/auth/AuthContext.jsx
import { createContext, useContext, useState, useEffect } from 'react';
import { loginUser, registerUser, fetchCurrentUser } from '../api/client';

const AuthContext = createContext(null);

export function AuthProvider({ children }) {
  const [user, setUser] = useState(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const token = localStorage.getItem('token');
    if (token) {
      fetchCurrentUser()
        .then(setUser)
        .catch(() => {
          localStorage.removeItem('token');
          setUser(null);
        })
        .finally(() => setLoading(false));
    } else {
      setLoading(false);
    }

    const handleLogout = () => { setUser(null); };
    window.addEventListener('auth:logout', handleLogout);
    return () => window.removeEventListener('auth:logout', handleLogout);
  }, []);

  const login = async (email, password) => {
    const data = await loginUser(email, password);
    localStorage.setItem('token', data.token);
    setUser(data.user);
    return data.user;
  };

  const register = async (fields) => {
    await registerUser(fields);
  };

  const logout = () => {
    localStorage.removeItem('token');
    setUser(null);
  };

  return (
    <AuthContext.Provider value={{ user, loading, login, logout, register }}>
      {children}
    </AuthContext.Provider>
  );
}

export const useAuth = () => useContext(AuthContext);
```

- [ ] **Step 3: Wrap App with AuthProvider in main.jsx**

```jsx
import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { BrowserRouter } from 'react-router-dom'
import { AuthProvider } from './auth/AuthContext.jsx'
import './index.css'
import App from './App.jsx'

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <BrowserRouter basename={import.meta.env.BASE_URL}>
      <AuthProvider>
        <App />
      </AuthProvider>
    </BrowserRouter>
  </StrictMode>,
)
```

- [ ] **Step 4: Verify it compiles**

```bash
cd frontend
npm run build 2>&1 | tail -5
```

Expected: build succeeds with no errors.

- [ ] **Step 5: Commit**

```bash
cd frontend
git add src/auth/AuthContext.jsx src/api/client.js src/main.jsx
git commit -m "feat(frontend): add AuthContext and auth API functions (#60)"
```

---

## Task 10: Frontend — Login and Register Pages

**Files:**
- Create: `frontend/src/pages/LoginPage.jsx`
- Create: `frontend/src/pages/RegisterPage.jsx`
- Create: `frontend/src/components/ProtectedRoute.jsx`

- [ ] **Step 1: Create ProtectedRoute**

```jsx
// frontend/src/components/ProtectedRoute.jsx
import { Navigate } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function ProtectedRoute({ children, adminOnly = false }) {
  const { user, loading } = useAuth();

  if (loading) return <div className="loading">Loading...</div>;
  if (!user) return <Navigate to="/login" replace />;
  if (adminOnly && user.role !== 'admin') return <Navigate to="/" replace />;

  return children;
}
```

- [ ] **Step 2: Create LoginPage**

```jsx
// frontend/src/pages/LoginPage.jsx
import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const { login } = useAuth();
  const navigate = useNavigate();

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSubmitting(true);

    try {
      await login(email, password);
      navigate('/');
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <h2>Sign In</h2>
        <form onSubmit={handleSubmit}>
          {error && <div className="auth-error">{error}</div>}
          <label>
            Email
            <input type="email" value={email} onChange={e => setEmail(e.target.value)} required />
          </label>
          <label>
            Password
            <input type="password" value={password} onChange={e => setPassword(e.target.value)} required minLength={8} />
          </label>
          <button type="submit" disabled={submitting}>
            {submitting ? 'Signing in...' : 'Sign In'}
          </button>
        </form>
        <p className="auth-link">
          Don't have an account? <Link to="/register">Register</Link>
        </p>
      </div>
    </div>
  );
}
```

- [ ] **Step 3: Create RegisterPage**

```jsx
// frontend/src/pages/RegisterPage.jsx
import { useState } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import { useAuth } from '../auth/AuthContext';

export default function RegisterPage() {
  const [form, setForm] = useState({ email: '', password: '', name: '', organization: '' });
  const [error, setError] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const { register } = useAuth();
  const navigate = useNavigate();

  const handleChange = (e) => {
    setForm({ ...form, [e.target.name]: e.target.value });
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSubmitting(true);

    try {
      await register(form);
      navigate('/login', { state: { registered: true } });
    } catch (err) {
      setError(err.message);
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <div className="auth-page">
      <div className="auth-card">
        <h2>Create Account</h2>
        <form onSubmit={handleSubmit}>
          {error && <div className="auth-error">{error}</div>}
          <label>
            Email *
            <input type="email" name="email" value={form.email} onChange={handleChange} required />
          </label>
          <label>
            Password *
            <input type="password" name="password" value={form.password} onChange={handleChange} required minLength={8} />
          </label>
          <label>
            Name
            <input type="text" name="name" value={form.name} onChange={handleChange} />
          </label>
          <label>
            Organization
            <input type="text" name="organization" value={form.organization} onChange={handleChange} />
          </label>
          <button type="submit" disabled={submitting}>
            {submitting ? 'Creating account...' : 'Create Account'}
          </button>
        </form>
        <p className="auth-link">
          Already have an account? <Link to="/login">Sign In</Link>
        </p>
      </div>
    </div>
  );
}
```

- [ ] **Step 4: Verify build**

```bash
cd frontend
npm run build 2>&1 | tail -5
```

Expected: no errors.

- [ ] **Step 5: Commit**

```bash
cd frontend
git add src/pages/LoginPage.jsx src/pages/RegisterPage.jsx src/components/ProtectedRoute.jsx
git commit -m "feat(frontend): add Login, Register pages and ProtectedRoute (#60)"
```

---

## Task 11: Frontend — Refactor App.jsx to Use Routes

**Files:**
- Modify: `frontend/src/App.jsx`

- [ ] **Step 1: Refactor App.jsx**

Replace `frontend/src/App.jsx` with route-based navigation:

```jsx
import { useState } from 'react';
import { Routes, Route, Link, useNavigate, useLocation } from 'react-router-dom';
import { useAuth } from './auth/AuthContext';
import ProtectedRoute from './components/ProtectedRoute';
import JobForm from './components/JobForm';
import JobList from './components/JobList';
import JobDetail from './components/JobDetail';
import DemoGallery from './components/DemoGallery';
import LoginPage from './pages/LoginPage';
import RegisterPage from './pages/RegisterPage';
import './App.css';

function Dashboard() {
  const [selectedJob, setSelectedJob] = useState(null);
  const [refreshTrigger, setRefreshTrigger] = useState(0);

  const handleJobSubmitted = (jobId) => {
    setSelectedJob(jobId);
    setRefreshTrigger((n) => n + 1);
  };

  const handleBack = () => {
    setSelectedJob(null);
    setRefreshTrigger((n) => n + 1);
  };

  if (selectedJob) {
    return <JobDetail jobId={selectedJob} onBack={handleBack} />;
  }

  return (
    <div className="dashboard">
      <JobForm onJobSubmitted={handleJobSubmitted} />
      <JobList onSelectJob={setSelectedJob} refreshTrigger={refreshTrigger} />
    </div>
  );
}

function DemosPage() {
  const navigate = useNavigate();
  const [selectedJob, setSelectedJob] = useState(null);

  const handleDemoLaunch = (jobId) => {
    setSelectedJob(jobId);
  };

  const handleBack = () => {
    setSelectedJob(null);
  };

  if (selectedJob) {
    return <JobDetail jobId={selectedJob} onBack={handleBack} />;
  }

  return <DemoGallery onDemoLaunch={handleDemoLaunch} />;
}

function AppNav() {
  const { user, logout } = useAuth();
  const location = useLocation();

  if (!user) return null;

  return (
    <nav className="app-nav">
      <div className="nav-links">
        <Link to="/" className={location.pathname === '/' ? 'active' : ''}>Calibrate</Link>
        <Link to="/demos" className={location.pathname === '/demos' ? 'active' : ''}>Demo Gallery</Link>
        {user.role === 'admin' && (
          <Link to="/admin" className={location.pathname === '/admin' ? 'active' : ''}>Admin</Link>
        )}
      </div>
      <div className="nav-user">
        <span>{user.email}</span>
        <button onClick={logout} className="logout-btn">Sign Out</button>
      </div>
    </nav>
  );
}

function App() {
  const [videosExpanded, setVideosExpanded] = useState(false);

  return (
    <div className="app">
      <header>
        <h1>VA Calibration Platform</h1>
        <p>Process verbal autopsy data with openVA and vacalibration</p>
      </header>

      <AppNav />

      <section className="video-wrapper">
        <div className="video-card">
          <button
            className="video-toggle"
            onClick={() => setVideosExpanded(!videosExpanded)}
          >
            <span className={`toggle-icon ${videosExpanded ? 'expanded' : ''}`}>▶</span>
            Introduction Videos
          </button>
          {videosExpanded && (
            <div className="video-grid">
              <div className="video-item">
                <h4>Platform Overview</h4>
                <p>Introduction to the Verbal Autopsy Calibration Platform</p>
                <video controls>
                  <source src={`${import.meta.env.BASE_URL}VacalibrationVideo.mp4`} type="video/mp4" />
                </video>
              </div>
              <div className="video-item">
                <h4>Methodology Details</h4>
                <p>Technical explanation of the Bayesian calibration methodology</p>
                <video controls>
                  <source src={`${import.meta.env.BASE_URL}vacalibration-full-method.mp4`} type="video/mp4" />
                </video>
              </div>
            </div>
          )}
        </div>
      </section>

      <main>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route path="/register" element={<RegisterPage />} />
          <Route path="/" element={
            <ProtectedRoute><Dashboard /></ProtectedRoute>
          } />
          <Route path="/demos" element={
            <ProtectedRoute><DemosPage /></ProtectedRoute>
          } />
          <Route path="/admin" element={
            <ProtectedRoute adminOnly>
              <div>Admin Dashboard (coming next)</div>
            </ProtectedRoute>
          } />
        </Routes>
      </main>

      <footer>
        <p>Powered by Johns Hopkins Data Science and AI Institute (DSAI)</p>
      </footer>
    </div>
  );
}

export default App;
```

- [ ] **Step 2: Add basic auth CSS**

Add to `frontend/src/App.css` (or `index.css`):

```css
/* Auth pages */
.auth-page {
  display: flex;
  justify-content: center;
  padding: 2rem;
}

.auth-card {
  width: 100%;
  max-width: 400px;
  padding: 2rem;
  border: 1px solid #ddd;
  border-radius: 8px;
  background: white;
}

.auth-card h2 {
  margin-top: 0;
}

.auth-card label {
  display: block;
  margin-bottom: 1rem;
}

.auth-card input {
  display: block;
  width: 100%;
  padding: 0.5rem;
  margin-top: 0.25rem;
  border: 1px solid #ccc;
  border-radius: 4px;
  box-sizing: border-box;
}

.auth-card button[type="submit"] {
  width: 100%;
  padding: 0.75rem;
  background: #2563eb;
  color: white;
  border: none;
  border-radius: 4px;
  cursor: pointer;
  font-size: 1rem;
}

.auth-card button[type="submit"]:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.auth-error {
  background: #fef2f2;
  color: #dc2626;
  padding: 0.75rem;
  border-radius: 4px;
  margin-bottom: 1rem;
}

.auth-link {
  text-align: center;
  margin-top: 1rem;
}

/* Navigation */
.app-nav {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 1rem;
  background: #f8fafc;
  border-bottom: 1px solid #e2e8f0;
}

.nav-links a {
  margin-right: 1rem;
  text-decoration: none;
  color: #475569;
  padding: 0.25rem 0.5rem;
}

.nav-links a.active {
  color: #2563eb;
  font-weight: 600;
}

.nav-user {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.nav-user span {
  color: #64748b;
  font-size: 0.875rem;
}

.logout-btn {
  background: none;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  padding: 0.25rem 0.75rem;
  cursor: pointer;
  color: #475569;
  font-size: 0.875rem;
}
```

- [ ] **Step 3: Verify build and existing tests**

```bash
cd frontend
npm run build 2>&1 | tail -5
npm test 2>&1 | tail -10
```

Expected: build succeeds. Some existing tests may need updating if they render `<App />` (they may need to be wrapped in `<BrowserRouter>` and `<AuthProvider>`).

- [ ] **Step 4: Fix any failing tests**

If tests that render `<App />` fail, wrap them in the required providers:

```jsx
import { BrowserRouter } from 'react-router-dom';
import { AuthProvider } from '../auth/AuthContext';

// In test render calls:
render(
  <BrowserRouter>
    <AuthProvider>
      <App />
    </AuthProvider>
  </BrowserRouter>
);
```

- [ ] **Step 5: Commit**

```bash
cd frontend
git add src/App.jsx src/App.css
git commit -m "feat(frontend): refactor App to use react-router with auth routes (#60)"
```

---

## Task 12: Frontend — Admin Page

**Files:**
- Create: `frontend/src/pages/AdminPage.jsx`
- Modify: `frontend/src/api/client.js` (add admin API functions)
- Modify: `frontend/src/App.jsx` (replace placeholder admin route)

- [ ] **Step 1: Add admin API functions to client.js**

```js
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
```

- [ ] **Step 2: Create AdminPage**

```jsx
// frontend/src/pages/AdminPage.jsx
import { useState, useEffect } from 'react';
import { fetchAdminUsers, updateAdminUser } from '../api/client';

export default function AdminPage() {
  const [users, setUsers] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  const loadUsers = async () => {
    try {
      const data = await fetchAdminUsers();
      setUsers(data.users || []);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => { loadUsers(); }, []);

  const toggleActive = async (userId, currentActive) => {
    await updateAdminUser(userId, { is_active: !currentActive });
    loadUsers();
  };

  const toggleRole = async (userId, currentRole) => {
    const newRole = currentRole === 'admin' ? 'user' : 'admin';
    await updateAdminUser(userId, { role: newRole });
    loadUsers();
  };

  if (loading) return <div>Loading users...</div>;
  if (error) return <div className="auth-error">{error}</div>;

  return (
    <div className="admin-page">
      <h2>User Management</h2>
      <table className="admin-table">
        <thead>
          <tr>
            <th>Email</th>
            <th>Name</th>
            <th>Organization</th>
            <th>Role</th>
            <th>Jobs</th>
            <th>Active</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          {users.map(u => (
            <tr key={u.id}>
              <td>{u.email}</td>
              <td>{u.name || '-'}</td>
              <td>{u.organization || '-'}</td>
              <td>{u.role}</td>
              <td>{u.job_count}</td>
              <td>{u.is_active ? 'Yes' : 'No'}</td>
              <td>
                <button onClick={() => toggleActive(u.id, u.is_active)} className="admin-btn">
                  {u.is_active ? 'Disable' : 'Enable'}
                </button>
                <button onClick={() => toggleRole(u.id, u.role)} className="admin-btn">
                  {u.role === 'admin' ? 'Demote' : 'Promote'}
                </button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}
```

- [ ] **Step 3: Update App.jsx admin route**

Replace the placeholder admin route in `App.jsx`:

```jsx
import AdminPage from './pages/AdminPage';

// In Routes:
<Route path="/admin" element={
  <ProtectedRoute adminOnly>
    <AdminPage />
  </ProtectedRoute>
} />
```

- [ ] **Step 4: Add admin CSS to App.css**

```css
/* Admin page */
.admin-page {
  padding: 1rem;
}

.admin-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 1rem;
}

.admin-table th,
.admin-table td {
  padding: 0.5rem 0.75rem;
  text-align: left;
  border-bottom: 1px solid #e2e8f0;
}

.admin-table th {
  background: #f8fafc;
  font-weight: 600;
}

.admin-btn {
  background: none;
  border: 1px solid #cbd5e1;
  border-radius: 4px;
  padding: 0.2rem 0.5rem;
  cursor: pointer;
  margin-right: 0.25rem;
  font-size: 0.8rem;
}
```

- [ ] **Step 5: Verify build**

```bash
cd frontend
npm run build 2>&1 | tail -5
```

Expected: builds without error.

- [ ] **Step 6: Commit**

```bash
cd frontend
git add src/pages/AdminPage.jsx src/api/client.js src/App.jsx src/App.css
git commit -m "feat(frontend): add admin user management page (#60)"
```

---

## Task 13: End-to-End Verification

- [ ] **Step 1: Start backend**

```bash
cd backend
JWT_SECRET=test-secret-key-min-32-characters-long Rscript run.R &
```

- [ ] **Step 2: Start frontend dev server**

```bash
cd frontend
npm run dev &
```

- [ ] **Step 3: Manual E2E test checklist**

Open browser to `http://localhost:5173/comsa-dashboard/`:
1. Should redirect to `/login`
2. Click "Register" → fill form → submit → redirected to `/login`
3. Login with registered credentials → redirected to `/`
4. Dashboard shows (JobForm + JobList) — only current user's jobs
5. Navigate to Demo Gallery → launch a demo → verify job appears
6. Sign Out → redirected to `/login`
7. (If admin) Login as admin → Admin tab visible → click Admin → user table loads

- [ ] **Step 4: Run existing frontend tests**

```bash
cd frontend
npm test
```

Fix any broken tests due to routing/auth changes.

- [ ] **Step 5: Clean up and stop servers**

```bash
kill %1 %2  # stop backend and frontend
```

---

## Task 14: Disable Grace Period (Phase 5 enforcement)

> **Note:** Only do this task after confirming the frontend auth is fully working.

**Files:**
- Modify: `backend/auth/middleware.R`

- [ ] **Step 1: Set AUTH_GRACE_PERIOD to FALSE**

In `backend/auth/middleware.R`, change:

```r
AUTH_GRACE_PERIOD <- FALSE
```

- [ ] **Step 2: Test that unauthenticated requests are rejected**

```bash
cd backend
JWT_SECRET=test-secret-key-min-32-characters-long Rscript run.R &
sleep 3

# This should now return 401
curl -s -o /dev/null -w "%{http_code}" http://localhost:8000/jobs
```

Expected: `401`

- [ ] **Step 3: Commit**

```bash
git add backend/auth/middleware.R
git commit -m "feat(auth): disable grace period — require JWT on all protected endpoints (#60)"
```

---

## Verification Summary

After all tasks are complete:

1. **Backend unit tests**: Password hashing (sodium), token create/verify (jose)
2. **Backend API tests**: Register, login, /auth/me, duplicate email, wrong password, disabled account
3. **Job isolation**: User A cannot see User B's jobs; admin sees all
4. **Frontend build**: `npm run build` succeeds
5. **Frontend unit tests**: `npm test` passes
6. **E2E flow**: Register → Login → Submit job → View results → Logout
7. **Admin flow**: Admin login → View users → Disable user → Verify disabled user can't login
