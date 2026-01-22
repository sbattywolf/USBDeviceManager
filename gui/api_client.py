import os
import json
import time
import requests
import logging


class ApiClient:
    def __init__(self, base_url):
        self.base = base_url.rstrip('/')

        # Embedded fallback data for offline debugging
        self._fallback_devices = [
            {"Id": "dev-1", "Name": "Wheel Base", "DeviceId": "WB-001", "IsEnabled": True, "LastSeen": "2026-01-20T12:00:00"},
            {"Id": "dev-2", "Name": "Pedals", "DeviceId": "PD-002", "IsEnabled": False, "LastSeen": "2026-01-20T11:55:00"}
        ]
        self._fallback_software = [
            {"Id": "sw-1", "Name": "TelemetryRelay", "ExecutablePath": "C:\\Program Files\\Telemetry\\relay.exe", "IsRunning": False, "AutoStart": True},
            {"Id": "sw-2", "Name": "ForceFeedback", "ExecutablePath": "C:\\FFB\\ffb.exe", "IsRunning": True, "AutoStart": False}
        ]
        self._last_simulated = False

    @property
    def last_simulated(self):
        return bool(self._last_simulated)

    def get_devices(self):
        try:
            r = requests.get(f"{self.base}/api/devices", timeout=5)
            r.raise_for_status()
            self._last_simulated = False
            return r.json()
        except Exception:
            logging.exception("ApiClient.get_devices failed for %s, returning fallback data", self.base)
            self._last_simulated = True
            return self._fallback_devices

    def get_software(self):
        try:
            r = requests.get(f"{self.base}/api/software", timeout=5)
            r.raise_for_status()
            self._last_simulated = False
            return r.json()
        except Exception:
            logging.exception("ApiClient.get_software failed for %s, returning fallback data", self.base)
            self._last_simulated = True
            return self._fallback_software

    def post(self, path, data=None):
        try:
            r = requests.post(f"{self.base}{path}", json=data, timeout=5)
            r.raise_for_status()
            try:
                return True, r.json()
            except ValueError:
                return True, r.text
        except Exception as e:
            logging.exception("ApiClient.post failed %s on %s; falling back to simulated response", path, self.base)
            # Simulate expected server behavior when backend is down so UI can remain interactive
            try:
                # Device toggle: /api/devices/{id}/toggle
                if path.startswith('/api/devices/') and path.rstrip('/').endswith('/toggle'):
                    parts = path.split('/')
                    dev_id = parts[3] if len(parts) > 3 else None
                    for d in self._fallback_devices:
                        if d.get('Id') == dev_id or d.get('id') == dev_id:
                            d['IsEnabled'] = not bool(d.get('IsEnabled'))
                            simulated = {'result': 'ok', 'Id': dev_id, 'IsEnabled': d['IsEnabled']}
                            # persist simulated POST to activity log
                            try:
                                ts = time.strftime('%Y-%m-%d %H:%M:%S')
                                os.makedirs('logs', exist_ok=True)
                                with open(os.path.join('logs', 'desktop_activity.log'), 'a', encoding='utf-8') as fh:
                                    fh.write(f'[{ts}] SIMULATED POST {path} -> {json.dumps(simulated, default=str)}\n')
                            except Exception:
                                logging.exception('Failed to write simulated POST to desktop_activity.log')
                            return True, simulated
                    simulated = {'result': 'ok', 'Id': dev_id, 'requested': data}
                    try:
                        ts = time.strftime('%Y-%m-%d %H:%M:%S')
                        os.makedirs('logs', exist_ok=True)
                        with open(os.path.join('logs', 'desktop_activity.log'), 'a', encoding='utf-8') as fh:
                            fh.write(f'[{ts}] SIMULATED POST {path} -> {json.dumps(simulated, default=str)}\n')
                    except Exception:
                        logging.exception('Failed to write simulated POST to desktop_activity.log')
                    return True, simulated

                # Software start/stop: /api/software/{id}/start or /stop
                if path.startswith('/api/software/') and (path.rstrip('/').endswith('/start') or path.rstrip('/').endswith('/stop')):
                    parts = path.split('/')
                    sw_id = parts[3] if len(parts) > 3 else None
                    action = 'start' if path.rstrip('/').endswith('/start') else 'stop'
                    for s in self._fallback_software:
                        if s.get('Id') == sw_id or s.get('id') == sw_id:
                            s['IsRunning'] = True if action == 'start' else False
                            simulated = {'result': 'ok', 'Id': sw_id, 'IsRunning': s['IsRunning']}
                            try:
                                ts = time.strftime('%Y-%m-%d %H:%M:%S')
                                os.makedirs('logs', exist_ok=True)
                                with open(os.path.join('logs', 'desktop_activity.log'), 'a', encoding='utf-8') as fh:
                                    fh.write(f'[{ts}] SIMULATED POST {path} -> {json.dumps(simulated, default=str)}\n')
                            except Exception:
                                logging.exception('Failed to write simulated POST to desktop_activity.log')
                            return True, simulated
                    simulated = {'result': 'ok', 'Id': sw_id, 'action': action}
                    try:
                        ts = time.strftime('%Y-%m-%d %H:%M:%S')
                        os.makedirs('logs', exist_ok=True)
                        with open(os.path.join('logs', 'desktop_activity.log'), 'a', encoding='utf-8') as fh:
                            fh.write(f'[{ts}] SIMULATED POST {path} -> {json.dumps(simulated, default=str)}\n')
                    except Exception:
                        logging.exception('Failed to write simulated POST to desktop_activity.log')
                    return True, simulated

                # Generic simulated success for other POSTs
                return True, {'result': 'ok', 'path': path, 'simulated': True}
            except Exception:
                logging.exception('Failed to simulate API response for %s', path)
            return False, str(e)
