## Deferred Items

- Pre-existing `npm run lint` failures in `frontend/src/auth/AuthContext.jsx` (react-hooks/set-state-in-effect,
  react-refresh/only-export-components) and `frontend/src/api/integration.test.js` (`no-undef` on `process`)
  status: open
  **What:** `cd frontend && npm run lint` exits 1 with 4 errors across these two files, unrelated to
  data-retention work. Confirmed pre-existing at commit `f81cf1f` (end of plan 03-01), last touched by
  unrelated commit `05047ec` ("chore(test): add PR test CI + env-configurable backend port"). Plan 03-02
  touches only `frontend/src/components/JobList.jsx`, which lints clean in isolation
  (`npx eslint src/components/JobList.jsx` exits 0), and `npm run build` succeeds. Out of scope per the
  deviation rules' scope boundary (pre-existing, unrelated files) -- not fixed here.
