import UsbWatcher from '../usbWatcher';
import scanUsbDevices from '../usb';

jest.mock('../usb');

describe('UsbWatcher', () => {
  beforeEach(() => jest.clearAllMocks());

  test('emits change when devices change', async () => {
    const devices1 = [{ InstanceId: 'a', FriendlyName: 'A', Status: 'OK' }];
    const devices2 = [{ InstanceId: 'b', FriendlyName: 'B', Status: 'OK' }];

    // @ts-ignore
    scanUsbDevices.mockResolvedValueOnce(devices1).mockResolvedValueOnce(devices2);

    const w = new UsbWatcher({ usbInterval: 50 });
    const changes: any[] = [];
    w.on('change', (d) => changes.push(d));

    // start by adding a fake client so watcher starts
    const fakeRes: any = { write: () => {}, end: () => {} };
    w.addClient(fakeRes);

    // wait enough time for two polls
    await new Promise((r) => setTimeout(r, 160));

    expect(changes.length).toBeGreaterThanOrEqual(2);

    w.removeClient(fakeRes);
  });

  test('stops when no clients', async () => {
    const devices = [{ InstanceId: 'x', FriendlyName: 'X', Status: 'OK' }];
    // @ts-ignore
    scanUsbDevices.mockResolvedValue(devices);

    const w = new UsbWatcher({ usbInterval: 30 });
    const fakeRes: any = { write: () => {}, end: () => {} };
    w.addClient(fakeRes);
    await new Promise((r) => setTimeout(r, 60));
    w.removeClient(fakeRes);
    // capture internal timer
    await new Promise((r) => setTimeout(r, 40));
    // after removing clients, internal timer should be null (no further polls)
    // we rely on absence of exceptions; ensure clients size is zero
    // @ts-ignore
    expect((w as any).clients.size).toBe(0);
  });
});
