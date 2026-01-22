import json
import logging
import argparse
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse

logging.basicConfig(filename='logs/mock_stub.log', level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

SAMPLE_DEVICES = [
    {"Id": "dev-1", "Name": "Wheel Base", "DeviceId": "WB-001", "IsEnabled": True, "LastSeen": "2026-01-20T12:00:00"},
    {"Id": "dev-2", "Name": "Pedals", "DeviceId": "PD-002", "IsEnabled": False, "LastSeen": "2026-01-20T11:55:00"}
]

SAMPLE_SOFTWARE = [
    {"Id": "sw-1", "Name": "TelemetryRelay", "ExecutablePath": "C:\\Program Files\\Telemetry\\relay.exe", "IsRunning": False, "AutoStart": True},
    {"Id": "sw-2", "Name": "ForceFeedback", "ExecutablePath": "C:\\FFB\\ffb.exe", "IsRunning": True, "AutoStart": False}
]

class MockHandler(BaseHTTPRequestHandler):
    def _send_json(self, data, status=200):
        body = json.dumps(data).encode('utf-8')
        self.send_response(status)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()
        self.wfile.write(body)

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET,POST,OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        logging.info('GET %s', path)
        if path == '/api/devices':
            self._send_json(SAMPLE_DEVICES)
            return
        if path == '/api/software':
            self._send_json(SAMPLE_SOFTWARE)
            return
        # default 404
        self._send_json({'error': 'not found'}, status=404)

    def do_POST(self):
        parsed = urlparse(self.path)
        path = parsed.path
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length) if length else b''
        try:
            payload = json.loads(body) if body else None
        except Exception:
            payload = body.decode('utf-8', errors='ignore')
        logging.info('POST %s payload=%s', path, payload)

        # Toggle device
        if path.startswith('/api/devices/') and path.endswith('/toggle'):
            # echo back a success message and the new state (toggle)
            dev_id = path.split('/')[3] if len(path.split('/')) > 3 else None
            # Find device and flip IsEnabled
            for d in SAMPLE_DEVICES:
                if d.get('Id') == dev_id or d.get('id') == dev_id:
                    d['IsEnabled'] = not bool(d.get('IsEnabled'))
                    self._send_json({'result': 'ok', 'Id': dev_id, 'IsEnabled': d['IsEnabled']})
                    return
            # if not found, return success with requested toggle
            self._send_json({'result': 'ok', 'Id': dev_id, 'requested': payload})
            return

        # Software start/stop
        if path.startswith('/api/software/') and (path.endswith('/start') or path.endswith('/stop')):
            sw_id = path.split('/')[3] if len(path.split('/')) > 3 else None
            action = 'start' if path.endswith('/start') else 'stop'
            for s in SAMPLE_SOFTWARE:
                if s.get('Id') == sw_id or s.get('id') == sw_id:
                    s['IsRunning'] = True if action == 'start' else False
                    self._send_json({'result': 'ok', 'Id': sw_id, 'IsRunning': s['IsRunning']})
                    return
            self._send_json({'result': 'ok', 'Id': sw_id, 'action': action})
            return

        self._send_json({'error': 'not found'}, status=404)


def serve(port: int = 5000):
    server = HTTPServer(('0.0.0.0', port), MockHandler)
    logging.info('Mock API server starting on port %d', port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        logging.info('Mock API server stopping')
        server.server_close()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=5000)
    args = parser.parse_args()
    serve(args.port)
