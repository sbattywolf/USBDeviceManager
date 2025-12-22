import { exec } from 'child_process';

export type UsbDevice = {
  InstanceId?: string;
  FriendlyName?: string;
  Class?: string;
  Status?: string;
};

export function scanUsbDevices(): Promise<UsbDevice[]> {
  return new Promise((resolve) => {
    if (process.platform !== 'win32') return resolve([]);

    // Use PowerShell to enumerate present PnP devices filtered by USB class
    const cmd = `powershell -NoProfile -Command "Get-PnpDevice -PresentOnly | Select-Object InstanceId,FriendlyName,Class,Status | ConvertTo-Json -Depth 3"`;

    exec(cmd, { windowsHide: true, timeout: 5000 }, (err, stdout) => {
      if (err) {
        return resolve([]);
      }

      try {
        const raw = stdout && stdout.trim();
        if (!raw) return resolve([]);

        const parsed = JSON.parse(raw);
        // Convert single object to array
        if (Array.isArray(parsed)) return resolve(parsed as UsbDevice[]);
        return resolve([parsed as UsbDevice]);
      } catch (e) {
        return resolve([]);
      }
    });
  });
}

export default scanUsbDevices;
