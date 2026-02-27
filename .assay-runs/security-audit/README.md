# SQL Injection Risk Audit
## Overview
This directory contains files related to the security audit of potential SQL injection risks in the project.
## Files
- `sql-injection-risk.sql`: Demonstrates a vulnerable SQL query.
- `fix-sql-injection.sql`: Contains the fix for the identified SQL injection risk.
- `test-before.sql`: A test case that should fail before the fix is applied.
- `test-after.sql`: A test case that should pass after the fix is implemented.
## Steps to Run Tests
1. Apply the fix by executing `fix-sql-injection.sql`.
2. Execute `test-before.sql` and verify it fails as expected.
3. Execute `test-after.sql` and verify it passes indicating the fix was successful.