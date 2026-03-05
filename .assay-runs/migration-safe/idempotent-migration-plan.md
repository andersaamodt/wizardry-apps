# Idempotent Migration Plan for Schema Change
## Overview
This document outlines an idempotent migration plan for a realistic schema change, including rollback, observability, and release sequencing safeguards.
## Migration Details
### Phase 1: Schema Update (04_add_comment_table.sql)
- **Description**: Add a `comments` table to the database.
- **Files**:
  - `/migrations/04_add_comment_table.sql`
### Phase 2: Data Migration (05_migrate_existing_comments.sql)
- **Description**: Migrate existing comments from an old schema to the new `