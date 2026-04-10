# EAS AI Adoption Dashboard

Enterprise AI adoption tracking platform for Enterprise Application Solutions (EAS), covering 6 practices and 120+ licensed users across GitHub Copilot, Claude, ChatGPT, and other AI tools.

## Live URLs

| Page | URL |
|------|-----|
| **Dashboard** | https://omarhelal1234.github.io/eas-ai-dashboard/ |
| **Login** | https://omarhelal1234.github.io/eas-ai-dashboard/login.html |
| **Signup** | https://omarhelal1234.github.io/eas-ai-dashboard/signup.html |
| **Admin Panel** | https://omarhelal1234.github.io/eas-ai-dashboard/admin.html |

## Tech Stack

- **Frontend:** Vanilla HTML/CSS/JS, Chart.js, SheetJS (Excel)
- **Backend:** Supabase (PostgreSQL + Auth + RLS)
- **Hosting:** GitHub Pages (static site)
- **Design:** Dark theme, Inter font, responsive sidebar navigation

## Project Structure

```
./
├── index.html              # Main dashboard (6 pages)
├── login.html              # Authentication page
├── signup.html             # Contributor self-registration
├── admin.html              # Admin panel (CRUD)
├── migrate.html            # Browser-based migration tool
│
├── css/
│   ├── variables.css       # Shared design tokens & base styles
│   └── dashboard.css       # Dashboard component styles (extracted Phase 3)
│
├── js/
│   ├── config.js           # Supabase client configuration
│   ├── auth.js             # Authentication & session management
│   ├── db.js               # Full Supabase data layer (live queries)
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
| **Admin** | Full access, all practices, user management | Omar Ibrahim |
| **SPOC** | Own practice CRUD, program-level aggregates | Norah Al Wabel (CES) |
| **Contributor** | View dashboard, log own tasks (Phase 5) | Self-registered users |

## License

Internal — Enterprise Application Solutions © 2026
