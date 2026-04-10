# Code Architecture — EAS AI Dashboard

> **Last Updated:** April 11, 2026 | **Phase:** 2 (Auth + Quarters + Signup) Complete

---

## 1. System Overview

The EAS AI Dashboard is a **static-first web application** hosted on GitHub Pages with a Supabase (PostgreSQL) backend. It tracks AI tool adoption across 6 practices in Ejada’s Enterprise Application Solutions (EAS) department.

### Architecture Pattern

```
┌─────────────────────────────────────────────────────┐
│                   GitHub Pages                       │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌───────────┐  │
│  │login.html│  │index.html│  │admin.html│  │signup.html│  │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └─────┬─────┘  │
│       │              │              │                 │
│  ┌────┴──────────────┴──────────────┴────────────────┐     │
│  │              JS Modules Layer                │     │
│  │  config.js │ auth.js │ db.js │ utils.js     │     │
│  └──────────────────────┬──────────────────────┘     │
└─────────────────────────┼───────────────────────────┘
                          │ HTTPS (anon key)
                          ▼
┌─────────────────────────────────────────────────────┐
│                   Supabase                           │
│  ┌──────────┐  ┌──────────┐  ┌──────────────┐      │
│  │  Auth     │  │ PostgreSQL│  │  RLS Policies │      │
│  │  (JWT)    │  │  (9 tables)│  │  (per-role)   │      │
│  └──────────┘  └──────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────┘
```

### Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| No build step | Vanilla JS | GitHub Pages hosting, simple deployment |
| Supabase over Firebase | PostgreSQL + built-in Auth | Better SQL support, RLS, free tier |
| CDN libraries | Chart.js, SheetJS, Supabase JS | No npm build needed for frontend |
| Dark theme default | CSS custom properties | Enterprise/exec presentation use case |
| Single-page per HTML file | Multi-page SPA pattern | Works with GitHub Pages routing |

---

## 2. File Structure

```
eas-ai-dashboard/
│
├── index.html              # Main app shell — 6 in-page views
│                           # Dashboard, Practices, Tasks,
│                           # Accomplishments, Copilot, Projects
│
├── login.html              # Supabase Auth login (email/password)
├── signup.html             # Contributor self-registration (2-step form)
├── admin.html              # Admin CRUD panel (legacy static auth)
├── migrate.html            # One-time data migration tool
├── data.js                 # Static data.js (backup/legacy)
│
├── css/
│   └── variables.css       # Design tokens, base reset, shared components
│                           # :root variables, buttons, badges, toasts
│
├── js/
│   ├── config.js           # Supabase URL + anon key + client factory
│   ├── auth.js             # EAS_Auth module: session, roles, guards
│   ├── db.js               # EAS_DB module: quarters, filtering, queries
│   └── utils.js            # EAS_Utils: format, sanitize, colors, dates
│
├── sql/
│   └── 001_schema.sql      # Full Supabase schema (tables, views, RLS, triggers)
│
├── scripts/                # Node.js admin/migration scripts
│   ├── create-auth-users.mjs   # One-time auth user creation
│   ├── run-migration.mjs       # One-time data.js → Supabase migration
│   └── create-schema.mjs       # Schema execution (superseded by MCP)
│
├── docs/                   # Project documentation
│
├── .env.example            # Environment variable template
├── .gitignore              # Ignores: .env, node_modules, logs
├── package.json            # Only dep: @supabase/supabase-js (for scripts)
└── README.md               # Project overview
```

---

## 3. Module Architecture

### JS Modules (Browser-side)

All modules use the **Revealing Module Pattern** (IIFE returning a public API):

```
┌──────────────┐     ┌──────────────┐
│  config.js   │────▶│  Supabase    │
│  (client)    │     │  CDN Library  │
└──────┬───────┘     └──────────────┘
       │
       ├──────────────┐
       ▼              ▼
┌──────────────┐  ┌──────────────┐
│   auth.js    │  │    db.js     │
│  (EAS_Auth)  │  │  (EAS_DB)   │
│              │  │              │
│ - getSession │  │ - quarters   │
│ - getUser    │  │ - filtering  │
│ - roles      │  │ - Supabase   │
│ - signOut    │  │   queries    │
│ - UI guards  │  │ - selectors  │
└──────────────┘  └──────────────┘
       │              │
       └──────┬───────┘
              ▼
       ┌──────────────┐
       │  utils.js    │
       │ (EAS_Utils)  │
       │              │
       │ - sanitize   │
       │ - format     │
       │ - colors     │
       │ - dates      │
       └──────────────┘
```

| Module | Global Name | Responsibility |
|--------|-------------|----------------|
| `config.js` | `getSupabaseClient()` | Supabase client singleton |
| `auth.js` | `EAS_Auth` | Session management, role checks, auth guards, UI visibility |
| `db.js` | `EAS_DB` | Quarter loading/selection, client-side data filtering, Supabase queries |
| `utils.js` | `EAS_Utils` | Formatting, XSS sanitization, practice mappings, chart colors, date parsing |

### Load Order (Critical)

```html
<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2/dist/umd/supabase.min.js"></script>
<script src="js/config.js"></script>   <!-- Must be first: creates Supabase client -->
<script src="js/utils.js"></script>    <!-- Pure utilities, no dependencies -->
<script src="js/auth.js"></script>     <!-- Depends on config.js -->
<script src="js/db.js"></script>       <!-- Depends on config.js -->
```

---

## 4. Database Schema

### Tables (9)

| Table | Purpose | Row Count (Phase 1) |
|-------|---------|---------------------|
| `practices` | 6 EAS practices (reference) | 6 |
| `quarters` | Q1-Q4 2026 with targets | 4 |
| `users` | App users with auth linkage | 6 |
| `tasks` | AI task log (core data) | 108 |
| `accomplishments` | Notable AI wins | 4 |
| `copilot_users` | License management | 146 |
| `projects` | Project portfolio | 22 |
| `lovs` | Lists of values (dropdowns) | 18 |
| `activity_log` | Audit trail | 0 |

### Computed Columns

`tasks` table has two generated columns:
- `time_saved = time_without_ai - time_with_ai`
- `efficiency = (time_without - time_with) / time_without`

### Database Functions

| Function | Type | Purpose |
|----------|------|--------|
| `get_user_role()` | SQL | Returns role of currently authenticated user from `users` |
| `get_user_practice()` | SQL | Returns practice of currently authenticated user from `users` |
| `signup_contributor()` | SECURITY DEFINER | Creates `users` row + `copilot_users` row for new contributor signups |

#### `signup_contributor()` Parameters

| Param | Type | Description |
|-------|------|------------|
| `p_auth_id` | uuid | Supabase Auth user ID |
| `p_name` | text | Full name |
| `p_email` | text | Ejada email |
| `p_practice` | text | Practice name |
| `p_skill` | text | Job title / skill |
| `p_has_copilot` | boolean | Has Copilot access? |

Returns `jsonb` with `{status, user_id, copilot_id?}`. Copilot logic:
- `true` → `copilot_users` row with `status = 'Active'`, `copilot_access_date = null`
- `false` → `copilot_users` row with `status = 'Pending'`, `copilot_access_date = 'Not Granted'`

### Views

- `practice_summary` — Aggregated stats per practice
- `quarter_summary` — Aggregated stats per quarter

### Row-Level Security

| Role | Scope |
|------|-------|
| **Admin** | Full read/write on all tables |
| **SPOC** | Read/write own practice, read aggregates |
| **Contributor** | Insert own tasks, read own data |

---

## 5. Authentication Flow

```
User → login.html
  │
  ├── supabase.auth.signInWithPassword(email, password)
  │     │
  │     ├── ✅ Success → fetch user profile from public.users
  │     │     │
  │     │     ├── Profile found → store in localStorage, redirect to index.html
  │     │     └── Profile NOT found → check localStorage for pending signup
  │     │           │
  │     │           ├── Found → call signup_contributor() RPC, then redirect
  │     │           └── Not found → show "profile not found" error
  │     │
  │     └── ❌ Fail → show error message
  │
index.html (on load)
  │
  ├── EAS_Auth.requireAuth()
  │     │
  │     ├── getUser() → validates JWT with Supabase server
  │     │     │
  │     │     ├── ✅ Valid → load profile, continue
  │     │     └── ❌ Invalid → redirect to login.html
  │     │
  │     └── EAS_Auth.applyRoleVisibility()
  │           └── Show/hide elements with data-role attributes
```

### Signup Flow

```
User → signup.html
  │
  ├── Step 1: Fill profile (dept, practice, name, email, skill, copilot Y/N)
  │
  ├── Step 2: Create password
  │
  ├── supabase.auth.signUp(email, password)
  │     │
  │     ├── Auto-confirm ON → session returned immediately
  │     │     └── Call signup_contributor() RPC → redirect to dashboard
  │     │
  │     └── Auto-confirm OFF → no session
  │           └── Store profile in localStorage (eas_pending_signup)
  │           └── Show "check email" screen
  │           └── On first login → login.html completes RPC call
```

---

## 6. Data Flow (Current: Hybrid)

Currently in a **transitional hybrid state**:
- **Auth + Quarters** → Read from Supabase
- **Tasks, Accomplishments, etc.** → Read from inline `APP_DATA` (static)

### Phase 3 Target: Full Supabase

```
index.html → EAS_DB.fetchTasks(quarter) → Supabase API → RLS → PostgreSQL
```

---

## 7. CSS Architecture

### Design Tokens (`css/variables.css`)

All colors, spacing, and component styles are defined as CSS custom properties in `:root`. This enables future theme switching (dark/light) by swapping variable values.

### Style Scoping

- `variables.css` — Shared globally (imported by all pages)
- Inline `<style>` blocks — Page-specific styles (remaining in each HTML file)

### Color System

| Token | Value | Usage |
|-------|-------|-------|
| `--accent` | `#3b82f6` | Primary actions, links |
| `--success` | `#10b981` | Positive metrics, completed |
| `--warning` | `#f59e0b` | Caution, pending |
| `--danger` | `#ef4444` | Errors, destructive |
| `--purple` | `#8b5cf6` | Quality ratings, EPS practice |
| `--pink` | `#ec4899` | GRC practice |
| `--info` | `#06b6d4` | EPCS practice, informational |

---

## 8. Security Model

### Keys & Secrets

| Key | Location | Access Level |
|-----|----------|-------------|
| Anon Key | `js/config.js` (public) | Read with RLS enforcement |
| Service Role Key | `.env` only (never committed) | Full admin, bypasses RLS |

### XSS Prevention

`EAS_Utils.sanitize()` escapes HTML entities before any `innerHTML` insertion. All user-facing data should pass through this function.

### Client-Side Role Limitation

Role checks via `EAS_Auth.isAdmin()` control **UI visibility only**. Actual data access is enforced by Supabase RLS policies server-side.

---

## 9. Known Technical Debt

| # | Issue | Priority | Target Phase |
|---|-------|----------|--------------|
| 1 | `index.html` is ~5,400 lines (monolith) | HIGH | Phase 3 |
| 2 | `admin.html` uses hardcoded auth, not Supabase | HIGH | Phase 4 |
| 3 | Dashboard reads static `APP_DATA`, not Supabase | HIGH | Phase 3 |
| 4 | CSS partially duplicated across HTML files | MEDIUM | Phase 3 |
| 5 | `data.js` summary rows contaminate task data | MEDIUM | Phase 3 |
| 6 | No pagination on tables | LOW | Phase 4 |
| 7 | No error boundary on boot failure | LOW | Phase 6 |

---

*Document maintained as part of the EAS AI Dashboard project. See [IMPLEMENTATION_PLAN.md](IMPLEMENTATION_PLAN.md) for phase details.*
