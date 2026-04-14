-- 015: Add task_details column to tasks table
-- Stores additional description/details (formerly "Why is this important?")
-- This column is optional and provides context for the AI validator.

ALTER TABLE tasks
  ADD COLUMN IF NOT EXISTS task_details TEXT;

COMMENT ON COLUMN tasks.task_details IS 'Additional task description/details (optional context for AI validator)';
