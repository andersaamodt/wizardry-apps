-- Test for SQL Injection After Fix
PREPARE stmt FROM 'SELECT * FROM users WHERE username = ? AND password = ?';
SET @username = 'admin';
SET @password = 'password';
EXECUTE stmt USING @username, @password;
DEALLOCATE PREPARE stmt; -- This should return admin's details if the fix is implemented correctly