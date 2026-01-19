import sys
import argparse
import logging
import traceback
import os
from PyQt6.QtWidgets import QApplication
from ui.main_window import MainDashboard
from ui.dialogs import ErrorDetailDialog

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
    error_dlg = ErrorDetailDialog(str(value), traceback_details)
    error_dlg.exec()
    sys.exit(1)

def main():
    sys.excepthook = exception_hook

    parser = argparse.ArgumentParser()
    parser.add_argument('--api', default='http://localhost:5000', help='Base URL for server API')
    parser.add_argument('--no-refresh', action='store_true', help='Disable periodic UI refresh')
    args = parser.parse_args()

    app = QApplication(sys.argv)

    # pass api base to main window
    enable_timer = not args.no_refresh if hasattr(args, 'no_refresh') else True
    window = MainDashboard(api_base=args.api, enable_timer=enable_timer)
    window.show()
    sys.exit(app.exec())

if __name__ == '__main__':
    main()
