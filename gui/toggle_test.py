import requests
import time

BASE = 'http://localhost:5000'

def main():
    try:
        r = requests.get(f"{BASE}/api/devices", timeout=5)
        r.raise_for_status()
        devices = r.json()
    except Exception as e:
        print('GET /api/devices failed:', e)
        return

    if not devices:
        print('No devices found')
        return

    d = devices[0]
    device_id = d.get('Id') or d.get('id')
    current = d.get('IsEnabled')
    if current is None:
        current = d.get('isEnabled')
    if current is None:
        current = False

    toggle_value = not bool(current)
    print(f"Toggling device {device_id}: {current} -> {toggle_value}")

    try:
        r2 = requests.post(f"{BASE}/api/devices/{device_id}/toggle", json=toggle_value, timeout=5)
        print('POST response status:', r2.status_code)
        try:
            print('Body:', r2.json())
        except Exception:
            print('Body:', r2.text)
    except Exception as e:
        print('POST failed:', e)

if __name__ == '__main__':
    main()
