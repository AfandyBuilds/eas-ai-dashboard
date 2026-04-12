-- ============================================================
-- EAS AI Dashboard — Licensed Tool Tracking Migration
-- Date: April 12, 2026
-- Purpose: Track GitHub Copilot & M365 Copilot (Basic) as
--          primary licensed tools; classify all other tools
--          as community/personal-choice.
-- ============================================================

-- 1. Add a 'is_licensed' flag to the lovs table for AI tools
-- This lets the app know which tools are Ejada-paid vs user-choice
ALTER TABLE lovs ADD COLUMN IF NOT EXISTS is_licensed BOOLEAN DEFAULT false;

-- 2. Mark the two licensed tools
UPDATE lovs SET is_licensed = true WHERE category = 'aiTool' AND value = 'Github Copilot';
UPDATE lovs SET is_licensed = true WHERE category = 'aiTool' AND value = 'M365 Copilot';

-- 3. Add licensed tool activation tracking to copilot_users
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS github_copilot_status TEXT DEFAULT 'inactive';
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS m365_copilot_status TEXT DEFAULT 'inactive';
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS github_copilot_activated_at TIMESTAMPTZ;
ALTER TABLE copilot_users ADD COLUMN IF NOT EXISTS m365_copilot_activated_at TIMESTAMPTZ;

-- 4. Add an 'is_licensed_tool' generated column to tasks for easy filtering
-- Matches tasks that used Github Copilot or M365 Copilot
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_licensed_tool BOOLEAN
  GENERATED ALWAYS AS (
    LOWER(ai_tool) IN ('github copilot', 'Github Copilot', 'github copilot', 'm365 copilot', 'M365 Copilot', 'm365 Copilot')
    OR LOWER(ai_tool) LIKE '%github copilot%'
    OR LOWER(ai_tool) LIKE '%m365 copilot%'
  ) STORED;

-- 5. Index for fast licensed-tool queries
CREATE INDEX IF NOT EXISTS idx_tasks_licensed_tool ON tasks(is_licensed_tool) WHERE is_licensed_tool = true;
CREATE INDEX IF NOT EXISTS idx_copilot_users_gh_status ON copilot_users(github_copilot_status);
CREATE INDEX IF NOT EXISTS idx_copilot_users_m365_status ON copilot_users(m365_copilot_status);

-- 6. Create an RPC to get licensed tool adoption summary per practice
CREATE OR REPLACE FUNCTION get_licensed_tool_adoption(p_quarter_id TEXT DEFAULT NULL)
RETURNS TABLE(
  practice TEXT,
  licensed_users BIGINT,
  gh_copilot_active BIGINT,
  m365_copilot_active BIGINT,
  licensed_tool_tasks BIGINT,
  other_tool_tasks BIGINT,
  licensed_hours_saved NUMERIC,
  other_hours_saved NUMERIC,
  gh_copilot_tasks BIGINT,
  m365_copilot_tasks BIGINT,
  gh_copilot_hours NUMERIC,
  m365_copilot_hours NUMERIC,
  adoption_rate_licensed NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.name AS practice,
    COALESCE(cu.total_users, 0) AS licensed_users,
    COALESCE(cu.gh_active, 0) AS gh_copilot_active,
    COALESCE(cu.m365_active, 0) AS m365_copilot_active,
    COALESCE(t.licensed_tasks, 0) AS licensed_tool_tasks,
    COALESCE(t.other_tasks, 0) AS other_tool_tasks,
    COALESCE(t.licensed_saved, 0)::NUMERIC AS licensed_hours_saved,
    COALESCE(t.other_saved, 0)::NUMERIC AS other_hours_saved,
    COALESCE(t.gh_tasks, 0) AS gh_copilot_tasks,
    COALESCE(t.m365_tasks, 0) AS m365_copilot_tasks,
    COALESCE(t.gh_saved, 0)::NUMERIC AS gh_copilot_hours,
    COALESCE(t.m365_saved, 0)::NUMERIC AS m365_copilot_hours,
    CASE WHEN COALESCE(cu.total_users, 0) > 0
      THEN ROUND(
        (COALESCE(cu.gh_active, 0) + COALESCE(cu.m365_active, 0))::NUMERIC
        / cu.total_users * 100, 1
      )
      ELSE 0
    END AS adoption_rate_licensed
  FROM practices p
  LEFT JOIN (
    SELECT
      c.practice,
      COUNT(*) AS total_users,
      COUNT(*) FILTER (WHERE c.github_copilot_status = 'active') AS gh_active,
      COUNT(*) FILTER (WHERE c.m365_copilot_status = 'active') AS m365_active
    FROM copilot_users c
    GROUP BY c.practice
  ) cu ON cu.practice = p.name
  LEFT JOIN (
    SELECT
      tk.practice,
      COUNT(*) FILTER (WHERE tk.is_licensed_tool = true AND tk.approval_status = 'approved') AS licensed_tasks,
      COUNT(*) FILTER (WHERE (tk.is_licensed_tool = false OR tk.is_licensed_tool IS NULL) AND tk.approval_status = 'approved') AS other_tasks,
      SUM(CASE WHEN tk.is_licensed_tool = true AND tk.approval_status = 'approved' THEN tk.time_saved ELSE 0 END) AS licensed_saved,
      SUM(CASE WHEN (tk.is_licensed_tool = false OR tk.is_licensed_tool IS NULL) AND tk.approval_status = 'approved' THEN tk.time_saved ELSE 0 END) AS other_saved,
      COUNT(*) FILTER (WHERE LOWER(tk.ai_tool) LIKE '%github copilot%' AND tk.approval_status = 'approved') AS gh_tasks,
      COUNT(*) FILTER (WHERE LOWER(tk.ai_tool) LIKE '%m365 copilot%' AND tk.approval_status = 'approved') AS m365_tasks,
      SUM(CASE WHEN LOWER(tk.ai_tool) LIKE '%github copilot%' AND tk.approval_status = 'approved' THEN tk.time_saved ELSE 0 END) AS gh_saved,
      SUM(CASE WHEN LOWER(tk.ai_tool) LIKE '%m365 copilot%' AND tk.approval_status = 'approved' THEN tk.time_saved ELSE 0 END) AS m365_saved
    FROM tasks tk
    WHERE (p_quarter_id IS NULL OR tk.quarter_id = p_quarter_id)
    GROUP BY tk.practice
  ) t ON t.practice = p.name
  WHERE p.name != 'SE'
  ORDER BY p.name;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE
   SET search_path = public;

-- 7. Update the practice_summary view to include licensed tool breakdown
CREATE OR REPLACE VIEW practice_summary AS
SELECT
  p.name AS practice,
  p.head,
  p.spoc,
  COALESCE(t.task_count, 0) AS tasks,
  COALESCE(t.total_time_without, 0) AS time_without,
  COALESCE(t.total_time_with, 0) AS time_with,
  COALESCE(t.total_time_saved, 0) AS time_saved,
  CASE WHEN COALESCE(t.total_time_without, 0) > 0
    THEN ROUND((t.total_time_saved / t.total_time_without * 100)::numeric, 1)
    ELSE 0 END AS efficiency_pct,
  COALESCE(t.avg_quality, 0) AS avg_quality,
  COALESCE(t.completed_count, 0) AS completed,
  COALESCE(proj.project_count, 0) AS project_count,
  COALESCE(cu.licensed_users, 0) AS licensed_users,
  COALESCE(cu.active_users, 0) AS active_users,
  -- Licensed tool breakdown
  COALESCE(t.licensed_tool_tasks, 0) AS licensed_tool_tasks,
  COALESCE(t.other_tool_tasks, 0) AS other_tool_tasks,
  COALESCE(t.licensed_hours_saved, 0) AS licensed_hours_saved
FROM practices p
LEFT JOIN (
  SELECT
    practice,
    COUNT(*) AS task_count,
    SUM(time_without_ai) AS total_time_without,
    SUM(time_with_ai) AS total_time_with,
    SUM(time_without_ai - time_with_ai) AS total_time_saved,
    ROUND(AVG(NULLIF(quality_rating, 0))::numeric, 2) AS avg_quality,
    COUNT(*) FILTER (WHERE LOWER(status) = 'completed') AS completed_count,
    COUNT(*) FILTER (WHERE is_licensed_tool = true) AS licensed_tool_tasks,
    COUNT(*) FILTER (WHERE is_licensed_tool = false OR is_licensed_tool IS NULL) AS other_tool_tasks,
    SUM(CASE WHEN is_licensed_tool = true THEN time_without_ai - time_with_ai ELSE 0 END) AS licensed_hours_saved
  FROM tasks
  WHERE approval_status = 'approved'
  GROUP BY practice
) t ON t.practice = p.name
LEFT JOIN (
  SELECT practice, COUNT(DISTINCT project_name) AS project_count
  FROM projects
  GROUP BY practice
) proj ON proj.practice = p.name
LEFT JOIN (
  SELECT
    practice,
    COUNT(*) AS licensed_users,
    COUNT(*) FILTER (WHERE has_logged_task = true) AS active_users
  FROM copilot_users
  GROUP BY practice
) cu ON cu.practice = p.name;

-- 8. Grant execution permission to authenticated users
GRANT EXECUTE ON FUNCTION get_licensed_tool_adoption(TEXT) TO authenticated;
