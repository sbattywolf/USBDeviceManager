import os from 'os';
import path from 'path';
import fs from 'fs/promises';
import { FileStorage } from '../storage';

describe('FileStorage (unit)', () => {
  const tmpDir = os.tmpdir();
  const file = path.join(tmpDir, `device-sentinel-test-${Date.now()}.json`);
  let store: FileStorage;

  beforeAll(() => {
    store = new FileStorage(file);
  });

  afterAll(async () => {
    try { await fs.unlink(file); } catch {};
  });

  test('create/get/update/delete config', async () => {
    const insert = {
      deviceId: 'dev:1',
      friendlyName: 'Test Device',
      port: undefined,
      isEnabled: true,
      triggerPath: 'C:\\Windows\\notepad.exe',
      triggerParams: '',
      runSilently: false,
      forceMinimize: false
    };

    const created = await store.createConfig(insert as any);
    expect(created).toHaveProperty('id');

    const fetched = await store.getConfig(created.id as number);
    expect(fetched?.deviceId).toBe(insert.deviceId);

    const updated = await store.updateConfig(created.id as number, { friendlyName: 'Updated' });
    expect(updated.friendlyName).toBe('Updated');

    await store.deleteConfig(created.id as number);
    const after = await store.getConfig(created.id as number);
    expect(after).toBeUndefined();
  });

  test('create and clear logs', async () => {
    const log = {
      deviceId: 'dev:1',
      friendlyName: 'Test Device',
      eventType: 'CONNECTED',
      actionTaken: 'TRIGGER_STARTED',
      details: 'ok'
    };

    const created = await store.createLog(log as any);
    expect(created).toHaveProperty('id');

    const logs = await store.getLogs();
    expect(Array.isArray(logs)).toBe(true);
    expect(logs.length).toBeGreaterThanOrEqual(1);

    await store.clearLogs();
    const after = await store.getLogs();
    expect(after.length).toBe(0);
  });
});
