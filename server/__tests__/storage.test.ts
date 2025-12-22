import { storage } from '../storage';

describe('File fallback storage (development)', () => {
  test('create and list configs', async () => {
    const cfg = await storage.createConfig({
      deviceId: 'dev:1234',
      friendlyName: 'Test Device',
      port: undefined,
      isEnabled: true,
      triggerPath: 'C:\\Windows\\notepad.exe',
      triggerParams: '',
      runSilently: false,
      forceMinimize: false,
    } as any);

    const list = await storage.getConfigs();
    expect(Array.isArray(list)).toBe(true);
    expect(list.length).toBeGreaterThan(0);
  });

  test('create and clear logs', async () => {
    await storage.createLog({ deviceId: 'dev:1234', friendlyName: 'Test', eventType: 'CONNECTED', actionTaken: 'TRIGGER_STARTED', details: 'ok' } as any);
    const logs = await storage.getLogs();
    expect(Array.isArray(logs)).toBe(true);
    expect(logs.length).toBeGreaterThan(0);
    await storage.clearLogs();
    const cleared = await storage.getLogs();
    expect(cleared.length).toBe(0);
  });
});
