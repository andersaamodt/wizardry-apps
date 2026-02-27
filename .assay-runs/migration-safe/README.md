# Migration Safe Directory
This directory contains migration scripts that are designed to be run idempotently. Each script is versioned with a sequential number, ensuring that migrations can be applied multiple times without causing errors or data corruption.
## Steps to Run Migrations
1. **Backup Data**: Always back up your database before running any migrations.
2. **Run Migration Script**: Execute the migration script in ascending order based on their filenames (e.g., `03_add_comment_table.sql`, `04_add_timestamp_to_comment.sql`).
3. **Verify Changes**: Check the database schema and data integrity after each migration.
## Rollback Instructions
If a migration fails or causes issues, use the corresponding rollback script. The rollback scripts are designed to revert changes made by their respective forward migration scripts.