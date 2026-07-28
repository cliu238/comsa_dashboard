# backend/auth/middleware.R
# Plumber authentication filter with grace period support

source("auth/tokens.R")

# Grace period: if TRUE, allow unauthenticated requests through (req$user = NULL).
# Turned off now that frontend auth has shipped (login page, ProtectedRoute on
# every route, admin users page) — the dashboard is login-only. An anonymous
# request to any non-public endpoint now gets 401 instead of falling through.
# Overridable by env only to unblock a one-off (e.g. a smoke test) without a
# redeploy; absent or anything other than "true" keeps auth enforced.
AUTH_GRACE_PERIOD <- tolower(Sys.getenv("AUTH_GRACE_PERIOD", "false")) == "true"

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

# NOTE: job_visibility() — which jobs a request may ENUMERATE — lives in
# jobs/utils.R, not here. It has to be testable without a JWT library, and this
# file sources auth/tokens.R, which needs `jose`.

require_admin <- function(req, res) {
  if (is.null(req$user) || req$user$role != "admin") {
    res$status <- 403
    return(list(error = "Admin access required"))
  }
  TRUE
}

# HTTP wrapper over job_access_decision() (jobs/utils.R, kept there so it is
# testable without jose). Translates the decision to TRUE / a 401 / a 403.
check_job_access <- function(job, req, res) {
  switch(job_access_decision(req$user, job$user_id, AUTH_GRACE_PERIOD),
    allow = TRUE,
    unauthenticated = { res$status <- 401; list(error = "Authentication required") },
    deny = { res$status <- 403; list(error = "Access denied") }
  )
}
