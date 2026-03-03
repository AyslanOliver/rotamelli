-- D1 migration: create users table
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT,
  email TEXT UNIQUE,
  role TEXT,
  active INTEGER DEFAULT 1,
  pinHash TEXT
);
