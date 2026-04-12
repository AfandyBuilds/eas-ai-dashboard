# Changelog

All notable changes to the E-AI-S (EAS AI Adoption Tracker) project are recorded here.

Format: `- YYYY-MM-DD (channel) — description (scope)`
Channels: `claude` · `copilot` · `commit` · `manual`
This changelog is **append-only**. Every task, regardless of origin, must add an entry under `## [Unreleased]` per `.github/copilot-instructions.md` §4.

---

## [Unreleased]

- 2026-04-12 (copilot) — Fix RLS violation on task INSERT for contributor/SPOC users: added missing `tasks_contributor_update` and `submission_approvals_spoc_insert` policies; fixed hardcoded practice name mismatch ('ERP' → 'ERP Solutions'); auto-restrict practice dropdown for non-admin users to their own practice. (fix)
- 2026-04-12 (copilot) — Enforce approval-only metrics, charts, exports, and forecasts; add approval badges to tasks/accomplishments; edits reset approval and trigger re-approval workflow. (approval)
- 2026-04-12 (copilot) — Add AI Innovation approved use cases: created `use_cases` table in Supabase, extracted 40 EAS use cases from AI_Use_Case_Asset_Template Excel, inserted all as approved reference use cases. Updated Use Case Library UI to show approved use cases with "AI Innovation Approved" badges alongside community task-derived use cases. Added type filter (Approved/Community). Updated AI validation edge function to reference approved use cases during submission validation. New migration: `sql/003_use_cases.sql`. (feat)
- 2026-04-12 (copilot) — Add "Guide Me" page: new Resources section in sidebar with a 4-tab help page for adopters — Guidelines (parsed from guidelines.txt), AI News, Skills Library, and GitHub Copilot Enablement links from Microsoft. Includes full responsive CSS and tab-switching JS. (feat)
- 2026-04-12 (copilot) — Fix RLS policies on `submission_approvals` and `practice_spoc`: policies were comparing `auth.uid()` against `users.id` instead of `users.auth_id`, causing zero rows returned for all roles. Replaced with `get_user_role()`/`get_user_practice()` helper functions that correctly use `auth_id`. Added authenticated-read SELECT policy. (fix)
- 2026-04-12 (copilot) — Fix approvals navigation errors by adding `getUserId` to auth and scoping the Approvals nav item to admin/SPOC roles (fix)

- 2026-04-11 (claude) — **Fix:** added root redirect stubs (`index.html`, `login.html`, `signup.html`, `admin.html`, `employee-status.html`, `migrate.html`) after the `src/pages/` move broke the GitHub Pages root URL (which started serving `README.md` instead of the dashboard). Each stub is a tiny HTML page that forwards via `window.location.replace` + `<meta refresh>` to the canonical file under `src/pages/`, preserving query strings and hashes. Existing bookmarks and OAuth redirects continue to work. (fix)
- 2026-04-11 (claude) — Reorganized project layout: moved `index/admin/login/signup/migrate/employee-status.html` into `src/pages/` and rewrote all asset references to `../../css/` and `../../js/` (refactor)
- 2026-04-11 (claude) — Merged project instructions into `.github/copilot-instructions.md` as the single source of truth for Claude + Copilot + commit-authored changes, covering TODO workflow, mandatory skills (UI/UX Pro, Superpowers, Supabase), Supabase MCP rule, full docs sweep, authoritative layout, reference-integrity rule, and commit hygiene (docs)
- 2026-04-11 (claude) — Introduced `CHANGELOG.md` with the doc-update rule enforced for every task communicated via Claude, GitHub Copilot, or git (docs)
- 2026-04-11 (claude) — Updated `README.md` project-structure tree and live-URL paths to reflect `src/pages/` layout and linked docs subfolders (`docs/approval/`, `docs/deployment/`, `docs/phase8/`, `docs/testing/`) (docs)
- 2026-04-11 (claude) — Removed empty `docs/cr/` directory (chore)

## [Prior history]

See git log for commits before `CHANGELOG.md` was introduced.
