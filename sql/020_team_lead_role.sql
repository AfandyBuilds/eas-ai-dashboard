-- ============================================================
-- EAS AI Adoption Dashboard — Team Lead Role
-- Migration 020: Add team_lead role + member assignments
--
-- Team Leads are practice contributors promoted by their SPOC.
-- They have the same capabilities as SPOCs but scoped to a
-- subset of practice contributors assigned by the SPOC.
-- One Team Lead per contributor; one contributor → one team lead.
-- ============================================================

-- ===================== 1. ALTER CHECK CONSTRAINTS =====================

-- 1a. users.role — drop & recreate to include 'team_lead'
ALTER TABLE users DROP CONSTRAINT IF EXISTS users_role_check;
ALTER TABLE users ADD CONSTRAINT users_role_check
  CHECK (role IN ('admin', 'spoc', 'contributor', 'viewer', 'executive', 'team_lead'));

-- 1b. role_view_permissions.role — same pattern
ALTER TABLE role_view_permissions DROP CONSTRAINT IF EXISTS role_view_permissions_role_check;
ALTER TABLE role_view_permissions ADD CONSTRAINT role_view_permissions_role_check
  CHECK (role IN ('admin', 'spoc', 'contributor', 'viewer', 'executive', 'team_lead'));

-- ===================== 2. TEAM_LEAD_ASSIGNMENTS TABLE =====================

CREATE TABLE IF NOT EXISTS team_lead_assignments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_lead_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  member_email  TEXT NOT NULL,
  practice      TEXT NOT NULL REFERENCES practices(name),
  assigned_by   UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ DEFAULT now(),
  updated_at    TIMESTAMPTZ DEFAULT now(),
  UNIQUE(member_email, practice)  -- one team lead per contributor per practice
);

CREATE INDEX IF NOT EXISTS idx_tla_team_lead ON team_lead_assignments(team_lead_id);
CREATE INDEX IF NOT EXISTS idx_tla_member ON team_lead_assignments(member_email);
CREATE INDEX IF NOT EXISTS idx_tla_practice ON team_lead_assignments(practice);

COMMENT ON TABLE team_lead_assignments IS
  'Maps team lead users to the practice contributors they manage. '
  'Each contributor can only have one team lead within a practice. '
  'Assigned by the SPOC of that practice.';

-- ===================== 3. RLS ON TEAM_LEAD_ASSIGNMENTS =====================

ALTER TABLE team_lead_assignments ENABLE ROW LEVEL SECURITY;

-- Admin: full access
CREATE POLICY "tla_admin_all"
  ON team_lead_assignments FOR ALL
  USING (get_user_role() = 'admin');

-- SPOC: full access for own practice (they manage team lead assignments)
CREATE POLICY "tla_spoc_all"
  ON team_lead_assignments FOR ALL
  USING (get_user_role() = 'spoc' AND practice = get_user_practice())
  WITH CHECK (get_user_role() = 'spoc' AND practice = get_user_practice());

-- Team Leads: read their own assignments
CREATE POLICY "tla_team_lead_read"
  ON team_lead_assignments FOR SELECT
  USING (
    get_user_role() = 'team_lead'
    AND team_lead_id = (SELECT id FROM users WHERE auth_id = auth.uid())
  );

-- All authenticated users can read (for UI display purposes)
CREATE POLICY "tla_read_all"
  ON team_lead_assignments FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- ===================== 4. HELPER FUNCTIONS =====================

-- Get current user's ID from users table
CREATE OR REPLACE FUNCTION get_current_user_id()
RETURNS UUID AS $$
  SELECT id FROM public.users WHERE auth_id = auth.uid() LIMIT 1;
$$ LANGUAGE sql SECURITY DEFINER STABLE
   SET search_path = public;

-- Get emails of members assigned to the current team lead
CREATE OR REPLACE FUNCTION get_team_lead_members()
RETURNS TEXT[] AS $$
  SELECT COALESCE(
    array_agg(member_email),
    ARRAY[]::TEXT[]
  )
  FROM team_lead_assignments
  WHERE team_lead_id = (SELECT id FROM users WHERE auth_id = auth.uid());
$$ LANGUAGE sql SECURITY DEFINER STABLE
   SET search_path = public;

-- ===================== 5. UPDATE RLS POLICIES FOR TEAM LEAD =====================

-- ---- TASKS: team_lead can write for assigned members ----
CREATE POLICY "tasks_team_lead_insert" ON tasks FOR INSERT WITH CHECK (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
  AND employee_email = ANY(get_team_lead_members())
);

CREATE POLICY "tasks_team_lead_update" ON tasks FOR UPDATE USING (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
  AND employee_email = ANY(get_team_lead_members())
);

CREATE POLICY "tasks_team_lead_delete" ON tasks FOR DELETE USING (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
  AND employee_email = ANY(get_team_lead_members())
);

-- ---- ACCOMPLISHMENTS: team_lead can write for assigned members ----
CREATE POLICY "acc_team_lead_insert" ON accomplishments FOR INSERT WITH CHECK (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
);

CREATE POLICY "acc_team_lead_update" ON accomplishments FOR UPDATE USING (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
);

-- ---- SUBMISSION APPROVALS: team_lead can approve for their members ----
CREATE POLICY "submission_approvals_team_lead_update" ON submission_approvals FOR UPDATE USING (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
  AND submitted_by_email = ANY(get_team_lead_members())
);

CREATE POLICY "submission_approvals_team_lead_insert" ON submission_approvals FOR INSERT WITH CHECK (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
);

-- ---- COPILOT USERS: team_lead can manage for their practice ----
CREATE POLICY "copilot_team_lead_update" ON copilot_users FOR UPDATE USING (
  get_user_role() = 'team_lead'
  AND practice = get_user_practice()
);

-- ===================== 6. UPDATED_AT TRIGGER =====================

CREATE TRIGGER trg_team_lead_assignments_updated_at
  BEFORE UPDATE ON team_lead_assignments
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ===================== 7. SEED VIEW PERMISSIONS =====================

-- Team Lead gets same views as SPOC (My Practice, Approvals, etc.)
INSERT INTO role_view_permissions (role, view_key, label, is_visible) VALUES
  ('team_lead', 'web.dashboard',        'Dashboard',           true),
  ('team_lead', 'web.leaderboard',      'Leaderboard',         true),
  ('team_lead', 'web.exec_summary',     'Executive Summary',   false),
  ('team_lead', 'web.mypractice',       'My Practice',         true),
  ('team_lead', 'web.practices',        'All Practices',       false),
  ('team_lead', 'web.tasks',            'All Tasks',           true),
  ('team_lead', 'web.mytasks',          'My Tasks',            false),
  ('team_lead', 'web.accomplishments',  'Accomplishments',     true),
  ('team_lead', 'web.approvals',        'Approvals',           true),
  ('team_lead', 'web.copilot',          'Licensed AI Users',   true),
  ('team_lead', 'web.projects',         'Projects',            true),
  ('team_lead', 'web.usecases',         'Use Case Library',    true),
  ('team_lead', 'web.prompts',          'Prompt Library',      true),
  ('team_lead', 'web.skills',           'Skills Library',      true),
  ('team_lead', 'web.guidelines',       'Guidelines',          true),
  ('team_lead', 'web.enablement',       'Copilot Enablement',  true),
  ('team_lead', 'web.ainews',           'AI News',             true),
  ('team_lead', 'web.vscode',           'VS Code Extension',   true),
  ('team_lead', 'web.ide_usage',        'IDE Usage Stats',     true),
  ('team_lead', 'web.issues',           'Issues / Blockers',   true)
ON CONFLICT (role, view_key) DO NOTHING;

-- Extension views for team_lead (same as SPOC)
INSERT INTO role_view_permissions (role, view_key, label, is_visible) VALUES
  ('team_lead', 'ext.tab_log_task',    'Log Task Tab',         true),
  ('team_lead', 'ext.tab_my_tasks',    'My Tasks Tab',         true),
  ('team_lead', 'ext.context_banner',  'Context Banner',       true),
  ('team_lead', 'ext.quick_log',       'Quick Log Command',    true),
  ('team_lead', 'ext.advanced_fields', 'Advanced Fields',      true),
  ('team_lead', 'ext.time_tracking',   'Time Tracking Fields', true),
  ('team_lead', 'ext.quality_rating',  'Quality Rating',       true),
  ('team_lead', 'ext.project_select',  'Project Selection',    true)
ON CONFLICT (role, view_key) DO NOTHING;
