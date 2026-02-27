-- Add user_profile column to users table

ALTER TABLE users ADD COLUMN user_profile JSONB;

\copy (SELECT jsonb_build_object('id', id, 'name', name) FROM users) TO '/tmp/user_profiles.json';

UPDATE users SET user_profile = (@json::JSONB);

\set @json NULL
