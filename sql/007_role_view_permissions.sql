-- ============================================================
-- EAS AI Adoption Dashboard — Role-Based View Permissions
-- Migration 007: Sidebar & UI view visibility per role
--
-- Approach: deny-list — all views default to VISIBLE (is_visible = true).
-- Admins toggle is_visible = false to hide specific views for a role.
-- ============================================================

-- ===================== TABLE =====================

CREATE TABLE role_view_permissions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  role        TEXT NOT NULL CHECK (role IN ('admin', 'spoc', 'contributor', 'viewer')),
  view_key    TEXT NOT NULL,
  label       TEXT NOT NULL DEFAULT '',
  is_visible  BOOLEAN NOT NULL DEFAULT true,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now(),
  UNIQUE(role, view_key)
);

COMMENT ON TABLE role_view_permissions IS
  'Controls which sidebar/UI sections each role can see. Deny-list: default visible, toggle false to hide.';

-- ===================== INDEX =====================

CREATE INDEX idx_rvp_role ON role_view_permissions(role);

-- ===================== UPDATED_AT TRIGGER =====================

CREATE TRIGGER trg_rvp_updated_at
  BEFORE UPDATE ON role_view_permissions
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ===================== ROW-LEVEL SECURITY =====================

ALTER TABLE role_view_permissions ENABLE ROW LEVEL SECURITY;

-- Any authenticated user can read permissions (extension & dashboard need this)
CREATE POLICY "rvp_read_authenticated"
  ON role_view_permissions FOR SELECT
  USING (auth.uid() IS NOT NULL);

-- Only admins can modify permissions
CREATE POLICY "rvp_admin_write"
  ON role_view_permissions FOR ALL
  USING (get_user_role() = 'admin');

-- ===================== HELPER FUNCTION =====================

-- Returns a JSON object { "view_key": true/false, ... } for a given role
CREATE OR REPLACE FUNCTION get_role_permissions(p_role TEXT)
RETURNS JSONB AS $$
  SELECT COALESCE(
    jsonb_object_agg(view_key, is_visible),
    '{}'::jsonb
  )
  FROM role_view_permissions
  WHERE role = p_role;
$$ LANGUAGE sql SECURITY DEFINER STABLE
   SET search_path = public;

-- ===================== SEED DATA =====================
-- 4 roles × 8 view keys = 32 rows, all visible by default

INSERT INTO role_view_permissions (role, view_key, label, is_visible) VALUES
  -- Admin
  ('admin', 'ext.tab_log_task',    'Log Task Tab',         true),
  ('admin', 'ext.tab_my_tasks',    'My Tasks Tab',         true),
  ('admin', 'ext.context_banner',  'Context Banner',       true),
  ('admin', 'ext.quick_log',       'Quick Log Command',    true),
  ('admin', 'ext.advanced_fields', 'Advanced Fields',      true),
  ('admin', 'ext.time_tracking',   'Time Tracking Fields', true),
  ('admin', 'ext.quality_rating',  'Quality Rating',       true),
  ('admin', 'ext.project_select',  'Project Selection',    true),

  -- SPOC
  ('spoc', 'ext.tab_log_task',    'Log Task Tab',         true),
  ('spoc', 'ext.tab_my_tasks',    'My Tasks Tab',         true),
  ('spoc', 'ext.context_banner',  'Context Banner',       true),
  ('spoc', 'ext.quick_log',       'Quick Log Command',    true),
  ('spoc', 'ext.advanced_fields', 'Advanced Fields',      true),
  ('spoc', 'ext.time_tracking',   'Time Tracking Fields', true),
  ('spoc', 'ext.quality_rating',  'Quality Rating',       true),
  ('spoc', 'ext.project_select',  'Project Selection',    true),

  -- Contributor
  ('contributor', 'ext.tab_log_task',    'Log Task Tab',         true),
  ('contributor', 'ext.tab_my_tasks',    'My Tasks Tab',         true),
  ('contributor', 'ext.context_banner',  'Context Banner',       true),
  ('contributor', 'ext.quick_log',       'Quick Log Command',    true),
  ('contributor', 'ext.advanced_fields', 'Advanced Fields',      true),
  ('contributor', 'ext.time_tracking',   'Time Tracking Fields', true),
  ('contributor', 'ext.quality_rating',  'Quality Rating',       true),
  ('contributor', 'ext.project_select',  'Project Selection',    true),

  -- Viewer
  ('viewer', 'ext.tab_log_task',    'Log Task Tab',         true),
  ('viewer', 'ext.tab_my_tasks',    'My Tasks Tab',         true),
  ('viewer', 'ext.context_banner',  'Context Banner',       true),
  ('viewer', 'ext.quick_log',       'Quick Log Command',    true),
  ('viewer', 'ext.advanced_fields', 'Advanced Fields',      true),
  ('viewer', 'ext.time_tracking',   'Time Tracking Fields', true),
  ('viewer', 'ext.quality_rating',  'Quality Rating',       true),
  ('viewer', 'ext.project_select',  'Project Selection',    true)
ON CONFLICT (role, view_key) DO NOTHING;
