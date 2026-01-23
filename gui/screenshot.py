import os
import datetime
import logging
from PyQt6.QtGui import QGuiApplication
try:
    from gui.signals import notifier
except Exception:
    notifier = None


def capture_screenshot(prefix: str = 'screenshot') -> str | None:
    """Capture the primary screen and save to logs/screenshots with a timestamp.

    Returns the file path on success, or None on failure.
    """
    try:
        folder = os.path.join('logs', 'screenshots')
        os.makedirs(folder, exist_ok=True)
        ts = datetime.datetime.now().strftime('%Y%m%d_%H%M%S')
        fname = os.path.join(folder, f"{prefix}_{ts}.png")
        screen = QGuiApplication.primaryScreen()
        if not screen:
            logging.warning('No primary screen available for screenshot')
            return None
        pix = screen.grabWindow(0)
        if pix and pix.save(fname):
            logging.info('Saved screenshot to %s', fname)
            try:
                if notifier is not None and fname:
                    # Emit a signal so the UI can refresh inline thumbnails immediately
                    notifier.screenshot_captured.emit(fname)
            except Exception:
                logging.exception('Failed to emit screenshot_captured signal')
            return fname
        logging.warning('Failed to save screenshot to %s', fname)
    except Exception:
        logging.exception('Exception while capturing screenshot')
    return None
