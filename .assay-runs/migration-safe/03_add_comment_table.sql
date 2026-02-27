-- Add the Comment table
CREATE TABLE IF NOT EXISTS comments (
    id INT PRIMARY KEY AUTOINCREMENT,
    post_id INT,
    user_id INT,
    content TEXT,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (post_id) REFERENCES posts(id),
    FOREIGN KEY (user_id) REFERENCES users(id)
);