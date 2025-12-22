import { useEffect, useRef, useState } from 'react';

export type UsbDevice = { InstanceId?: string; FriendlyName?: string; Status?: string };

export function useUsbStream(options?: { usbInterval?: number }) {
  const [devices, setDevices] = useState<UsbDevice[]>([]);
  const esRef = useRef<EventSource | null>(null);
  const pollRef = useRef<number | null>(null);
  const usbInterval = options?.usbInterval ?? 10000;

  useEffect(() => {
    let active = true;

    const startSSE = () => {
      if (typeof window === 'undefined' || !('EventSource' in window)) return false;
      try {
        const es = new EventSource('/api/usb/stream');
        es.onmessage = (ev) => {
          try {
            const parsed = JSON.parse(ev.data);
            if (active) setDevices(parsed);
          } catch {}
        };
        es.onerror = () => {
          // fallback to polling
          stopSSE();
        };
        esRef.current = es;
        return true;
      } catch (e) {
        return false;
      }
    };

    const stopSSE = () => {
      if (esRef.current) {
        try { esRef.current.close(); } catch {}
        esRef.current = null;
      }
    };

    const poll = async () => {
      try {
        const res = await fetch('/api/usb/scan');
        if (!res.ok) return;
        const json = await res.json();
        if (active) setDevices(json);
      } catch {}
    };

    const startPolling = () => {
      if (pollRef.current) return;
      poll();
      pollRef.current = window.setInterval(poll, usbInterval);
    };

    const stopPolling = () => {
      if (pollRef.current) {
        clearInterval(pollRef.current);
        pollRef.current = null;
      }
    };

    // Only start when tab is visible to minimize resources
    const handleVisibility = () => {
      if (document.hidden) {
        stopSSE();
        stopPolling();
      } else {
        const ok = startSSE();
        if (!ok) startPolling();
      }
    };

    document.addEventListener('visibilitychange', handleVisibility);
    // initial start
    handleVisibility();

    return () => {
      active = false;
      document.removeEventListener('visibilitychange', handleVisibility);
      stopSSE();
      stopPolling();
    };
  }, [usbInterval]);

  return { devices };
}

export default useUsbStream;
