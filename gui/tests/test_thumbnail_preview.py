import os
from PyQt6.QtGui import QPixmap, QColor

from gui.ui.main_window import MainDashboard


def test_thumbnail_updates(tmp_path, qtbot):
    """Create a dummy PNG in logs/screenshots and ensure the Logs tab thumbnail updates."""
    # Run the app with a temporary cwd so it uses tmp_path/logs
    oldcwd = os.getcwd()
    os.chdir(str(tmp_path))
    try:
        # Ensure logs/screenshots exists
        (tmp_path / 'logs' / 'screenshots').mkdir(parents=True, exist_ok=True)

        main = MainDashboard(enable_timer=False)
        qtbot.addWidget(main)
        main.show()
        qtbot.waitForWindowShown(main)

        # Initially no screenshot
        main.refresh_latest_thumbnail()
        initial_pm = main.screenshot_thumb.pixmap()
        assert initial_pm is None or initial_pm.isNull()

        # Create a dummy PNG using QPixmap and save it into logs/screenshots
        img_path = tmp_path / 'logs' / 'screenshots' / 'dummy.png'
        pix = QPixmap(200, 120)
        pix.fill(QColor('blue'))
        saved = pix.save(str(img_path), 'PNG')
        assert saved

        # Trigger thumbnail refresh and ensure pixmap is now present
        main.refresh_latest_thumbnail()
        qtbot.wait(50)
        pm = main.screenshot_thumb.pixmap()
        assert pm is not None and not pm.isNull()
    finally:
        os.chdir(oldcwd)
