-- Add user_preferences column to users table

ALTER TABLE users ADD COLUMN user_preferences JSONB;
