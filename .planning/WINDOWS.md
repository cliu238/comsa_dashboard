---
schema_version: 1
open_count: 1
waived_count: 0
fixed_count: 0
total_count: 1
last_updated: 2026-09-13T05:31:07.677Z
---

# Broken Windows Ledger

> Cross-phase defect register. With `workflow.windows_enforce` enabled, `/gsd-ship` blocks while `open_count > 0`.
> Waive with `gsd-tools windows waive <id> "<reason>"` (reason required).
> Mark fixed with `gsd-tools windows fixed <id>`.

| id | phase | kind | file | line | description | status | reason | recorded_at | resolved_at |
|----|-------|------|------|------|-------------|--------|--------|-------------|-------------|
| 1 | 03 | lint-warning | frontend/src/auth/AuthContext.jsx |  | Pre-existing npm run lint failures (react-hooks/set-state-in-effect, react-refresh/only-export-components) in AuthContext.jsx and no-undef in api/integration.test.js -- unrelated to plan 03-02, confirmed pre-existing at f81cf1f | open |  | 2026-09-13T05:31:07.677Z |  |

````json
[
  {
    "id": 1,
    "kind": "lint-warning",
    "phase": "03",
    "file": "frontend/src/auth/AuthContext.jsx",
    "line": null,
    "description": "Pre-existing npm run lint failures (react-hooks/set-state-in-effect, react-refresh/only-export-components) in AuthContext.jsx and no-undef in api/integration.test.js -- unrelated to plan 03-02, confirmed pre-existing at f81cf1f",
    "status": "open",
    "reason": "",
    "recorded_at": "2026-09-13T05:31:07.677Z",
    "resolved_at": null
  }
]
````
