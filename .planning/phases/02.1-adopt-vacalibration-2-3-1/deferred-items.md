## Deferred Items

- Frontend lint fails with 4 pre-existing errors, unrelated to this phase (02.1-02
  touched only `backend/jobs/utils.R` and `tests/test_vacalibration_backend.R`;
  `frontend/src` is byte-identical to the pre-phase commit `30e082d`, confirmed via
  `git diff --quiet 30e082d -- frontend/src`).
  status: open
  **What:** `cd frontend && npm run lint` reports:
  - `src/api/integration.test.js:5,36` — `'process' is not defined (no-undef)`
  - `src/auth/AuthContext.jsx:21` — `react-hooks/set-state-in-effect` (calling
    `setState` synchronously inside a `useEffect`)
  - `src/auth/AuthContext.jsx:52` — `react-refresh/only-export-components`
  **Verified pre-existing:** re-ran `npm run lint` in a fresh `git worktree` checked
  out at the pre-phase commit `30e082d2e6906d3c062f29fd5d2889fe463d90f2` (fresh
  `npm ci`, not the working tree's `node_modules`) — identical 4 errors, same lines.

- Frontend/backend integration check reports one pre-existing mismatch, unrelated to
  this phase (`backend/plumber.R` and `frontend/src/api/client.js` are both
  byte-identical to the pre-phase commit `30e082d`).
  status: open
  **What:** `python3 .claude/skills/test/scripts/check_integration.py --project-root .`
  reports `Frontend calls endpoints that don't exist in backend: GET
  /admin/users/{param}` (script exits 0, but the plan's own `<fails_when>` treats any
  reported endpoint mismatch as a failure).
  **Verified pre-existing:** re-ran the same check in a fresh `git worktree` checked
  out at the pre-phase commit `30e082d2e6906d3c062f29fd5d2889fe463d90f2` — identical
  output (same single mismatch, same warnings).
