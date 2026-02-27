-- Test for SQL Injection Before Fix
SELECT * FROM users WHERE username = 'admin' AND password = 'password'; -- This should return admin's details if the fix is not implemented