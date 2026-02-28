#!/bin/bash
# This script performs an idempotent migration for a realistic schema change.

# Migration steps:
# 1. Add new column to table
# 2. Update default value of existing column
# 3. Rename old column (if applicable)

# Execute migration
psql -h localhost -U your_user -d your_database -f migrate.sql

# Rollback script can be provided if necessary
