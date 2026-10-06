# Deferred Items: Quick Task 261006-k87 (issue #139 wide one-hot CSV upload)

Out-of-scope discoveries found during execution. Per the deviation-rule scope boundary, these are
logged here and NOT fixed as part of this task — they are pre-existing and unrelated to the wide
one-hot CSV upload reader.

## 1. `frontend/src/api/integration.test.js` — 2 pre-existing failures (tests send no Authorization header)

- **Tests:** `Backend API integration > GET /jobs returns jobs array`,
  `Backend API integration > POST /jobs/demo creates a job`
- **Symptom:** `expect(res.ok).toBe(true)` fails (`res.ok === false`, HTTP 401).
- **Root cause (verified by the orchestrator against a backend started from the main checkout,
  with `.env.local` present):** both tests call protected endpoints with a bare `fetch()` and no
  `Authorization: Bearer …` header. Since login became mandatory (`backend/auth/middleware.R`
  reads `AUTH_GRACE_PERIOD`, default `false`, once at startup), `auth_filter` returns 401 before
  the handler runs. `.env.local` is irrelevant: it carries DB credentials and `JWT_SECRET`, not a
  test token. `GET /health` is public and passes, which is why only these two fail.
  ```
  curl -s -o /dev/null -w "HTTP %{http_code}\n" -X POST "http://localhost:8000/jobs/demo?algorithm=insilicova&age_group=neonate&country=Mozambique"
  HTTP 401
  ```
- **Verified pre-existing:** `git diff --quiet master -- frontend/src/api/integration.test.js backend/auth`
  is empty — neither the test nor the auth layer was touched by this task. Same 2 failures on the
  baseline HEAD before any change (366/368 → 367/369 after, the +1 being this task's new assertion).
  See also the memory note on issue #131 (an old backend process started before the grace-period
  default flipped makes these tests pass; a fresh one makes them fail).
- **Why deferred:** Out of scope for issue #139 (one issue per PR; D-04 forbids extra infrastructure).
- **Suggested follow-up (not actioned):** have the two tests register a throwaway user via the
  public `POST /auth/register`, log in, and send the token — or fail loudly with a named reason
  when no backend credentials exist, consistent with CLAUDE.md's "no silent test skips" rule.
  Note: `POST /auth/register` returned `500 <simpleError: Parameter 3 does not have length 1.>`
  against the local backend during this check (DB-side, untouched by this task) — worth a look
  in the same follow-up.

## 2. Pre-existing ESLint errors in untouched files

- **Command:** `cd frontend && npm run lint` (run as an extra sanity check; not one of the plan's
  two required verification gates).
- **Findings:**
  - `frontend/src/api/integration.test.js:5,36` — `'process' is not defined (no-undef)`
  - `frontend/src/auth/AuthContext.jsx:21` — `react-hooks/set-state-in-effect`
  - `frontend/src/auth/AuthContext.jsx:52` — `react-refresh/only-export-components`
- **Verified pre-existing / untouched by this task:**
  `git diff --stat HEAD~2 -- frontend/src/api/integration.test.js frontend/src/auth/AuthContext.jsx`
  returns empty — neither file was modified by any of this task's three commits.
- **Why deferred:** Scope boundary rule — "pre-existing warnings, linting errors... in unrelated
  files are out of scope."
