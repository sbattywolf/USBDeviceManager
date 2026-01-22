import sys
import argparse
import logging
import traceback
import os
from PyQt6.QtWidgets import QApplication, QMessageBox
from gui.screenshot import capture_screenshot



os.makedirs('logs', exist_ok=True)
logging.basicConfig(
    filename='logs/desktop_gui.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

def exception_hook(exctype, value, tb):
    traceback_details = "".join(traceback.format_exception(exctype, value, tb))
    logging.critical(f"Unhandled Exception: {traceback_details}")
    app = QApplication.instance()
    if not app:
        app = QApplication(sys.argv)
    # Use ErrorDetailDialog if available; otherwise show a simple message box
    # capture a screenshot of the desktop to help diagnose rendering issues
    try:
        fname = capture_screenshot('unhandled_exception')
    except Exception:
        logging.exception('Screenshot capture failed')
    else:
        try:
            # Persist to activity log so running UI can pick it up and refresh thumbnail
            os.makedirs('logs', exist_ok=True)
            with open(os.path.join('logs', 'desktop_activity.log'), 'a', encoding='utf-8') as fh:
                fh.write(f"[unhandled_exception] screenshot={fname}\n")
        except Exception:
            logging.exception('Failed to write unhandled exception to activity log')

    if 'ErrorDetailDialog' in globals():
        try:
            error_dlg = ErrorDetailDialog(str(value), traceback_details)
            error_dlg.exec()
        except Exception:
            QMessageBox.critical(None, "Application Error", f"{value}\n\nSee logs for details. Screenshot: {fname if 'fname' in locals() else 'n/a'}")
    else:
        QMessageBox.critical(None, "Application Error", f"{value}\n\nSee logs/desktop_gui.log for details. Screenshot: {fname if 'fname' in locals() else 'n/a'}")
    sys.exit(1)

def main():
    sys.excepthook = exception_hook

    parser = argparse.ArgumentParser()
    parser.add_argument('--api', default='http://localhost:5000', help='Base URL for server API')
    parser.add_argument('--no-refresh', action='store_true', help='Disable periodic UI refresh')
    args = parser.parse_args()

    app = QApplication(sys.argv)

    # Import UI components after setting the excepthook so import-time
    # errors are handled by the hook or by the fallback below.
    try:
        # Try absolute import first (when running with CWD set to gui/)
        from ui.main_window import MainDashboard
        from ui.dialogs import ErrorDetailDialog
    except Exception:
        try:
            # Fallback to package-relative import when running as module (python -m gui.main)
            from .ui.main_window import MainDashboard  # type: ignore
            from .ui.dialogs import ErrorDetailDialog  # type: ignore
        except Exception as e:
            logging.critical(f"Failed to import UI modules: {e}\n{traceback.format_exc()}")
            QMessageBox.critical(None, "Startup Error", f"Failed to load UI: {e}\n\nSee logs/desktop_gui.log for details.")
            sys.exit(1)

    # pass api base to main window
    enable_timer = not args.no_refresh if hasattr(args, 'no_refresh') else True
    window = MainDashboard(api_base=args.api, enable_timer=enable_timer)
    window.show()
    sys.exit(app.exec())

if __name__ == '__main__':
    main()
