-- Test Script for SQL Injection Protection
-- Initial state of the database
SELECT * FROM users;
SELECT * FROM posts;
-- Attempt to inject harmful SQL
INSERT INTO comments (user_id, text) VALUES (1, 'DROP TABLE users');
UPDATE posts SET content = 'DELETE FROM posts WHERE id = 1';
-- Post-protection check
SELECT * FROM users;
SELECT * FROM posts;