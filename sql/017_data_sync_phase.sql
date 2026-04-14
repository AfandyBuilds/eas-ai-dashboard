-- ============================================================
-- EAS AI Dashboard — Data Sync Phase Migration
-- Date: April 14, 2026
-- Purpose: Add Grafana IDE usage columns to copilot_users,
--          add sync tracking columns for recurring data sync
-- ============================================================

-- 1. Grafana IDE usage aggregate columns on copilot_users
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_days_active INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_total_interactions INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_code_generations INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_code_acceptances INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_agent_days INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_chat_days INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_loc_suggested INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_loc_added INT DEFAULT 0;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_last_active_date DATE;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_data_period TEXT;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS ide_data_updated_at TIMESTAMPTZ;

-- 2. Generated username column for Grafana user_login matching
--    e.g. 'oibrahim@ejada.com' → 'oibrahim'
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS username TEXT
  GENERATED ALWAYS AS (LOWER(SPLIT_PART(email, '@', 1))) STORED;

CREATE INDEX IF NOT EXISTS idx_copilot_users_username ON copilot_users(username);

-- 3. Sync tracking metadata
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS sync_source TEXT DEFAULT 'manual';
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS last_synced_at TIMESTAMPTZ;

-- 4. Sync hash on tasks/accomplishments/projects for idempotent re-imports
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS sync_hash TEXT;
ALTER TABLE accomplishments ADD COLUMN IF NOT EXISTS sync_hash TEXT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS sync_hash TEXT;

-- 5. Normalize emails and add unique constraint for upsert
UPDATE copilot_users SET email = LOWER(TRIM(email)) WHERE email != LOWER(TRIM(email));
ALTER TABLE copilot_users ADD CONSTRAINT copilot_users_email_unique UNIQUE (email);

-- 6. Unique partial indexes on sync_hash for ON CONFLICT upserts
CREATE UNIQUE INDEX IF NOT EXISTS idx_tasks_sync_hash ON tasks(sync_hash) WHERE sync_hash IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_projects_sync_hash ON projects(sync_hash) WHERE sync_hash IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_accomplishments_sync_hash ON accomplishments(sync_hash) WHERE sync_hash IS NOT NULL;

-- 7. Extend source check constraints to allow 'tracker_sync' value
ALTER TABLE tasks DROP CONSTRAINT IF EXISTS tasks_source_check;
ALTER TABLE tasks ADD CONSTRAINT tasks_source_check CHECK (source IN ('web', 'ide', 'api', 'tracker_sync'));

ALTER TABLE accomplishments DROP CONSTRAINT IF EXISTS accomplishments_source_check;
ALTER TABLE accomplishments ADD CONSTRAINT accomplishments_source_check CHECK (source IN ('web', 'ide', 'api', 'tracker_sync'));
