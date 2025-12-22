import EventEmitter from 'events';
import scanUsbDevices, { UsbDevice } from './usb';

export type UsbWatcherOptions = {
  usbInterval?: number; // ms
};

export class UsbWatcher extends EventEmitter {
  private timer: NodeJS.Timeout | null = null;
  private clients = new Set<any>();
  private lastSnapshot: string | null = null;
  private usbInterval: number;

  constructor(opts?: UsbWatcherOptions) {
    super();
    this.usbInterval = (opts?.usbInterval ?? 10000);
  }

  startIfNeeded() {
    if (this.timer) return;
    this.timer = setInterval(() => this.poll(), this.usbInterval);
    // run immediate
    void this.poll();
  }

  stopIfIdle() {
    if (this.timer && this.clients.size === 0) {
      clearInterval(this.timer);
      this.timer = null;
      this.lastSnapshot = null;
    }
  }

  addClient(res: any) {
    this.clients.add(res);
    if (this.clients.size === 1) this.startIfNeeded();
  }

  removeClient(res: any) {
    this.clients.delete(res);
    this.stopIfIdle();
  }

  async poll() {
    try {
      const devices: UsbDevice[] = await scanUsbDevices();
      const snapshot = JSON.stringify(devices.map(d => ({ id: d.InstanceId, name: d.FriendlyName, status: d.Status })));
      if (this.lastSnapshot === null) {
        this.lastSnapshot = snapshot;
        // initial load - emit current
        this.emit('change', devices);
        this.pushToClients(devices);
        return;
      }

      if (snapshot !== this.lastSnapshot) {
        this.lastSnapshot = snapshot;
        this.emit('change', devices);
        this.pushToClients(devices);
      }
    } catch (e) {
      // ignore errors to keep polling
    }
  }

  pushToClients(devices: UsbDevice[]) {
    const payload = JSON.stringify(devices);
    for (const res of Array.from(this.clients)) {
      try {
        res.write(`data: ${payload}\n\n`);
      } catch (e) {
        // on error, remove client
        this.removeClient(res);
        try { res.end(); } catch {}
      }
    }
  }
}

export default UsbWatcher;
