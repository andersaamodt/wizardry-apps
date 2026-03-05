const db = require('../db');
async function migrateUsersToNewTable() {
  try {
    await db.query('BEGIN');
    // Fetch users from the old table
    const oldUsers = await db.query('SELECT * FROM users_old');
    // Insert users into the new table
    for (let user of oldUsers) {
      await db.query('INSERT INTO users_new SET ?', user);
    }
    // Drop the old table
    await db.query('DROP TABLE users_old');
    await db.query('COMMIT');
    console.log('User migration completed