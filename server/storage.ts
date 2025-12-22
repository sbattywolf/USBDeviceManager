
import { usbConfigs, usbLogs, type UsbConfig, type InsertUsbConfig, type UsbLog, type InsertUsbLog } from "../shared/schema";
import fs from 'fs/promises';
import path from 'path';

export interface IStorage {
  getConfigs(): Promise<UsbConfig[]>;
  getConfig(id: number): Promise<UsbConfig | undefined>;
  getConfigByDeviceId(deviceId: string): Promise<UsbConfig | undefined>;
  createConfig(config: InsertUsbConfig): Promise<UsbConfig>;
  updateConfig(id: number, config: Partial<InsertUsbConfig>): Promise<UsbConfig>;
  deleteConfig(id: number): Promise<void>;

  getLogs(): Promise<UsbLog[]>;
  createLog(log: InsertUsbLog): Promise<UsbLog>;
  clearLogs(): Promise<void>;
}

export class PgStorage implements IStorage {
  async getConfigs(): Promise<UsbConfig[]> {
    const { db } = await import('./db');
    const { desc } = await import('drizzle-orm');
    return await db.select().from(usbConfigs).orderBy(desc(usbConfigs.createdAt));
  }

  async getConfig(id: number): Promise<UsbConfig | undefined> {
    const { db } = await import('./db');
    const { eq } = await import('drizzle-orm');
    const [config] = await db.select().from(usbConfigs).where(eq(usbConfigs.id, id));
    return config;
  }

  async getConfigByDeviceId(deviceId: string): Promise<UsbConfig | undefined> {
    const { db } = await import('./db');
    const { eq } = await import('drizzle-orm');
    const [config] = await db.select().from(usbConfigs).where(eq(usbConfigs.deviceId, deviceId));
    return config;
  }

  async createConfig(insertConfig: InsertUsbConfig): Promise<UsbConfig> {
    const { db } = await import('./db');
    const [config] = await db.insert(usbConfigs).values(insertConfig).returning();
    return config;
  }

  async updateConfig(id: number, updates: Partial<InsertUsbConfig>): Promise<UsbConfig> {
    const { db } = await import('./db');
    const { eq } = await import('drizzle-orm');
    const [config] = await db
      .update(usbConfigs)
      .set({ ...updates, updatedAt: new Date() })
      .where(eq(usbConfigs.id, id))
      .returning();
    return config;
  }

  async deleteConfig(id: number): Promise<void> {
    const { db } = await import('./db');
    const { eq } = await import('drizzle-orm');
    await db.delete(usbConfigs).where(eq(usbConfigs.id, id));
  }

  async getLogs(): Promise<UsbLog[]> {
    const { db } = await import('./db');
    const { desc } = await import('drizzle-orm');
    return await db.select().from(usbLogs).orderBy(desc(usbLogs.timestamp));
  }

  async createLog(insertLog: InsertUsbLog): Promise<UsbLog> {
    const { db } = await import('./db');
    const [log] = await db.insert(usbLogs).values(insertLog).returning();
    return log;
  }

  async clearLogs(): Promise<void> {
    const { db } = await import('./db');
    await db.delete(usbLogs);
  }
}

export class FileStorage implements IStorage {
  private filePath: string;
  private data: { configs: any[]; logs: any[]; nextId: number } = { configs: [], logs: [], nextId: 1 };
  private writeLock: Promise<void> = Promise.resolve();

  constructor(filePath?: string) {
    this.filePath = filePath || path.resolve(process.cwd(), 'data', 'fallback-db.json');
  }

  private async load() {
    try {
      const raw = await fs.readFile(this.filePath, 'utf8');
      this.data = JSON.parse(raw);
      if (!this.data.nextId) this.data.nextId = 1;
    } catch (err: any) {
      if (err?.code === 'ENOENT') {
        await fs.mkdir(path.dirname(this.filePath), { recursive: true });
        await this.persist();
      } else if (err instanceof SyntaxError) {
        // Try to restore from the latest backup if JSON is corrupted
        const dir = path.dirname(this.filePath);
        const base = path.basename(this.filePath);
        const entries = await fs.readdir(dir);
        const bakFiles = await Promise.all(entries
          .filter(f => f.startsWith(`${base}.bak.`))
          .map(async f => ({ name: f, path: path.join(dir, f), stat: await fs.stat(path.join(dir, f)) }))
        );
        bakFiles.sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs); // newest first
        const latest = bakFiles[0];
        if (latest) {
          await fs.copyFile(latest.path, this.filePath);
          // Try loading again (recursive, but only once)
          const raw2 = await fs.readFile(this.filePath, 'utf8');
          this.data = JSON.parse(raw2);
          if (!this.data.nextId) this.data.nextId = 1;
          return;
        }
        throw new Error('Fallback DB is corrupted and no backup is available');
      } else {
        throw err;
      }
    }
  }

  private async persist() {
    const tmp = `${this.filePath}.tmp`;
    const backup = `${this.filePath}.bak.${Date.now()}`;
    const keep = Number(process.env.FALLBACK_DB_BACKUP_KEEP || process.env.STORAGE_BACKUP_KEEP || 10);

    const write = async () => {
      try {
        // create backup if the main file exists
        try {
          await fs.access(this.filePath);
          await fs.copyFile(this.filePath, backup);
        } catch (e) {
          // file doesn't exist or backup failed: continue without failing persist
        }

        await fs.writeFile(tmp, JSON.stringify(this.data, null, 2), 'utf8');
        try {
          await fs.rename(tmp, this.filePath);
        } catch (renameErr) {
          // On Windows, fs.rename can fail with EPERM if the file is in use.
          // Fall back to copying the temp file over the target and removing the temp file.
          try {
            await fs.copyFile(tmp, this.filePath);
            await fs.unlink(tmp).catch(() => {});
          } catch (copyErr) {
            // If fallback also fails, rethrow original rename error to be handled below
            throw renameErr;
          }
        }
      } catch (err) {
        // Attempt to restore from backup on failure
        try {
          await fs.access(backup);
          await fs.copyFile(backup, this.filePath);
        } catch (restoreErr) {
          // if restore also fails, rethrow the original error
        }
        throw err;
      }
      // rotate old backups (keep newest `keep` items)
      try {
        const dir = path.dirname(this.filePath);
        const base = path.basename(this.filePath);
        const entries = await fs.readdir(dir);
        const bakFiles = await Promise.all(entries
          .filter(f => f.startsWith(`${base}.bak.`))
          .map(async f => ({ name: f, path: path.join(dir, f), stat: await fs.stat(path.join(dir, f)) }))
        );

        bakFiles.sort((a, b) => b.stat.mtimeMs - a.stat.mtimeMs);
        const toDelete = bakFiles.slice(keep);
        await Promise.all(toDelete.map(t => fs.unlink(t.path).catch(() => {})));
      } catch (rotationErr) {
        // don't fail the write if rotation fails
      }
    };

    this.writeLock = this.writeLock.then(write, write);
    return this.writeLock;
  }

  private clone<T>(v: T): T {
    // JSON.stringify returns undefined for top-level `undefined`.
    if (typeof v === 'undefined') return v as T;
    const s = JSON.stringify(v);
    if (typeof s === 'undefined') return v as T;
    return JSON.parse(s);
  }

  async getConfigs(): Promise<UsbConfig[]> {
    await this.load();
    return this.clone(this.data.configs.map((c, idx) => ({ id: c.id ?? idx + 1, ...c })));
  }

  async getConfig(id: number): Promise<UsbConfig | undefined> {
    await this.load();
    const found = this.data.configs.find((c: any) => Number(c.id || 0) === Number(id));
    if (!found) return undefined;
    return this.clone(found);
  }

  async getConfigByDeviceId(deviceId: string): Promise<UsbConfig | undefined> {
    await this.load();
    const found = this.data.configs.find((c: any) => c.deviceId === deviceId);
    if (!found) return undefined;
    return this.clone(found);
  }

  async createConfig(insertConfig: InsertUsbConfig): Promise<UsbConfig> {
    await this.load();
    const id = this.data.nextId++;
    const record: any = { id, ...insertConfig, createdAt: new Date().toISOString(), updatedAt: new Date().toISOString() };
    this.data.configs.push(record);
    await this.persist();
    return this.clone(record);
  }

  async updateConfig(id: number, updates: Partial<InsertUsbConfig>): Promise<UsbConfig> {
    await this.load();
    const idx = this.data.configs.findIndex((c: any) => Number(c.id || 0) === Number(id));
    if (idx === -1) throw new Error('Config not found');
    this.data.configs[idx] = { ...this.data.configs[idx], ...updates, updatedAt: new Date().toISOString() };
    await this.persist();
    return this.clone(this.data.configs[idx]);
  }

  async deleteConfig(id: number): Promise<void> {
    await this.load();
    this.data.configs = this.data.configs.filter((c: any) => Number(c.id || 0) !== Number(id));
    await this.persist();
  }

  async getLogs(): Promise<UsbLog[]> {
    await this.load();
    return this.clone(this.data.logs);
  }

  async createLog(insertLog: InsertUsbLog): Promise<UsbLog> {
    await this.load();
    const record: any = { id: this.data.logs.length + 1, ...insertLog, timestamp: new Date().toISOString() };
    this.data.logs.push(record);
    await this.persist();
    return this.clone(record);
  }

  async clearLogs(): Promise<void> {
    await this.load();
    this.data.logs = [];
    await this.persist();
  }
}

// Try to detect better-sqlite3 at runtime (optional dependency)
// try to require better-sqlite3 if available (works in CommonJS test runtime)
let BetterSqlite3: any = null;
try {
  // eslint-disable-next-line @typescript-eslint/no-var-requires
  BetterSqlite3 = require('better-sqlite3');
} catch (e) {
  BetterSqlite3 = null;
}

export class SqliteStorage implements IStorage {
  private db: any;

  constructor(filePath?: string) {
    if (!BetterSqlite3) throw new Error('better-sqlite3 is not available');
    const sqlitePath = filePath || path.resolve(process.cwd(), 'data', 'fallback.db');
    // ensure dir
    fs.mkdir(path.dirname(sqlitePath), { recursive: true }).catch(() => {});
    this.db = new BetterSqlite3(sqlitePath);
    this.db.pragma('journal_mode = WAL');

    // create tables if not exist
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS configs (
        id INTEGER PRIMARY KEY,
        deviceId TEXT,
        friendlyName TEXT,
        isEnabled INTEGER DEFAULT 1,
        triggerPath TEXT,
        triggerParams TEXT,
        runSilently INTEGER DEFAULT 0,
        forceMinimize INTEGER DEFAULT 0,
        createdAt TEXT,
        updatedAt TEXT
      );
    `);

    this.db.exec(`
      CREATE TABLE IF NOT EXISTS logs (
        id INTEGER PRIMARY KEY,
        deviceId TEXT,
        friendlyName TEXT,
        eventType TEXT,
        actionTaken TEXT,
        details TEXT,
        timestamp TEXT
      );
    `);
  }

  async getConfigs(): Promise<UsbConfig[]> {
    const rows = this.db.prepare('SELECT * FROM configs ORDER BY datetime(createdAt) DESC').all();
    return rows.map((r: any) => ({ ...r, isEnabled: !!r.isEnabled }));
  }

  async getConfig(id: number): Promise<UsbConfig | undefined> {
    const row = this.db.prepare('SELECT * FROM configs WHERE id = ?').get(id);
    if (!row) return undefined;
    return { ...row, isEnabled: !!row.isEnabled };
  }

  async getConfigByDeviceId(deviceId: string): Promise<UsbConfig | undefined> {
    const row = this.db.prepare('SELECT * FROM configs WHERE deviceId = ?').get(deviceId);
    if (!row) return undefined;
    return { ...row, isEnabled: !!row.isEnabled };
  }

  async createConfig(insertConfig: InsertUsbConfig): Promise<UsbConfig> {
    const stmt = this.db.prepare(`INSERT INTO configs (deviceId,friendlyName,isEnabled,triggerPath,triggerParams,runSilently,forceMinimize,createdAt,updatedAt) VALUES (?,?,?,?,?,?,?,?,?)`);
    const now = new Date().toISOString();
    const info = stmt.run(
      insertConfig.deviceId,
      insertConfig.friendlyName,
      insertConfig.isEnabled ? 1 : 0,
      insertConfig.triggerPath,
      insertConfig.triggerParams || '',
      insertConfig.runSilently ? 1 : 0,
      insertConfig.forceMinimize ? 1 : 0,
      now,
      now
    );
    const id = info.lastInsertRowid || info.lastInsertRowId || info.lastInsertRow;
    return this.getConfig(Number(id)) as Promise<UsbConfig>;
  }

  async updateConfig(id: number, updates: Partial<InsertUsbConfig>): Promise<UsbConfig> {
    const existing = await this.getConfig(id);
    if (!existing) throw new Error('Config not found');
    const merged = { ...existing, ...updates, updatedAt: new Date().toISOString() };
    const stmt = this.db.prepare(`UPDATE configs SET deviceId=?,friendlyName=?,isEnabled=?,triggerPath=?,triggerParams=?,runSilently=?,forceMinimize=?,updatedAt=? WHERE id=?`);
    stmt.run(
      merged.deviceId,
      merged.friendlyName,
      merged.isEnabled ? 1 : 0,
      merged.triggerPath,
      (merged as any).triggerParams || '',
      merged.runSilently ? 1 : 0,
      merged.forceMinimize ? 1 : 0,
      merged.updatedAt,
      id
    );
    return this.getConfig(id) as Promise<UsbConfig>;
  }

  async deleteConfig(id: number): Promise<void> {
    this.db.prepare('DELETE FROM configs WHERE id = ?').run(id);
  }

  async getLogs(): Promise<UsbLog[]> {
    const rows = this.db.prepare('SELECT * FROM logs ORDER BY datetime(timestamp) DESC').all();
    return rows;
  }

  async createLog(insertLog: InsertUsbLog): Promise<UsbLog> {
    const stmt = this.db.prepare('INSERT INTO logs (deviceId,friendlyName,eventType,actionTaken,details,timestamp) VALUES (?,?,?,?,?,?)');
    const now = new Date().toISOString();
    const info = stmt.run(insertLog.deviceId, insertLog.friendlyName, insertLog.eventType, insertLog.actionTaken, insertLog.details || '', now);
    const id = info.lastInsertRowid || info.lastInsertRowId || info.lastInsertRow;
    return this.db.prepare('SELECT * FROM logs WHERE id = ?').get(id);
  }

  async clearLogs(): Promise<void> {
    this.db.prepare('DELETE FROM logs').run();
  }
}

// Choose storage backend: Postgres if DATABASE_URL, else optional SQLite if requested, else file fallback
let storageImpl: IStorage;
if (process.env.DATABASE_URL) {
  storageImpl = new PgStorage();
} else if ((process.env.FALLBACK_SQLITE === '1' || process.env.FALLBACK_SQLITE === 'true') && BetterSqlite3) {
  storageImpl = new SqliteStorage();
} else {
  storageImpl = new FileStorage();
}

export const storage = storageImpl;
