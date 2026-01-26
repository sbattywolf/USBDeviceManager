import yaml, traceback
p='e:/Workspaces/Git/SimRacing/USBDeviceManager/.github/workflows/ci.yml'
try:
    with open(p,'r',encoding='utf-8') as f:
        yaml.safe_load(f)
    print('OK')
except Exception as e:
    print('ERROR',repr(e))
    traceback.print_exc()
