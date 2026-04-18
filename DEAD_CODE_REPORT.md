# Dead Code Report

**Project:** E-AI-S (EAS AI Adoption Tracker)
**Scanned:** 2026-04-17
**Files analyzed:** 70+
**Findings:** 23

---

## Summary

| Category | Count | Severity |
|----------|-------|----------|
| Unreferenced Files | 4 | High |
| Unused Functions | 10 | Medium |
| Unused CSS Rules | 5 | Low |
| Orphaned Imports / Dependencies | 1 | Low |
| Dead Code Branches | 0 | — |
| Unused Variables | 0 | — |
| Duplicate / Redundant Code | 3 | Medium |

---

## Critical Findings (Safe to Delete)

### 1. `scripts/set-secrets.js` — UNREFERENCED FILE
- **34 lines** — not imported, referenced, or mentioned anywhere in the project (HTML, JS, docs, deploy scripts).
- **Confidence:** High
- **Recommendation:** Delete

### 2. `src/pages/grafana-stats.html` — ORPHANED PAGE
- **837 lines** — a standalone page with its own inline JS. Not linked from any navigation, sidebar, or other HTML page. Root `grafana-stats.html` is just a redirect to `index.html#ide-usage` (not to this page).
- **Confidence:** High — its functionality appears to have been absorbed into the main dashboard's IDE Usage view.
- **Recommendation:** Delete (the root redirect `grafana-stats.html` can also be deleted)

### 3. Unused Functions in `js/db.js`

| Function | Line | Reason | Confidence |
|----------|------|--------|------------|
| `adminResetPassword` | ~987 | Never called anywhere in the codebase | High |
| `resetRolePermissions` | ~2083 | Never called anywhere in the codebase | High |
| `fetchEmployeeTaskApprovals` | ~1806 | Never called anywhere in the codebase | High |

### 4. Unused Functions in `js/utils.js`

| Function | Line | Reason | Confidence |
|----------|------|--------|------------|
| `mapPracticeToShort` | ~100 | Never called anywhere | High |
| `mapPracticeToLong` | ~104 | Never called anywhere | High |
| ~~`debounce`~~ | ~134 | **FALSE POSITIVE** — called in `index.html:7005` (search input) | N/A |

### 5. Unused Functions in `js/auth.js`

| Function | Line | Reason | Confidence |
|----------|------|--------|------------|
| `isViewer` | ~88 | Never called anywhere | High |
| `isExecutive` | ~92 | Never called anywhere | High |
| `onAuthStateChange` | ~199 | Never called anywhere | High |

---

## Review Required

### 6. `src/pages/migrate.html` — ONE-TIME MIGRATION TOOL
- **378 lines** — a standalone data migration page. Not linked from any navigation. Only referenced in documentation (README, CLAUDE.md, IMPLEMENTATION_NOTES, etc.).
- **Confidence:** Medium — it may have been a one-time migration tool that is no longer needed, but the user should confirm.
- **Recommendation:** Ask user — if the migration is complete, delete.

### 7. Internal-Only Functions in `js/db.js`

These are exported via `window.EAS_DB` but only called internally within `db.js` itself:

| Function | Line | Notes |
|----------|------|-------|
| `calcDelta` | ~124 | Used internally in `fetchQuarterSummary` |
| `formatDelta` | ~129 | Used internally in `fetchQuarterSummary` |
| `getPreviousQuarter` | ~118 | Used internally in `fetchQuarterSummary` |
| `logActivity` | ~1005 | Used internally by insert/update/delete functions |

- **Recommendation:** These can be converted to private (non-exported) functions inside the IIFE if no external usage is intended. Not urgent.

### 8. Unused CSS Classes in `css/dashboard.css`

These classes are defined in the CSS but not used in any HTML or JS file:

| Class | Notes |
|-------|-------|
| `.guide-hero-icon` | Copilot Enablement section — possibly removed from HTML |
| `.guide-hero-text` | Copilot Enablement section — possibly removed from HTML |
| `.guide-skill-card` | Copilot Enablement section — possibly removed from HTML |
| `.guide-skill-level` | Copilot Enablement section — possibly removed from HTML |
| `.guide-skill-tags` | Copilot Enablement section — possibly removed from HTML |

- **Confidence:** Medium — these may have been left behind after the Copilot Enablement section redesign (commit `7c43dc5`).
- **Recommendation:** Delete the CSS rules.

### 9. Duplicate HTML Files (Root Redirectors)

The root-level HTML files are thin redirectors to `src/pages/`:

| Root File | Redirects To | Size |
|-----------|-------------|------|
| `index.html` | `src/pages/index.html` | 14 lines |
| `admin.html` | `src/pages/admin.html` | ~14 lines |
| `login.html` | `src/pages/login.html` | ~14 lines |
| `signup.html` | `src/pages/signup.html` | ~14 lines |
| `employee-status.html` | `src/pages/employee-status.html` | ~14 lines |
| `grafana-stats.html` | `src/pages/index.html#ide-usage` | ~14 lines |

- **Confidence:** Low — these exist for GitHub Pages compatibility (serving from root). They are NOT dead code, but `grafana-stats.html` at root is questionable since it redirects to a hash route, not to `src/pages/grafana-stats.html`.
- **Recommendation:** Keep root redirectors except `grafana-stats.html` (delete with its `src/pages/` counterpart).

### 10. `@supabase/supabase-js` npm Package

- Listed in `package.json` dependencies, but only used by `server/adoption-agent-endpoint.js` (the Node.js server).
- The main frontend loads Supabase via CDN (`<script>` tag), not via npm.
- **Confidence:** Low — the package is used, just only by the server component.
- **Recommendation:** Keep, but consider moving to `server/package.json` if it has its own.

---

## Detailed Size Impact

| Item | Lines | Type |
|------|-------|------|
| `scripts/set-secrets.js` | 34 | File |
| `src/pages/grafana-stats.html` | 837 | File |
| `grafana-stats.html` (root) | 14 | File |
| `src/pages/migrate.html` | 378 | File (pending user confirmation) |
| Unused functions (db.js) | ~120 | Code blocks |
| Unused functions (utils.js) | ~40 | Code blocks |
| Unused functions (auth.js) | ~30 | Code blocks |
| Unused CSS rules | ~40 | CSS |
| **Total removable** | **~1,115 lines** | — |

---

*Generated by Dead Code Detector skill — 2026-04-17*
