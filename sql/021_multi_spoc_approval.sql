-- ============================================================
-- EAS AI Adoption Dashboard — Multi-SPOC Approval per Practice
-- Migration: Allow multiple SPOCs per practice, any SPOC can approve
-- ============================================================

-- 1. Remove the old UNIQUE(practice) constraint on practice_spoc
--    so multiple SPOCs can be assigned to the same practice.
ALTER TABLE practice_spoc DROP CONSTRAINT IF EXISTS practice_spoc_practice_key;

-- 2. Add a unique constraint on (practice, spoc_id) to prevent
--    the same user being assigned twice to the same practice.
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'practice_spoc_practice_spoc_id_key'
  ) THEN
    ALTER TABLE practice_spoc
      ADD CONSTRAINT practice_spoc_practice_spoc_id_key UNIQUE (practice, spoc_id);
  END IF;
END $$;

-- 3. Add a composite index for fast lookup of active SPOCs per practice.
CREATE INDEX IF NOT EXISTS idx_practice_spoc_active
  ON practice_spoc (practice, is_active) WHERE is_active = true;

-- 4. Update the employee_task_approvals view to include SPOC names
--    for the "Pending With" column. We aggregate all active SPOCs
--    for the task's practice into a comma-separated list.
DROP VIEW IF EXISTS employee_task_approvals;
CREATE VIEW employee_task_approvals AS
SELECT
  t.id AS task_id,
  t.employee_name,
  t.employee_email,
  t.task_description,
  t.practice,
  t.time_saved,
  t.approval_status,
  sa.approval_layer,
  sa.spoc_id,
  sa.admin_id,
  sa.approved_by_name,
  sa.submitted_at,
  sa.approved_at,
  sa.rejection_reason,
  CASE
    WHEN t.approval_status = 'approved' THEN 'Approved'
    WHEN t.approval_status = 'rejected' THEN 'Rejected'
    WHEN t.approval_status = 'pending' AND sa.saved_hours >= 15 THEN 'Pending Admin Approval'
    WHEN t.approval_status = 'ai_review' THEN 'Pending AI Review'
    WHEN t.approval_status = 'spoc_review' THEN 'Pending SPOC Review'
    WHEN t.approval_status = 'admin_review' THEN 'Pending Admin Review'
    ELSE 'Pending'
  END AS status_display,
  CASE
    WHEN t.approval_status IN ('pending', 'ai_review', 'spoc_review', 'admin_review') THEN TRUE
    ELSE FALSE
  END AS is_pending,
  -- Aggregate active SPOC names for the practice
  (
    SELECT string_agg(ps.spoc_name, ', ' ORDER BY ps.spoc_name)
    FROM practice_spoc ps
    WHERE ps.practice = t.practice AND ps.is_active = true
  ) AS pending_spoc_names
FROM tasks t
LEFT JOIN submission_approvals sa ON sa.id = t.approval_id
ORDER BY t.created_at DESC;

-- 5. Update the pending_approvals view (used by admin dashboard)
DROP VIEW IF EXISTS pending_approvals;
CREATE VIEW pending_approvals AS
SELECT
  sa.id,
  sa.submission_type,
  sa.submission_id,
  sa.approval_status,
  sa.approval_layer,
  sa.saved_hours,
  sa.practice,
  sa.submitted_by_email,
  sa.spoc_id,
  sa.admin_id,
  CASE
    WHEN sa.approval_status = 'pending' AND sa.saved_hours >= 15 THEN 'admin'
    WHEN sa.approval_status = 'ai_review' THEN 'ai'
    WHEN sa.approval_status = 'spoc_review' THEN 'spoc'
    WHEN sa.approval_status = 'admin_review' THEN 'admin'
    ELSE NULL
  END AS awaiting_from,
  sa.submitted_at,
  sa.created_at,
  -- Show SPOC names pending with
  (
    SELECT string_agg(ps.spoc_name, ', ' ORDER BY ps.spoc_name)
    FROM practice_spoc ps
    WHERE ps.practice = sa.practice AND ps.is_active = true
  ) AS pending_spoc_names
FROM submission_approvals sa
WHERE sa.approval_status NOT IN ('approved', 'rejected')
ORDER BY sa.saved_hours DESC, sa.submitted_at ASC;

-- 6. Update SPOC workload view to handle multiple SPOCs per practice
DROP VIEW IF EXISTS spoc_approval_workload;
CREATE VIEW spoc_approval_workload AS
SELECT
  ps.spoc_id,
  ps.spoc_name,
  ps.practice,
  COALESCE(COUNT(CASE WHEN sa.approval_status = 'spoc_review' THEN 1 END), 0) AS pending_review,
  COALESCE(COUNT(CASE WHEN sa.approval_status NOT IN ('pending', 'ai_review') THEN 1 END), 0) AS total_reviewed,
  COALESCE(
    AVG(EXTRACT(EPOCH FROM (COALESCE(sa.spoc_reviewed_at, now()) - sa.submitted_at)) / 3600),
    0
  ) AS avg_review_hours
FROM practice_spoc ps
LEFT JOIN submission_approvals sa
  ON sa.practice = ps.practice
  AND (sa.spoc_id = ps.spoc_id OR sa.approval_status = 'spoc_review')
WHERE ps.is_active = true
GROUP BY ps.spoc_id, ps.spoc_name, ps.practice;
