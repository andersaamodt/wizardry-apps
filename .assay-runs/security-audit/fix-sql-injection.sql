-- Fix for SQL Injection Risk
PREPARE stmt FROM 'SELECT * FROM users WHERE username = ? AND password = ?';
SET @username = 'admin';
SET @password = 'password';
EXECUTE stmt USING @username, @password;
DEALLOCATE PREPARE stmt;