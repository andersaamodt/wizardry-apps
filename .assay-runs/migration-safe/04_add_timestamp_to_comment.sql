CREATE TABLE IF NOT EXISTS comments_with_timestamp (
    id SERIAL PRIMARY KEY,
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
ALTER TABLE comments RENAME TO comments_without_timestamp;
UPDATE comments_with_timestamp AS new_table
SET updated_at = old_table.updated_at
FROM (
    SELECT id, updated_at FROM comments_without_timestamp
) AS old_table
WHERE new_table.id = old_table.id;
DROP TABLE IF EXISTS comments_without_timestamp;