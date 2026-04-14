-- Migration 014: Fix spoc_id linkage in submission_approvals
-- Date: 2026-04-14
-- Issue: All submission_approvals records have spoc_id = NULL because the
--        practice_spoc table was originally seeded with only spoc_name (no spoc_id).
--        The spoc_id was populated later, but existing approval records were never backfilled.
--        This causes SPOCs to see zero pending approvals because fetchPendingApprovals
--        filters on spoc_id = <user_id> which never matches NULL.

-- 1. Backfill spoc_id on ALL submission_approvals from practice_spoc lookup
UPDATE submission_approvals sa
SET spoc_id = ps.spoc_id
FROM practice_spoc ps
WHERE ps.practice = sa.practice
  AND ps.is_active = true
  AND ps.spoc_id IS NOT NULL
  AND sa.spoc_id IS NULL;

-- 2. Also ensure approval_layer is 'spoc' for records that are in spoc_review
--    but had approval_layer stuck on 'ai' from the old routing logic
UPDATE submission_approvals
SET approval_layer = 'spoc'
WHERE approval_status = 'spoc_review'
  AND approval_layer != 'spoc';

-- 3. Verify the fix — expect zero rows with null spoc_id where practice_spoc exists
-- SELECT sa.id, sa.practice, sa.spoc_id, sa.approval_status
-- FROM submission_approvals sa
-- JOIN practice_spoc ps ON ps.practice = sa.practice AND ps.is_active = true
-- WHERE sa.spoc_id IS NULL;
