# Data Sync Skill — Weekly EAS AI Adoption Data Refresh

## Purpose

Synchronise the **EAS AI Adoption Weekly Tracker** spreadsheet and **Grafana IDE usage** exports into the Supabase database. This is a **recurring weekly task** — the same process runs every time new data lands in the `RefreshedData/` folder.

---

## Prerequisites

| Requirement | Detail |
|---|---|
| **Python 3.10+** | With `openpyxl` installed (`pip install openpyxl`) |
| **Supabase MCP** | Must be connected — all SQL runs through `execute_sql` |
| **Migration 017** | `sql/017_data_sync_phase.sql` must be applied (adds IDE columns, sync_hash, username) |

---

## Input Files

Place refreshed files in `RefreshedData/` before starting:

| File | Location | Content |
|---|---|---|
| **Tracker Excel** | `RefreshedData/EAS_AI_Adoption_Weekly_Tracker*.xlsx` | Sheets: LOVs, Summary, AI Accomplishments, Projects, Copilot User Access, CES, ERP, BFSI, EPS, EPCS, AI\_Projects, GRC |
| **Grafana IDE Exports** | `RefreshedData/RE_ EAS AI Adoption _ Grafana stats/*.xlsx` | Monthly IDE usage (columns: day, user\_login, total\_interactions, code\_generations, acceptance\_count, agent\_turns, chat\_turns, loc\_added, loc\_deleted) |

---

## Step-by-Step Sync Procedure

### Step 1 — Generate Tracker SQL

```bash
python scripts/sync_tracker.py "RefreshedData/EAS_AI_Adoption_Weekly_Tracker (2).xlsx" --out scripts/sync_output
```

**Produces** in `scripts/sync_output/`:
- `sync_copilot_users.sql` — UPSERT on `LOWER(TRIM(email))`
- `sync_tasks.sql` — UPSERT on `sync_hash` (MD5 of practice + employee + week + task)
- `sync_projects.sql` — UPSERT on `LOWER(project_name) + project_code + practice`
- `sync_accomplishments.sql` — UPSERT on `sync_hash` (MD5 of practice + title + date)
- `eas_emails.txt` — list of emails extracted (used to filter Grafana)

### Step 2 — Generate Grafana SQL

```bash
python scripts/sync_grafana.py "RefreshedData/RE_ EAS AI Adoption _ Grafana stats/IDE Developer _Feb_2026_Data.xlsx" "RefreshedData/RE_ EAS AI Adoption _ Grafana stats/IDE Developer Mar_2026_Data.xlsx" --emails scripts/sync_output/eas_emails.txt --out scripts/sync_output
```

**Produces**: `scripts/sync_output/sync_grafana_ide.sql`

### Step 3 — Execute SQL via Supabase MCP

Run each file **in order** through MCP `execute_sql`. The order matters because tasks and accomplishments reference copilot\_users practices, and Grafana UPDATEs match on `username` derived from email.

**Execution order:**
1. `sync_copilot_users.sql` — users first (base table)
2. `sync_tasks.sql` — tasks depend on practice/employee
3. `sync_projects.sql` — projects by practice
4. `sync_accomplishments.sql` — accomplishments
5. `sync_grafana_ide.sql` — UPDATEs against copilot\_users.username

For large files (>50 KB), split into batches of ~50 statements and execute sequentially.

### Step 4 — Verify Counts

Run verification query via MCP:

```sql
SELECT 'tasks' as tbl, COUNT(*) FROM tasks
UNION ALL SELECT 'copilot_users', COUNT(*) FROM copilot_users
UNION ALL SELECT 'accomplishments', COUNT(*) FROM accomplishments
UNION ALL SELECT 'projects', COUNT(*) FROM projects;
```

### Step 5 — Dedup Check

After every sync, run duplicate detection:

```sql
-- Task content duplicates
SELECT COUNT(*) as task_dupes FROM (
  SELECT practice, employee_name, week_number, task_description
  FROM tasks GROUP BY 1,2,3,4 HAVING COUNT(*) > 1
) x;

-- Project content duplicates
SELECT COUNT(*) as project_dupes FROM (
  SELECT practice, LOWER(TRIM(project_name)), project_code
  FROM projects GROUP BY 1,2,3 HAVING COUNT(*) > 1
) x;
```

If duplicates are found, apply the dedup pattern:

```sql
-- Delete web-sourced tasks where tracker_sync version exists
DELETE FROM tasks
WHERE source = 'web'
  AND EXISTS (
    SELECT 1 FROM tasks t2
    WHERE t2.source = 'tracker_sync'
      AND t2.practice = tasks.practice
      AND t2.employee_name = tasks.employee_name
      AND t2.week_number = tasks.week_number
      AND t2.task_description = tasks.task_description
  );

-- Delete projects without sync_hash where one with sync_hash exists
DELETE FROM projects
WHERE sync_hash IS NULL
  AND EXISTS (
    SELECT 1 FROM projects p2
    WHERE p2.sync_hash IS NOT NULL
      AND p2.practice = projects.practice
      AND LOWER(TRIM(p2.project_name)) = LOWER(TRIM(projects.project_name))
      AND p2.project_code = projects.project_code
  );
```

---

## Known Issues & Caveats

| Issue | Mitigation |
|---|---|
| **ERP sheet column order** differs from other practice sheets (columns E/F swapped) | `sync_tracker.py` has ERP-specific column mapping — verify `ai_tool` and `prompt_used` are not swapped after sync |
| **Duplicate emails in tracker** | Handled by `ON CONFLICT` upsert — last row wins for same email |
| **Trailing characters in emails** (e.g., `user@ejada.com>`) | Script trims whitespace; manual trailing `>` must be cleaned in source Excel |
| **Grafana user\_login mismatch** | Matches by `LOWER(username)` = `LOWER(SPLIT_PART(email, '@', 1))` — only EAS employees with matching emails are linked |
| **Large SQL files** | Supabase MCP may timeout on very large payloads — split into 50-statement batches |

---

## Practice-to-Sheet Mapping

| Excel Sheet | `practice` Value in DB |
|---|---|
| BFSI | BFSI |
| CES | CES |
| ERP | ERP Solutions |
| EPS | EPS |
| EPCS | EPCS |
| GRC | GRC |

---

## Database Schema Context

### Tables Affected

- **`copilot_users`** — employee records + IDE usage columns (`ide_total_days`, `ide_code_generations`, etc.)
- **`tasks`** — weekly task submissions per employee
- **`projects`** — project registrations per practice
- **`accomplishments`** — AI accomplishment records

### Key Columns Added by Migration 017

- `copilot_users.username` — generated as `LOWER(SPLIT_PART(email, '@', 1))`
- `copilot_users.ide_*` — 12 Grafana IDE metric columns
- `tasks.sync_hash` / `accomplishments.sync_hash` — MD5 dedup key
- `source` CHECK constraint includes `'tracker_sync'`

---

## File Inventory

| Path | Purpose |
|---|---|
| `scripts/sync_tracker.py` | Tracker Excel → SQL generator |
| `scripts/sync_grafana.py` | Grafana IDE → SQL generator |
| `scripts/sync_output/` | Generated SQL files (gitignored) |
| `sql/017_data_sync_phase.sql` | DB migration for sync infrastructure |
| `RefreshedData/` | Input data folder (tracker + Grafana exports) |

---

## Quick Checklist (Copy for Weekly Use)

- [ ] New tracker Excel placed in `RefreshedData/`
- [ ] New Grafana exports placed in `RefreshedData/RE_ EAS AI Adoption _ Grafana stats/`
- [ ] Run `sync_tracker.py` → check output SQL files
- [ ] Run `sync_grafana.py` → check output SQL
- [ ] Execute SQL via MCP in order: users → tasks → projects → accomplishments → grafana
- [ ] Verify row counts
- [ ] Run dedup check — clean if needed
- [ ] Note any anomalies (ERP column swap, email issues)
