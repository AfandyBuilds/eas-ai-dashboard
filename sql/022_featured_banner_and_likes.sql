-- ============================================================
-- 022_featured_banner_and_likes.sql
-- Featured Banner Spotlight + Global Likes System
-- Adds: likes table, featured_banner_config, featured_banner_pins,
--        v_banner_candidates view
-- Reuses: prompt_votes for prompt like counts
-- ============================================================

-- ===================== 1. LIKES TABLE =====================

CREATE TABLE IF NOT EXISTS likes (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_type  TEXT NOT NULL CHECK (item_type IN ('task', 'accomplishment', 'use_case')),
  item_id    UUID NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, item_type, item_id)
);

CREATE INDEX IF NOT EXISTS idx_likes_item ON likes(item_type, item_id);
CREATE INDEX IF NOT EXISTS idx_likes_user ON likes(user_id);

-- RLS
ALTER TABLE likes ENABLE ROW LEVEL SECURITY;

-- All authenticated can read (needed for counts)
CREATE POLICY likes_select ON likes
  FOR SELECT TO authenticated USING (true);

-- Users can insert their own likes
CREATE POLICY likes_insert ON likes
  FOR INSERT TO authenticated
  WITH CHECK (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1)
  );

-- Users can delete their own likes (unlike)
CREATE POLICY likes_delete ON likes
  FOR DELETE TO authenticated
  USING (
    user_id = (SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1)
  );

-- Admin full access
CREATE POLICY likes_admin_all ON likes
  FOR ALL TO authenticated
  USING (get_user_role() = 'admin')
  WITH CHECK (get_user_role() = 'admin');

-- ===================== 2. FEATURED BANNER CONFIG =====================

CREATE TABLE IF NOT EXISTS featured_banner_config (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_type   TEXT NOT NULL UNIQUE CHECK (item_type IN ('task', 'accomplishment', 'prompt', 'use_case', 'global')),
  slots       INT NOT NULL DEFAULT 3,
  is_active   BOOLEAN NOT NULL DEFAULT true,
  updated_by  UUID REFERENCES users(id),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE featured_banner_config ENABLE ROW LEVEL SECURITY;

CREATE POLICY banner_config_select ON featured_banner_config
  FOR SELECT TO authenticated USING (true);

CREATE POLICY banner_config_admin ON featured_banner_config
  FOR ALL TO authenticated
  USING (get_user_role() = 'admin')
  WITH CHECK (get_user_role() = 'admin');

-- Seed default config (total = 10)
INSERT INTO featured_banner_config (item_type, slots, is_active) VALUES
  ('global', 10, true),
  ('task', 3, true),
  ('accomplishment', 3, true),
  ('prompt', 2, true),
  ('use_case', 2, true)
ON CONFLICT (item_type) DO NOTHING;

-- ===================== 3. FEATURED BANNER PINS =====================

CREATE TABLE IF NOT EXISTS featured_banner_pins (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_type  TEXT NOT NULL CHECK (item_type IN ('task', 'accomplishment', 'prompt', 'use_case')),
  item_id    UUID NOT NULL,
  pin_label  TEXT NOT NULL DEFAULT 'Admin Pick',
  pinned_by  UUID NOT NULL REFERENCES users(id),
  pinned_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at DATE,
  UNIQUE (item_type, item_id)
);

ALTER TABLE featured_banner_pins ENABLE ROW LEVEL SECURITY;

CREATE POLICY banner_pins_select ON featured_banner_pins
  FOR SELECT TO authenticated USING (true);

CREATE POLICY banner_pins_admin ON featured_banner_pins
  FOR ALL TO authenticated
  USING (get_user_role() = 'admin')
  WITH CHECK (get_user_role() = 'admin');

CREATE POLICY banner_pins_spoc_insert ON featured_banner_pins
  FOR INSERT TO authenticated
  WITH CHECK (
    get_user_role() = 'spoc'
  );

CREATE POLICY banner_pins_spoc_delete ON featured_banner_pins
  FOR DELETE TO authenticated
  USING (
    get_user_role() = 'spoc'
    AND pinned_by = (SELECT id FROM users WHERE auth_id = auth.uid() LIMIT 1)
  );

-- ===================== 4. BANNER CANDIDATES VIEW =====================

CREATE OR REPLACE VIEW v_banner_candidates AS

-- Tasks
SELECT
  'task'::TEXT AS item_type,
  t.id AS item_id,
  t.task_description AS title,
  t.category AS subtitle,
  t.employee_name AS contributor_name,
  t.practice,
  p.department,
  t.ai_tool,
  COALESCE(t.time_saved, 0)::NUMERIC AS metric_value,
  'hrs saved' AS metric_label,
  COALESCE(ROUND(t.efficiency * 100, 1), 0)::NUMERIC AS metric_value_2,
  '% efficiency' AS metric_label_2,
  COALESCE(lk.like_count, 0)::INT AS like_count,
  pin.id IS NOT NULL AS is_pinned,
  pin.pin_label,
  t.quarter_id,
  t.created_at
FROM tasks t
JOIN practices p ON p.name = t.practice
LEFT JOIN (
  SELECT item_id, COUNT(*) AS like_count
  FROM likes WHERE item_type = 'task'
  GROUP BY item_id
) lk ON lk.item_id = t.id
LEFT JOIN featured_banner_pins pin ON pin.item_type = 'task' AND pin.item_id = t.id
  AND (pin.expires_at IS NULL OR pin.expires_at >= CURRENT_DATE)
WHERE t.approval_status = 'approved'

UNION ALL

-- Accomplishments
SELECT
  'accomplishment'::TEXT,
  a.id,
  a.title,
  a.project,
  COALESCE(a.employees, a.spoc) AS contributor_name,
  a.practice,
  p.department,
  a.ai_tool,
  COALESCE(a.effort_saved, 0)::NUMERIC,
  'hrs saved',
  0::NUMERIC,
  '',
  COALESCE(lk.like_count, 0)::INT,
  pin.id IS NOT NULL,
  pin.pin_label,
  a.quarter_id,
  a.created_at
FROM accomplishments a
JOIN practices p ON p.name = a.practice
LEFT JOIN (
  SELECT item_id, COUNT(*) AS like_count
  FROM likes WHERE item_type = 'accomplishment'
  GROUP BY item_id
) lk ON lk.item_id = a.id
LEFT JOIN featured_banner_pins pin ON pin.item_type = 'accomplishment' AND pin.item_id = a.id
  AND (pin.expires_at IS NULL OR pin.expires_at >= CURRENT_DATE)
WHERE a.approval_status = 'approved'

UNION ALL

-- Prompts (reuses prompt_votes for like counts)
SELECT
  'prompt'::TEXT,
  pl.id,
  pl.prompt_text,
  pl.category,
  COALESCE(u.name, 'System') AS contributor_name,
  COALESCE(u.practice, 'EAS'),
  COALESCE(pr.department, 'EAS'),
  pl.role_label,
  COALESCE(pl.copy_count, 0)::NUMERIC,
  'copies',
  0::NUMERIC,
  '',
  COALESCE(pv.like_count, 0)::INT,
  pin.id IS NOT NULL,
  pin.pin_label,
  NULL::TEXT AS quarter_id,
  pl.created_at
FROM prompt_library pl
LEFT JOIN auth.users au ON au.id = pl.created_by
LEFT JOIN users u ON u.auth_id = au.id
LEFT JOIN practices pr ON pr.name = u.practice
LEFT JOIN (
  SELECT prompt_id, COUNT(*) AS like_count
  FROM prompt_votes WHERE vote_type = 'like'
  GROUP BY prompt_id
) pv ON pv.prompt_id = pl.id
LEFT JOIN featured_banner_pins pin ON pin.item_type = 'prompt' AND pin.item_id = pl.id
  AND (pin.expires_at IS NULL OR pin.expires_at >= CURRENT_DATE)
WHERE pl.is_active = true

UNION ALL

-- Use Cases
SELECT
  'use_case'::TEXT,
  uc.id,
  uc.name,
  uc.category,
  COALESCE(uc.owner_spoc, 'Unknown') AS contributor_name,
  COALESCE(uc.practice, 'EAS'),
  COALESCE(p.department, 'EAS'),
  uc.ai_tools,
  COALESCE(uc.hours_saved_per_impl::NUMERIC, 0),
  'hrs saved/impl',
  0::NUMERIC,
  '',
  COALESCE(lk.like_count, 0)::INT,
  pin.id IS NOT NULL,
  pin.pin_label,
  NULL::TEXT AS quarter_id,
  uc.created_at
FROM use_cases uc
LEFT JOIN practices p ON p.name = uc.practice
LEFT JOIN (
  SELECT item_id, COUNT(*) AS like_count
  FROM likes WHERE item_type = 'use_case'
  GROUP BY item_id
) lk ON lk.item_id = uc.id
LEFT JOIN featured_banner_pins pin ON pin.item_type = 'use_case' AND pin.item_id = uc.id
  AND (pin.expires_at IS NULL OR pin.expires_at >= CURRENT_DATE)
WHERE uc.is_active = true AND uc.is_approved_reference = true;

-- ===================== 5. RPC: toggle_like =====================
-- Returns JSON: { liked, like_count }

CREATE OR REPLACE FUNCTION toggle_like(
  p_item_type TEXT,
  p_item_id UUID
)
RETURNS JSON AS $$
DECLARE
  v_user_id UUID;
  v_exists BOOLEAN;
  v_count INT;
BEGIN
  -- Get internal user id
  SELECT id INTO v_user_id FROM users WHERE auth_id = auth.uid() LIMIT 1;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'User not found';
  END IF;

  -- Check if like exists
  SELECT EXISTS(
    SELECT 1 FROM likes
    WHERE user_id = v_user_id AND item_type = p_item_type AND item_id = p_item_id
  ) INTO v_exists;

  IF v_exists THEN
    DELETE FROM likes
    WHERE user_id = v_user_id AND item_type = p_item_type AND item_id = p_item_id;
  ELSE
    INSERT INTO likes (user_id, item_type, item_id)
    VALUES (v_user_id, p_item_type, p_item_id);
  END IF;

  -- Get updated count
  SELECT COUNT(*) INTO v_count
  FROM likes WHERE item_type = p_item_type AND item_id = p_item_id;

  RETURN json_build_object(
    'liked', NOT v_exists,
    'like_count', v_count
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
   SET search_path = public;
