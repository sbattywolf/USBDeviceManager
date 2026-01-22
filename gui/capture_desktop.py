import os
import time
import datetime
import logging
from PyQt6.QtGui import QGuiApplication

# wait to allow GUI to start and render
time.sleep(5)

os.makedirs('logs/screenshots', exist_ok=True)
ts = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
fname = os.path.join('logs', 'screenshots', f'startup_preview_{ts}.png')
try:
    app = QGuiApplication([])
    screen = QGuiApplication.primaryScreen()
    if not screen:
        print('No primary screen available')
        raise SystemExit(2)
    pix = screen.grabWindow(0)
    ok = pix.save(fname)
    if ok:
        print(fname)
    else:
        print('Failed to save screenshot')
except Exception as e:
    print('Exception capturing screenshot:', e)
    raise
