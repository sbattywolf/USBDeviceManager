#!/usr/bin/env node
// Tiny benchmark: compare JSON file storage vs SQLite (if available)
const fs = require('fs');
const fsp = require('fs').promises;
const path = require('path');
const { performance } = require('perf_hooks');

const rows = Number(process.env.BENCH_ROWS || process.argv[2] || 1000);
const iterations = Number(process.env.BENCH_ITERS || process.argv[3] || 3);
const mode = (process.env.BENCH_MODE || process.argv[4] || 'both'); // json, sqlite, both

const dataDir = path.resolve(process.cwd(), 'data');
const jsonPath = path.join(dataDir, 'benchmark-fallback.json');
const sqlitePath = path.join(dataDir, 'benchmark-sqlite.db');

async function ensureDataDir() {
  await fsp.mkdir(dataDir, { recursive: true });
}

function now() { return performance.now(); }

async function runJsonPerOp(n) {
  // simulate FileStorage: load & persist per operation
  const tmp = `${jsonPath}.tmp`;
  const start = now();
  for (let i = 0; i < n; i++) {
    let data = { configs: [], logs: [], nextId: 1 };
    try {
      const raw = await fsp.readFile(jsonPath, 'utf8');
      data = JSON.parse(raw);
    } catch (e) {
      // missing -> will be created
    }

    const id = data.nextId++;
    const rec = { id, deviceId: `dev-${Date.now()}-${i}`, friendlyName: `Device ${i}`, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
    data.configs.push(rec);

    await fsp.writeFile(tmp, JSON.stringify(data, null, 2), 'utf8');
    await fsp.rename(tmp, jsonPath);
  }
  return now() - start;
}

async function runJsonBatch(n) {
  const tmp = `${jsonPath}.tmp`;
  const start = now();
  let data = { configs: [], logs: [], nextId: 1 };
  try { const raw = await fsp.readFile(jsonPath, 'utf8'); data = JSON.parse(raw); } catch (e) {}
  for (let i = 0; i < n; i++) {
    const id = data.nextId++;
    data.configs.push({ id, deviceId: `dev-b-${Date.now()}-${i}`, friendlyName: `Device B ${i}`, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() });
  }
  await fsp.writeFile(tmp, JSON.stringify(data, null, 2), 'utf8');
  await fsp.rename(tmp, jsonPath);
  return now() - start;
}

function tryRequire(name) {
  try { return require(name); } catch (e) { return null; }
}

async function runSqliteBench(n) {
  const better = tryRequire('better-sqlite3');
  if (!better) {
    console.log('SQLite provider `better-sqlite3` not found. To include SQLite in the benchmark run:');
    console.log('  npm install --save better-sqlite3');
    return null;
  }

  const Database = better;
  // remove old DB if exists
  try { await fsp.unlink(sqlitePath); } catch {}
  const db = new Database(sqlitePath);
  db.pragma('journal_mode = WAL');
  db.exec(`CREATE TABLE configs (id INTEGER PRIMARY KEY, deviceId TEXT, friendlyName TEXT, createdAt TEXT, updatedAt TEXT);`);

  // per-op inserts (no explicit transaction)
  const startPer = now();
  const insert = db.prepare('INSERT INTO configs (deviceId,friendlyName,createdAt,updatedAt) VALUES (?,?,?,?)');
  for (let i = 0; i < n; i++) {
    insert.run(`sdev-${i}`, `SDevice ${i}`, new Date().toISOString(), new Date().toISOString());
  }
  const perTime = now() - startPer;

  // batch inserts using transaction
  try { db.exec('DELETE FROM configs;'); } catch {}
  const startBatch = now();
  const insertMany = db.transaction((count) => {
    for (let i = 0; i < count; i++) insert.run(`bdev-${i}`, `BDevice ${i}`, new Date().toISOString(), new Date().toISOString());
  });
  insertMany(n);
  const batchTime = now() - startBatch;

  // reads
  const startRead = now();
  const rows = db.prepare('SELECT COUNT(*) as c FROM configs').get();
  const readTime = now() - startRead;

  db.close();
  return { perTime, batchTime, readTime, count: rows.c };
}

async function run() {
  await ensureDataDir();
  console.log(`Benchmark: rows=${rows}, iterations=${iterations}, mode=${mode}`);

  // JSON benchmarks
  if (mode === 'both' || mode === 'json') {
    console.log('\nJSON (per-operation load+persist)');
    for (let it = 0; it < iterations; it++) {
      const t = await runJsonPerOp(rows);
      console.log(`  iter ${it + 1}: per-op time ${t.toFixed(2)} ms`);
    }

    console.log('\nJSON (batch write)');
    for (let it = 0; it < iterations; it++) {
      const t = await runJsonBatch(rows);
      console.log(`  iter ${it + 1}: batch time ${t.toFixed(2)} ms`);
    }
  }

  // SQLite benchmark (if available)
  if (mode === 'both' || mode === 'sqlite') {
    console.log('\nSQLite (if better-sqlite3 installed)');
    const res = await runSqliteBench(rows);
    if (!res) {
      console.log('SQLite benchmark skipped (dependency missing)');
    } else {
      console.log(`  per-op inserts: ${res.perTime.toFixed(2)} ms`);
      console.log(`  batch inserts (transaction): ${res.batchTime.toFixed(2)} ms`);
      console.log(`  read/count: ${res.readTime.toFixed(2)} ms (rows=${res.count})`);
    }
  }

  console.log('\nBenchmark complete. Note: results vary by hardware and Node version.');
}

run().catch(err => { console.error('Benchmark error', err); process.exit(1); });
