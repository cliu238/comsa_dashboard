# CORS origin policy (issue #4)
#
# The `cors` filter in plumber.R used to set `Access-Control-Allow-Origin: *` on
# every route, unconditionally. Issue #4 ("Restrict CORS in production") was closed
# with no corresponding change to the filter.
#
# The wildcard was never needed in production. k8s/ingress.yaml routes
# `/comsa-dashboard/api(/|$)(.*)` to the backend and `/comsa-dashboard(/|$)(.*)` to
# the frontend under the SAME host, and frontend/.env.production sets
# `VITE_API_BASE_URL=/comsa-dashboard/api` -- a relative path. So the deployed app is
# same-origin and sends no `Origin` header the browser will check; it needs no CORS
# header at all. Only local development is cross-origin (frontend :5173, backend
# :8000), which is what the defaults below cover.
#
# Kept free of plumber, the DB and jose so tests/test_cors.R can source it in CI.

# Vite dev server, and CRA/`serve` for anyone running the older setup.
DEFAULT_CORS_ORIGINS <- c("http://localhost:5173", "http://localhost:3000")

# Parse the CORS_ALLOWED_ORIGINS env var (comma-separated). Empty/unset means the
# local-dev defaults, which is the safe answer for production too: nothing there is
# cross-origin, so an unset variable must not widen anything.
cors_allowed_origins <- function(raw = Sys.getenv("CORS_ALLOWED_ORIGINS", "")) {
  if (is.null(raw) || length(raw) != 1 || is.na(raw) || !nzchar(trimws(raw))) {
    return(DEFAULT_CORS_ORIGINS)
  }
  origins <- trimws(strsplit(raw, ",", fixed = TRUE)[[1]])
  origins <- origins[nzchar(origins)]

  # Refuse the wildcard rather than accepting it as a literal that would silently
  # never match. Whoever sets this expects it to work; a no-op would look like CORS
  # is simply broken, and honouring it would reintroduce exactly the hole #4 is
  # about. Fail loudly instead (CLAUDE.md).
  if (any(origins == "*")) {
    stop("CORS_ALLOWED_ORIGINS contains a wildcard '*'. Every origin would be able ",
         "to read authenticated API responses. List exact origins instead, e.g. ",
         "CORS_ALLOWED_ORIGINS='http://localhost:5173,https://example.org'. The ",
         "deployed app is same-origin (see k8s/ingress.yaml) and needs no entry at all.",
         call. = FALSE)
  }
  if (length(origins) == 0) return(DEFAULT_CORS_ORIGINS)
  origins
}

# The value to echo back in Access-Control-Allow-Origin, or NULL for "send no such
# header". Exact string match only: an origin is a scheme+host+port triple, so
# prefix/suffix matching is what turns `http://localhost:5173` into
# `http://localhost:5173.evil.example.com`.
cors_allow_origin <- function(request_origin, allowed = cors_allowed_origins()) {
  if (is.null(request_origin) || length(request_origin) != 1) return(NULL)
  if (is.na(request_origin) || !nzchar(request_origin)) return(NULL)
  # "null" is what a sandboxed iframe or a file:// page sends. It is a real Origin
  # value, not an absent one, and must never be treated as trusted.
  if (identical(request_origin, "null")) return(NULL)
  if (request_origin %in% allowed) return(request_origin)
  NULL
}
