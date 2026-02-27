-- Rollback add user_profile column from users table

\set @json (SELECT jsonb_agg(row_to_json(t)) FROM (SELECT id, name FROM users) t)

UPDATE users SET user_profile = NULL;

ALTER TABLE users DROP COLUMN user_profile;
