# EAS AI Adoption Dashboard

Enterprise AI adoption tracking platform for Enterprise Application Solutions (EAS), covering 6 practices and 120+ licensed users across GitHub Copilot, Claude, ChatGPT, and other AI tools.

## Live URLs

| Page | URL |
|------|-----|
| **Dashboard** | https://omarhelal1234.github.io/eas-ai-dashboard/ |
| **Login** | https://omarhelal1234.github.io/eas-ai-dashboard/login.html |
| **Signup** | https://omarhelal1234.github.io/eas-ai-dashboard/signup.html |

## Tech Stack

- **Frontend:** Vanilla HTML/CSS/JS, Chart.js, SheetJS (Excel export)
- **Backend:** Supabase (PostgreSQL + Auth + RLS)
- **Hosting:** GitHub Pages (static site)
- **Design:** Dark theme, Inter font, responsive sidebar navigation

## Project Structure

```
./
├── index.html              # Main dashboard (6 pages + inline CRUD)
├── login.html              # Authentication page
├── signup.html             # Contributor self-registration
├── admin.html              # Legacy admin panel (deprecated — CRUD merged into dashboard)
├── migrate.html            # Browser-based migration tool
│
├── css/
│   ├── variables.css       # Shared design tokens & base styles
│   └── dashboard.css       # Dashboard component styles (extracted Phase 3)
│
├── js/
│   ├── config.js           # Supabase client configuration
│   ├── auth.js             # Authentication & session management
│   ├── db.js               # Full Supabase data layer (read + write + audit)
│   └── utils.js            # Shared utilities (formatting, sanitize)
│
├── sql/
│   └── 001_schema.sql      # Complete database schema
│
├── scripts/                # Node.js dev/admin scripts
│   ├── create-auth-users.mjs
│   ├── run-migration.mjs
│   └── create-schema.mjs
│
├── docs/                   # Project documentation
│   ├── CODE_ARCHITECTURE.md
│   ├── BRD.md
│   ├── HLD.md
│   ├── IMPLEMENTATION_PLAN.md
│   └── ONBOARDING_GUIDE.md
│
├── .agents/                # Copilot agent skills (Superpowers)
├── .github/                # GitHub config (copilot-instructions.md)
├── .env.example            # Environment variable template
├── .gitignore
├── package.json
└── README.md
```

## Getting Started

1. Clone the repository
2. Copy `.env.example` to `.env` and add your Supabase keys
3. Run `npm install`
4. Open `login.html` in browser (or serve via local server)

See [docs/ONBOARDING_GUIDE.md](docs/ONBOARDING_GUIDE.md) for full setup instructions.

## Documentation

- [Code Architecture](docs/CODE_ARCHITECTURE.md) — System design and file structure
- [Business Requirements (BRD)](docs/BRD.md) — Full feature requirements
- [High-Level Design (HLD)](docs/HLD.md) — Technical architecture
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md) — Phased delivery roadmap
- [Onboarding Guide](docs/ONBOARDING_GUIDE.md) — Setup, URLs, credentials

## Roles

| Role | Access | Example User |
|------|--------|-------------|
| **Admin** | Full CRUD all practices, data dumps, user management | Omar Ibrahim |
| **SPOC** | Own practice CRUD (tasks, accomplishments, copilot users) | Norah Al Wabel (CES) |
| **Contributor** | View dashboard, log own tasks & accomplishments | Self-registered users |

## Changelog

### Phase 4 — Admin Panel & Writes
- **Supabase CRUD**: All save/edit/delete operations write directly to Supabase (tasks, accomplishments, copilot users)
- **Edit/Delete UI**: Inline edit and delete buttons on task rows, accomplishment cards, and copilot user rows
- **Audit logging**: All write operations are logged to `activity_log` table with user ID and details
- **Data dumps**: Admin can create JSON snapshots of data stored in `data_dumps` table
- **Excel upload removed**: Replaced by direct Supabase writes (Excel export still available)
- **Admin panel deprecated**: CRUD functionality merged into main dashboard; admin.html is legacy
- **Confirmation dialogs**: All destructive actions require user confirmation
- **Form reset**: Edit modals properly reset titles and form fields

### Phase 3 — Live Data & Cleanup
- Removed ~3,700 lines of static APP_DATA JSON (77% code reduction)
- Full Supabase data layer with live queries per quarter
- Extracted CSS to `css/dashboard.css`
- Added XSS sanitization and pagination (25 rows/page)

## License

Internal — Enterprise Application Solutions © 2026
