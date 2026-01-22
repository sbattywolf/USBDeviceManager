import json
import os
from gui.ui.dialogs import JSONViewerDialog
from gui.ui.main_window import MainDashboard


def test_jsonviewer_shows_text(qtbot):
    sample = {"hello": "world", "list": [1, 2, 3]}
    text = json.dumps(sample, indent=2)
    dlg = JSONViewerDialog('Test', text)
    qtbot.addWidget(dlg)
    # ensure the dialog has the text we expect
    assert dlg.text.toPlainText() == text


def test_main_dashboard_opens_jsonviewer(qtbot, monkeypatch):
    # Replace JSONViewerDialog in the main_window module with a spy to capture params
    captured = {}

    class FakeDialog:
        def __init__(self, title, text, parent=None):
            captured['title'] = title
            captured['text'] = text
            captured['parent'] = parent

        def exec(self):
            captured['exec_called'] = True

    monkeypatch.setattr('gui.ui.main_window.JSONViewerDialog', FakeDialog)

    # Create MainDashboard with a base that will trigger fallback data
    dashboard = MainDashboard(api_base='http://127.0.0.1:59999', enable_timer=False)
    qtbot.addWidget(dashboard)

    # Call show_endpoint for devices which should use ApiClient fallback and open the dialog
    dashboard.show_endpoint('/api/devices')

    assert captured.get('exec_called') is True
    assert '/api/devices' in captured.get('title')
    # parsed JSON should include our fallback device name
    assert 'Wheel Base' in captured.get('text')
