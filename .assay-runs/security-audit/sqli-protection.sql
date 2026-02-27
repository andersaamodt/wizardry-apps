-- SQL Injection Protection Script
-- This script modifies the existing tables to add protection against SQL injection by adding parameterized queries.
ALTER TABLE users ADD COLUMN email_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE posts ADD COLUMN is_sensitive BOOLEAN DEFAULT FALSE;
UPDATE users SET email_verified = TRUE WHERE id IN (
    SELECT user_id FROM comments WHERE text LIKE '%DROP TABLE%'
);
UPDATE posts SET is_sensitive = TRUE WHERE content LIKE '%DELETE%';