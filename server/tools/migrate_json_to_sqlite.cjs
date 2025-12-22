#!/usr/bin/env node
// Migrate data/fallback-db.json -> SQLite (better-sqlite3)
const fs = require('fs').promises;
const path = require('path');
const { existsSync } = require('fs');

function tryRequire(name) {
  try { return require(name); } catch (e) { return null; }
}

async function run() {
  const better = tryRequire('better-sqlite3');
  if (!better) {
    console.error('better-sqlite3 is not installed. Run: npm install --save better-sqlite3');
    process.exit(2);
  }
  const dataPath = path.resolve(process.cwd(), 'data', 'fallback-db.json');
  if (!existsSync(dataPath)) {
    console.error('JSON fallback file not found at', dataPath);
    process.exit(1);
  }
  const raw = await fs.readFile(dataPath, 'utf8');
  const data = JSON.parse(raw || '{}');
  const configs = data.configs || [];
  const logs = data.logs || [];

  const dbPath = path.resolve(process.cwd(), 'data', 'fallback.db');
  const Database = better;
  const db = new Database(dbPath);
  db.pragma('journal_mode = WAL');
  db.exec(`CREATE TABLE IF NOT EXISTS configs (id INTEGER PRIMARY KEY, deviceId TEXT, friendlyName TEXT, isEnabled INTEGER, triggerPath TEXT, triggerParams TEXT, runSilently INTEGER, forceMinimize INTEGER, createdAt TEXT, updatedAt TEXT)`);
  db.exec(`CREATE TABLE IF NOT EXISTS logs (id INTEGER PRIMARY KEY, deviceId TEXT, friendlyName TEXT, eventType TEXT, actionTaken TEXT, details TEXT, timestamp TEXT)`);

  const insertCfg = db.prepare('INSERT OR REPLACE INTO configs (id,deviceId,friendlyName,isEnabled,triggerPath,triggerParams,runSilently,forceMinimize,createdAt,updatedAt) VALUES (?,?,?,?,?,?,?,?,?,?)');
  const insertLog = db.prepare('INSERT OR REPLACE INTO logs (id,deviceId,friendlyName,eventType,actionTaken,details,timestamp) VALUES (?,?,?,?,?,?,?)');

  const insertCfgMany = db.transaction((rows) => {
    for (const r of rows) {
      insertCfg.run(r.id || null, r.deviceId || null, r.friendlyName || null, r.isEnabled ? 1 : 0, r.triggerPath || null, r.triggerParams || '', r.runSilently ? 1 : 0, r.forceMinimize ? 1 : 0, r.createdAt || new Date().toISOString(), r.updatedAt || new Date().toISOString());
    }
  });

  const insertLogMany = db.transaction((rows) => {
    for (const r of rows) {
      insertLog.run(r.id || null, r.deviceId || null, r.friendlyName || null, r.eventType || null, r.actionTaken || null, r.details || '', r.timestamp || new Date().toISOString());
    }
  });

  insertCfgMany(configs);
  insertLogMany(logs);

  console.log(`Migrated ${configs.length} configs and ${logs.length} logs to ${dbPath}`);
  db.close();
}

run().catch(err => { console.error(err); process.exit(1); });
