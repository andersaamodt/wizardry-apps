-- Rollback add user_preferences column from users table

ALTER TABLE users DROP COLUMN user_preferences;
