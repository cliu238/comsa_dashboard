# Deferred Items — quick/260826-fps-fix-issue-130

## `frontend/src/api/integration.test.js` fails on `/jobs` and `/jobs/demo` (pre-existing, out of scope)

- **Observed during:** `npm test` run after Task 2 (adaptive `pct()` implementation).
- **Symptom:** `GET /jobs returns jobs array` and `POST /jobs/demo creates a job` both fail
  with `expect(res.ok).toBe(true)` receiving `false`. Manually hitting the backend confirms
  the real cause: `GET /jobs` returns `401 {"error":["Missing or invalid Authorization
  header"]}`. The backend's `/health` check (which the test also exercises) still passes.
- **Root cause:** The user-auth system (JWT-protected `/jobs` routes) was added to the
  backend in an earlier phase; `integration.test.js` was never updated to send an
  `Authorization` header, so every unauthenticated call to `/jobs*` now 401s.
- **Why out of scope:** This plan (issue #130) only touches `frontend/src/components/
  CSMFChart.js` and its display-precision tests. It does not touch the backend, the auth
  system, or job endpoints. Per the executor's scope boundary, pre-existing failures in
  unrelated files are logged here, not fixed.
- **Suggested follow-up:** A future plan should update `integration.test.js` to acquire and
  send a valid JWT (or use a test/service account) before calling `/jobs` and
  `/jobs/demo`.
