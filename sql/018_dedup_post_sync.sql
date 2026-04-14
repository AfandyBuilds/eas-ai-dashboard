-- ============================================================
-- Migration 018: Deduplicate Records Post-Sync
-- Applied: 2026-04-15 via Supabase MCP
-- ============================================================
-- Context: After Phase 11 data sync, web-sourced records overlapped
-- with tracker_sync records. This migration removes duplicates,
-- keeping the tracker_sync version (more complete, has sync_hash).
-- ============================================================

-- 1. DELETE duplicate TASKS (37 rows removed)
--    Pattern: web+tracker_sync overlap on (practice, employee_name, week_number, task_description)
--    Keep: tracker_sync record (has sync_hash, more complete data)
DELETE FROM tasks
WHERE source = 'web'
  AND id IN (
    SELECT t.id
    FROM tasks t
    WHERE t.source = 'web'
      AND EXISTS (
        SELECT 1 FROM tasks t2
        WHERE t2.source = 'tracker_sync'
          AND t2.practice = t.practice
          AND t2.employee_name = t.employee_name
          AND t2.week_number = t.week_number
          AND t2.task_description = t.task_description
      )
  );

-- 2. DELETE duplicate PROJECTS (21 rows removed)
--    Pattern: old records (sync_hash NULL) + tracker_sync records (has sync_hash)
--    Keep: record with sync_hash
DELETE FROM projects
WHERE sync_hash IS NULL
  AND id IN (
    SELECT p.id
    FROM projects p
    WHERE p.sync_hash IS NULL
      AND EXISTS (
        SELECT 1 FROM projects p2
        WHERE p2.sync_hash IS NOT NULL
          AND p2.practice = p.practice
          AND LOWER(TRIM(p2.project_name)) = LOWER(TRIM(p.project_name))
          AND p2.project_code = p.project_code
      )
  );

-- 3. DELETE orphaned/duplicate submission_approvals (3 rows removed)
--    - admin_review dupe for pair (keep approved version)
--    - test record with submission_id 00000000-0000-0000-0000-000000000001
--    - truly orphaned approval (task points to different approval_id)
-- (Applied via specific ID deletion)

-- 4. FIX orphaned approval linkage
--    Task ac5c7ed2 had null approval_id but approval 03944f90 referenced it
UPDATE tasks SET approval_id = '03944f90-66f8-4c04-b2f6-e3748d497cf5'
WHERE id = 'ac5c7ed2-56ce-4d5f-a40a-2e8aed84ba7f' AND approval_id IS NULL;

-- 5. Activity log: 26 activity_log entries appear duplicate by (user_id, action, details, date)
--    but have different timestamps — these are genuine repeated user actions (re-clicks).
--    Decision: KEEP as-is (audit trail).

-- ============================================================
-- POST-DEDUP VERIFICATION
-- tasks:           94 -> 57  (37 removed, 0 remaining dupes)
-- projects:        49 -> 28  (21 removed, 0 remaining dupes)
-- copilot_users:   171       (0 dupes - email unique constraint)
-- accomplishments: 9         (0 dupes)
-- sub_approvals:   13 -> 10  (3 removed, 0 remaining dupes)
-- activity_log:    87        (kept as-is)
-- ============================================================
