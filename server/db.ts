
import pg from 'pg';
import { drizzle } from 'drizzle-orm/node-postgres';

// Resolve shared schema. Prefer path alias when available, fall back to relative path for tests.
let schema: any;
try {
  // runtime alias used in build or TS path mapping
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  schema = require('@shared/schema');
} catch (e) {
  // fallback to workspace relative path
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  schema = require('../shared/schema');
}

let dbVar: any = null;

if (process.env.DATABASE_URL) {
  const { Pool } = pg;
  const pool = new Pool({ connectionString: process.env.DATABASE_URL });
  dbVar = drizzle(pool, { schema });
} else {
  // No DATABASE_URL: Postgres not configured. Storage will use file-fallback.
  console.warn('DATABASE_URL not set; Postgres disabled. Using fallback storage.');
}

export const db = dbVar;
