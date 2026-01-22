from PyQt6.QtCore import QObject, pyqtSignal


class ScreenshotNotifier(QObject):
    screenshot_captured = pyqtSignal(str)


# Single shared notifier instance used across the GUI
notifier = ScreenshotNotifier()
