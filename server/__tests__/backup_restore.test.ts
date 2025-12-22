import fs from 'fs/promises';
import path from 'path';
import { FileStorage } from '../storage';

describe('FileStorage backup/restore integrity', () => {
  const filePath = path.resolve(process.cwd(), 'data', 'test-fallback-db.json');
  let storage: FileStorage;

  beforeEach(async () => {
    storage = new FileStorage(filePath);
    // Start with a known state
    await fs.writeFile(filePath, JSON.stringify({ configs: [], logs: [], nextId: 1 }, null, 2), 'utf8');
  });

  afterEach(async () => {
    try { await fs.unlink(filePath); } catch {}
    // Remove backups
    const dir = path.dirname(filePath);
    const base = path.basename(filePath);
    const entries = await fs.readdir(dir);
    for (const f of entries) {
      if (f.startsWith(`${base}.bak.`)) {
        try { await fs.unlink(path.join(dir, f)); } catch {}
      }
    }
  });

  it('creates a backup and can restore from it', async () => {
    // Write initial config and force a backup
    await storage.createConfig({
      deviceId: 'test:backup',
      friendlyName: 'Backup Device',
      isEnabled: true,
      triggerPath: 'C:/Windows/notepad.exe',
      triggerParams: '',
      runSilently: false,
      forceMinimize: false
    });
    // Wait a moment to ensure backup timestamp is unique
    await new Promise(r => setTimeout(r, 10));
    // Force a backup by calling persist directly
    // @ts-expect-error: access private method for test
    await storage.persist();
    // Find the backup file
    const dir = path.dirname(filePath);
    const base = path.basename(filePath);
    const entries = await fs.readdir(dir);
    const bak = entries.find(f => f.startsWith(`${base}.bak.`));
    expect(bak).toBeTruthy();
    // Corrupt the main file
    await fs.writeFile(filePath, 'corrupted', 'utf8');
    // Try to load, which should trigger restore from backup
    await expect(storage.getConfigs()).resolves.toBeDefined();
    // Should not throw, and configs should be present
    const configs = await storage.getConfigs();
    expect(configs.length).toBeGreaterThan(0);
  });
});
