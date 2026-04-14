-- ============================================================
-- 012_cleanup_duplicates.sql
-- One-time cleanup: remove duplicate tasks, accomplishments,
-- and orphaned submission_approvals created by the closeModal bug.
-- Run via Supabase MCP or SQL Editor.
-- ============================================================

BEGIN;

-- 1. Remove duplicate tasks
--    Duplicates = same employee_email + task_description + created within 5 seconds
--    Keep the LATEST row per group (max id or max created_at)
WITH task_dupes AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY employee_email, task_description,
                        date_trunc('minute', created_at)
           ORDER BY created_at DESC
         ) AS rn
  FROM tasks
  WHERE employee_email IS NOT NULL
    AND task_description IS NOT NULL
)
DELETE FROM tasks
WHERE id IN (
  SELECT id FROM task_dupes WHERE rn > 1
);

DO $$
DECLARE
  deleted_tasks INT;
BEGIN
  GET DIAGNOSTICS deleted_tasks = ROW_COUNT;
  RAISE NOTICE 'Cleaned up % duplicate task(s)', deleted_tasks;
END $$;

-- 2. Remove duplicate accomplishments
--    Duplicates = same title + practice + created within the same minute
WITH acc_dupes AS (
  SELECT id,
         ROW_NUMBER() OVER (
           PARTITION BY title, practice,
                        date_trunc('minute', created_at)
           ORDER BY created_at DESC
         ) AS rn
  FROM accomplishments
  WHERE title IS NOT NULL
    AND practice IS NOT NULL
)
DELETE FROM accomplishments
WHERE id IN (
  SELECT id FROM acc_dupes WHERE rn > 1
);

DO $$
DECLARE
  deleted_accs INT;
BEGIN
  GET DIAGNOSTICS deleted_accs = ROW_COUNT;
  RAISE NOTICE 'Cleaned up % duplicate accomplishment(s)', deleted_accs;
END $$;

-- 3. Remove orphaned submission_approvals
--    An approval is orphaned if:
--    a) Its submission_id no longer exists in the corresponding table
--    b) The task/accomplishment points to a different approval_id
DELETE FROM submission_approvals sa
WHERE NOT EXISTS (
  SELECT 1 FROM tasks t
  WHERE t.id = sa.submission_id
    AND sa.submission_type = 'task'
)
AND NOT EXISTS (
  SELECT 1 FROM accomplishments a
  WHERE a.id = sa.submission_id
    AND sa.submission_type = 'accomplishment'
);

DO $$
DECLARE
  deleted_orphans INT;
BEGIN
  GET DIAGNOSTICS deleted_orphans = ROW_COUNT;
  RAISE NOTICE 'Cleaned up % orphaned submission_approval(s)', deleted_orphans;
END $$;

-- 4. Remove approvals where the parent row points to a different approval_id
DELETE FROM submission_approvals sa
WHERE sa.submission_type = 'task'
  AND EXISTS (
    SELECT 1 FROM tasks t
    WHERE t.id = sa.submission_id
      AND t.approval_id IS NOT NULL
      AND t.approval_id != sa.id
  );

DELETE FROM submission_approvals sa
WHERE sa.submission_type = 'accomplishment'
  AND EXISTS (
    SELECT 1 FROM accomplishments a
    WHERE a.id = sa.submission_id
      AND a.approval_id IS NOT NULL
      AND a.approval_id != sa.id
  );

COMMIT;
