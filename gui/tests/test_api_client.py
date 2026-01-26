import json
from gui.ui.main_window import ApiClient


def test_get_devices_fallback():
    api = ApiClient('http://127.0.0.1:59999')  # unused port to force connection failure
    devices = api.get_devices()
    assert isinstance(devices, list)
    assert len(devices) >= 1
    # when connection fails, ApiClient sets last_simulated True
    assert api.last_simulated is True


def test_post_toggle_simulation():
    api = ApiClient('http://127.0.0.1:59999')
    devices = api.get_devices()
    assert api.last_simulated
    # find initial state for dev-1
    initial = None
    for d in devices:
        if d.get('Id') == 'dev-1':
            initial = d.get('IsEnabled')
    ok, resp = api.post('/api/devices/dev-1/toggle')
    assert ok is True
    assert isinstance(resp, dict)
    assert resp.get('Id') == 'dev-1'
    assert resp.get('IsEnabled') == (not bool(initial))


def test_post_software_start_stop_simulation():
    api = ApiClient('http://127.0.0.1:59999')
    sw = api.get_software()
    assert api.last_simulated
    ok, resp = api.post('/api/software/sw-1/start')
    assert ok is True
    assert resp.get('Id') == 'sw-1'
    assert resp.get('IsRunning') is True
    ok, resp = api.post('/api/software/sw-1/stop')
    assert ok is True
    assert resp.get('IsRunning') is False
