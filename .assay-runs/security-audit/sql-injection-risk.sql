-- SQL Injection Risk Assessment
SELECT * FROM users WHERE username = 'admin' -- This query is vulnerable to SQL injection if not parameterized
AND password = 'password';