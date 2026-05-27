const fs = require("fs");
const path = require("path");
const sqlite3 = require("sqlite3").verbose();

const dataDir = path.join(__dirname, "..", "data");
fs.mkdirSync(dataDir, { recursive: true });

const db = new sqlite3.Database(path.join(dataDir, "heartlink.sqlite"));

function run(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.run(sql, params, function onRun(error) {
      if (error) {
        reject(error);
        return;
      }
      resolve({ id: this.lastID, changes: this.changes });
    });
  });
}

function get(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.get(sql, params, (error, row) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(row);
    });
  });
}

function all(sql, params = []) {
  return new Promise((resolve, reject) => {
    db.all(sql, params, (error, rows) => {
      if (error) {
        reject(error);
        return;
      }
      resolve(rows);
    });
  });
}

async function addColumnIfMissing(sql) {
  try {
    await run(sql);
  } catch (error) {
    if (!String(error.message || "").includes("duplicate column name")) {
      throw error;
    }
  }
}

async function init() {
  await run(`
    CREATE TABLE IF NOT EXISTS users (
      id TEXT PRIMARY KEY,
      code TEXT NOT NULL UNIQUE,
      display_name TEXT,
      couple_id TEXT,
      created_at TEXT NOT NULL
    )
  `);

  await addColumnIfMissing("ALTER TABLE users ADD COLUMN current_mood TEXT DEFAULT 'happy'");

  await run(`
    CREATE TABLE IF NOT EXISTS couples (
      id TEXT PRIMARY KEY,
      first_user_id TEXT NOT NULL,
      second_user_id TEXT NOT NULL,
      started_at TEXT,
      created_at TEXT NOT NULL
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS messages (
      id TEXT PRIMARY KEY,
      couple_id TEXT NOT NULL,
      sent_at TEXT NOT NULL,
      json TEXT NOT NULL
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS memories (
      id TEXT PRIMARY KEY,
      couple_id TEXT NOT NULL,
      date TEXT NOT NULL,
      json TEXT NOT NULL
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS goals (
      id TEXT PRIMARY KEY,
      couple_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      json TEXT NOT NULL
    )
  `);

  await run(`
    CREATE TABLE IF NOT EXISTS games (
      id TEXT PRIMARY KEY,
      couple_id TEXT NOT NULL,
      kind TEXT NOT NULL,
      day_key TEXT,
      json TEXT NOT NULL
    )
  `);
}

module.exports = {
  all,
  db,
  get,
  init,
  run
};
