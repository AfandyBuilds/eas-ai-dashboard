# Changelog

All notable changes to the E-AI-S (EAS AI Adoption Tracker) project are recorded here.

Format: `- YYYY-MM-DD (channel) — description (scope)`
Channels: `claude` · `copilot` · `commit` · `manual`
This changelog is **append-only**. Every task, regardless of origin, must add an entry under `## [Unreleased]` per `.github/copilot-instructions.md` §4.

---

## [Unreleased]

- 2026-04-13 (copilot) — **Move Use Case Library to Resources**: Moved the Use Case Library nav item from Management section into Resources section and reordered Resources tabs by relevance: Use Case Library → Prompt Library → Skills Library → Guidelines → Copilot Enablement → AI News. (refactor/ui)

- 2026-04-12 (copilot) — **Skills Library → skills.sh Integration**: Replaced static skills learning cards with a full skills.sh marketplace integration. New page features: searchable catalog of 18 curated skills from the skills.sh leaderboard (vercel-labs, anthropics, microsoft, obra), category filter pills (Frontend, Backend, DevOps & Cloud, Design & UX, Productivity, Official), per-skill install modal with copy-to-clipboard commands for multiple IDEs (GitHub Copilot, Cursor, Windsurf, Claude Code, Global), supported agents grid showing 15+ IDEs with their skill paths, and a how-to installation guide. Added ~300 lines of CSS for marketplace UI components (skill cards, search bar, filter pills, install modals, agent badges). (feat)

- 2026-04-12 (copilot) — **Prompt Library → Database Migration**: Migrated all 55 hardcoded prompts (7 roles × 7-9 prompts each) from inline HTML to Supabase `prompt_library` table. New SQL migration `005_prompt_library.sql`. Added RLS (authenticated read, admin CRUD), `increment_prompt_copy()` RPC for copy analytics, and `updated_at` trigger. Guide Me page now dynamically fetches and renders prompts from DB with loading state. Copy-to-clipboard tracks copy_count via RPC. Added `fetchPromptLibrary()` and `incrementPromptCopy()` to `db.js`. Added full admin CRUD panel (Admin → Prompt Library) with search, role filter, add/edit/delete modal. (feat/refactor)

- 2026-04-12 (copilot) — Add Prompt Library tab to Guide Me page with role-based sections for PM, Solution Architect, Business Analyst, Developer, DBA, Admin, and Delivery Manager. Each role has categorized, copy-to-clipboard prompts covering domain-specific AI use cases. Includes role filter pills, prompt counts, and visual feedback on copy. (feat)

- 2026-04-12 (copilot) — **Phase 9: Licensed Tool Tracking** — Added end-to-end tracking for Ejada-paid licensed AI tools (GitHub Copilot + M365 Copilot). New SQL migration (`sql/004_licensed_tool_tracking.sql`) adds `is_licensed` column to LOVs, per-tool status columns to `copilot_users`, generated `is_licensed_tool` column on `tasks`, and `get_licensed_tool_adoption()` RPC. Updated `db.js` with `LICENSED_TOOLS` constant, `isLicensedTool()` helper, `fetchLicensedToolAdoption()` RPC call, and enhanced `fetchAllData()` to return licensed tool breakdowns. Dashboard now shows Licensed Tool Adoption KPI section with 5 KPI cards, Licensed vs Other split donut chart, Licensed Tool Adoption by Practice stacked bar chart, and enhanced AI Tools donut with licensed tool colors. Tasks table shows "🏢 Licensed" badges on tool column. Form dropdowns use optgroups to separate "Licensed (Ejada-Paid)" tools from "Other Tools". Use Case Library adds licensed tool badges and "Licensed Tools Only" filter. SPOC panel shows practice-level licensed tool %. "Copilot Access" renamed to "Licensed AI Users" with per-tool status columns. (feat)

- 2026-04-12 (copilot) — Add SE (Service Excellence) practice: Head Neraaj Goel, SPOC Neeraj Goel (ngoel@ejada.com). Inserted into live DB and updated seed SQL. (feat)\n- 2026-04-12 (copilot) — Fix signup: practices dropdown was empty (RLS blocked anon reads); added `department` column to practices table; signup now dynamically loads departments and filters practices by department. Added 'viewer' role for read-only access (Neeraj Goel); viewer can see all data/exports but cannot create, edit, or delete records. Updated RLS, auth.js, index.html nav/buttons, seed SQL. (feat/fix)
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
