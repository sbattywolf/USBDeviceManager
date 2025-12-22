jest.mock('child_process', () => ({ exec: jest.fn() }));

import { scanUsbDevices } from '../usb';
import * as child from 'child_process';

describe('USB scan helper', () => {
  const originalPlatform = process.platform;
  afterEach(() => {
    // restore platform
    try { Object.defineProperty(process, 'platform', { value: originalPlatform }); } catch {}
    jest.restoreAllMocks();
  });

  test('returns empty array on non-windows', async () => {
    try { Object.defineProperty(process, 'platform', { value: 'linux' }); } catch {}
    const res = await scanUsbDevices();
    expect(Array.isArray(res)).toBe(true);
    expect(res.length).toBe(0);
  });

  test('parses JSON output from PowerShell', async () => {
    try { Object.defineProperty(process, 'platform', { value: 'win32' }); } catch {}

    const sample = JSON.stringify([
      { InstanceId: 'USB\\VID_1234', FriendlyName: 'USB Drive', Class: 'USB', Status: 'OK' }
    ]);

    (child as any).exec.mockImplementation((cmd: string, opts: any, cb: any) => {
      if (typeof cb === 'function') cb(null, sample, '');
      return {} as any;
    });

    const res = await scanUsbDevices();
    expect(Array.isArray(res)).toBe(true);
    expect(res[0].FriendlyName).toBe('USB Drive');
  });
});
