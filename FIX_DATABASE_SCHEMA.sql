-- Fix for missing s3key column in attachments table
-- This script adds the missing column that the application expects

-- Check if column exists first (PostgreSQL syntax)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_name = 'attachments'
        AND column_name = 's3key'
    ) THEN
        ALTER TABLE attachments
        ADD COLUMN s3key VARCHAR(255);

        RAISE NOTICE 'Successfully added s3key column to attachments table';
    ELSE
        RAISE NOTICE 's3key column already exists in attachments table';
    END IF;
END $$;

-- Verify the schema
SELECT
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'attachments'
ORDER BY ordinal_position;
