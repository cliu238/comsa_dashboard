# Lean Chrome E2E Protocol — Design Spec

## Problem

Chrome E2E browser tests (Tests A-D in `.claude/skills/test/references/chrome_e2e.md`) hit the Anthropic API's 20MB request body limit. The root cause is context accumulation: screenshots (~300-800KB each in base64) plus prior tool results (Bash, Edit, Read calls) pile up in the conversation context until the API request exceeds 20MB.

**Observed failure (session 77aef96e, 2026-03-13):** Test A failed after the agent had already done 17 Bash calls, 13 Edits, and 5 Reads (updating test docs), then took 3 screenshots during browser automation. The 4th screenshot attempt triggered "Request too large (max 20MB)". The session had ~100K input tokens and the cumulative JSON payload exceeded 20MB.

## Solution: Hybrid Lean Protocol + Pre-flight Check

### 1. Tool Selection Hierarchy

For each verification step in Chrome E2E tests, use tools in this priority order:

1. **`find`** — Check if a specific element exists (button, label, message). ~1KB response.
2. **`read_page`** — Check page structure or multiple elements. ~5-20KB response.
3. **`javascript_tool`** — Read specific DOM values (text content, input values, row counts). ~1KB response.
4. **`computer(screenshot)`** — **ONLY** when visual layout matters and cannot be checked structurally. ~300-800KB response.

**Hard cap: max 2 screenshots per test.** If a procedure calls for more, the procedure needs revision.

### 2. Pre-flight Context Check

Before starting Chrome E2E, assess session context load:

- **Heuristic**: If the session has made >10 tool calls before the Chrome E2E step, warn the user that the session may hit the 20MB limit.
- **Not a hard block** — warn and let the user decide whether to continue or start a fresh session.
- **No complex byte estimation** — counting prior tool calls is sufficient.

### 3. Rewritten Test Procedures

Example — **Test A (vacalibration mode, lean protocol)**:

1. Navigate to app -> `find` to verify "Submit Job" tab exists
2. `javascript_tool` to attach CSV file (existing DataTransfer script)
3. `find` to verify file attached; `read_page` to confirm form state
4. Click "Calibrate" -> `find` to verify job created (job ID in page)
5. Poll with `find` or `javascript_tool` until status shows "completed"
6. **Screenshot #1**: Results page (visual verification of chart + table layout)
7. `read_page` to verify specific result values (CSMF table, CI columns)
8. `javascript_tool` to test CSV export

Tests B, C, D follow the same pattern: `find`/`read_page` for structural checks, 1-2 screenshots max for visual verification of final results.

## Files Changed

| File | Change Type | Description |
|------|-------------|-------------|
| `.claude/skills/test/references/chrome_e2e.md` | Major rewrite | Add tool hierarchy, pre-flight check, rewrite Tests A-D with explicit tool choices |
| `.claude/skills/test/SKILL.md` | Minor update | Section 8 reference to lean protocol; update debugging table row for 20MB error |
| `.claude/skills/test/references/common_failures.md` | Update | Add root cause explanation and lean protocol as prevention strategy |

No new files. No code changes. Documentation only.

## Context Budget Math

Under the lean protocol, a single Chrome E2E test uses approximately:
- Navigation + `find`/`read_page` calls: ~50-100KB total
- File upload via `javascript_tool`: ~2KB
- 2 screenshots: ~1-1.6MB
- **Total: ~1.2-1.7MB** (vs ~3-4MB with the old screenshot-heavy approach)

This leaves ample headroom even in sessions with moderate prior work, well within the 20MB API limit.
