import { validateInsertUsbConfig, validateInsertUsbLog } from '../../shared/schema';

describe('Shared schema validators', () => {
  test('validateInsertUsbConfig accepts valid payload', () => {
    const payload = {
      deviceId: '1234:5678',
      friendlyName: 'USB Drive',
      port: undefined,
      isEnabled: true,
      triggerPath: 'C:\\Windows\\notepad.exe',
      triggerParams: '',
      runSilently: false,
      forceMinimize: false
    };

    expect(() => validateInsertUsbConfig(payload)).not.toThrow();
  });

  test('validateInsertUsbConfig rejects missing required', () => {
    const bad = { friendlyName: 'No Device' };
    expect(() => validateInsertUsbConfig(bad as any)).toThrow();
  });

  test('validateInsertUsbLog accepts valid payload', () => {
    const payload = {
      deviceId: '1234:5678',
      friendlyName: 'USB Drive',
      eventType: 'CONNECTED',
      actionTaken: 'TRIGGER_STARTED',
      details: 'ok'
    };
    expect(() => validateInsertUsbLog(payload)).not.toThrow();
  });

  test('validateInsertUsbLog rejects missing required', () => {
    const bad = { friendlyName: 'No Device' };
    expect(() => validateInsertUsbLog(bad as any)).toThrow();
  });
});
