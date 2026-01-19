import os
import json
import time
import requests
from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
                             QTableWidget, QTableWidgetItem, QPushButton,
                             QLabel, QHeaderView, QMessageBox, QTextEdit)
from PyQt6.QtCore import Qt, QTimer
from .dialogs import EditDeviceDialog

class ApiClient:
    def __init__(self, base_url):
        self.base = base_url.rstrip('/')

    def get_devices(self):
        try:
            r = requests.get(f"{self.base}/api/devices", timeout=5)
            r.raise_for_status()
            return r.json()
        except Exception:
            return []

    def get_software(self):
        try:
            r = requests.get(f"{self.base}/api/software", timeout=5)
            r.raise_for_status()
            return r.json()
        except Exception:
            return []

    def post(self, path, data=None):
        try:
            r = requests.post(f"{self.base}{path}", json=data, timeout=5)
            r.raise_for_status()
            try:
                return True, r.json()
            except ValueError:
                return True, r.text
        except Exception as e:
            return False, str(e)

class MainDashboard(QMainWindow):
    def __init__(self, api_base='http://localhost:5000', enable_timer: bool = True):
        super().__init__()
        self.setWindowTitle("USB Device Manager - Desktop")
        self.resize(1000, 700)
        self.api = ApiClient(api_base)
        self.setup_ui()
        self.enable_timer = enable_timer
        if self.enable_timer:
            self.refresh_timer = QTimer()
            self.refresh_timer.timeout.connect(self.refresh_all)
            self.refresh_timer.start(5000)
        # Always perform an initial one-time refresh
        self.refresh_all()

    def setup_ui(self):
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        main_layout = QVBoxLayout(central_widget)
        header_layout = QHBoxLayout()
        self.lbl_summary = QLabel("Devices: 0 | Running: 0")
        header_layout.addWidget(self.lbl_summary)
        btn_refresh = QPushButton("Refresh")
        btn_refresh.clicked.connect(self.refresh_all)
        header_layout.addWidget(btn_refresh)
        main_layout.addLayout(header_layout)

        self.table_devices = QTableWidget(0, 5)
        self.table_devices.setHorizontalHeaderLabels(["Friendly Name", "Hardware ID", "Status", "Last Seen", "Actions"])
        self.table_devices.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        main_layout.addWidget(self.table_devices)

        self.table_software = QTableWidget(0, 5)
        self.table_software.setHorizontalHeaderLabels(["Name", "Executable Path", "Status", "Auto Start", "Actions"])
        self.table_software.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        main_layout.addWidget(self.table_software)

        # Activity log for request/response traces
        self.log_label = QLabel("Activity Log")
        main_layout.addWidget(self.log_label)
        self.log_view = QTextEdit()
        self.log_view.setReadOnly(True)
        self.log_view.setFixedHeight(160)
        main_layout.addWidget(self.log_view)

    def refresh_all(self):
        devices = self.api.get_devices() or []
        software = self.api.get_software() or []

        # Devices
        self.table_devices.setRowCount(0)
        for d in devices:
            row = self.table_devices.rowCount()
            self.table_devices.insertRow(row)
            self.table_devices.setItem(row, 0, QTableWidgetItem(d.get('Name') or d.get('name') or ''))
            self.table_devices.setItem(row, 1, QTableWidgetItem(d.get('DeviceId') or d.get('deviceId') or ''))
            self.table_devices.setItem(row, 2, QTableWidgetItem('Enabled' if d.get('IsEnabled') else 'Disabled'))
            self.table_devices.setItem(row, 3, QTableWidgetItem(str(d.get('LastSeen') or '')))
            btn_box = QWidget()
            btn_layout = QHBoxLayout(btn_box)
            btn_layout.setContentsMargins(0,0,0,0)
            toggle = QPushButton('Toggle')
            toggle.clicked.connect(lambda ch, id=d.get('Id') or d.get('id'): self.toggle_device(id))
            btn_layout.addWidget(toggle)
            self.table_devices.setCellWidget(row, 4, btn_box)

        # Software
        self.table_software.setRowCount(0)
        for s in software:
            row = self.table_software.rowCount()
            self.table_software.insertRow(row)
            self.table_software.setItem(row, 0, QTableWidgetItem(s.get('Name') or s.get('name') or ''))
            self.table_software.setItem(row, 1, QTableWidgetItem(s.get('ExecutablePath') or s.get('executablePath') or ''))
            self.table_software.setItem(row, 2, QTableWidgetItem('Running' if s.get('IsRunning') else 'Stopped'))
            self.table_software.setItem(row, 3, QTableWidgetItem('Yes' if s.get('AutoStart') else 'No'))
            btn_box = QWidget()
            btn_layout = QHBoxLayout(btn_box)
            btn_layout.setContentsMargins(0,0,0,0)
            start_btn = QPushButton('Start')
            start_btn.clicked.connect(lambda ch, id=s.get('Id') or s.get('id'): self.start_software(id))
            stop_btn = QPushButton('Stop')
            stop_btn.clicked.connect(lambda ch, id=s.get('Id') or s.get('id'): self.stop_software(id))
            btn_layout.addWidget(start_btn)
            btn_layout.addWidget(stop_btn)
            self.table_software.setCellWidget(row, 4, btn_box)

        self.lbl_summary.setText(f"Devices: {len(devices)} | Software: {len(software)}")

    def toggle_device(self, device_id):
        # Determine current state from the API and send explicit JSON boolean body
        try:
            devices = self.api.get_devices() or []
            current = None
            for d in devices:
                if (d.get('Id') == device_id) or (d.get('id') == device_id):
                    val = d.get('IsEnabled')
                    if val is None:
                        val = d.get('isEnabled')
                    current = val
                    break

            if current is None:
                # fallback: toggle to true
                toggle_value = True
            else:
                toggle_value = not bool(current)

            ok, msg = self.api.post(f"/api/devices/{device_id}/toggle", data=toggle_value)
            # Log the response
            try:
                disp = json.dumps(msg, default=str) if isinstance(msg, (dict, list)) else str(msg)
            except Exception:
                disp = str(msg)
            self.append_log(f"POST /api/devices/{device_id}/toggle -> {disp}")
            if not ok:
                QMessageBox.critical(self, "Error", f"Toggle failed: {msg}")
        except Exception as e:
            QMessageBox.critical(self, "Error", f"Toggle failed: {e}")

        self.refresh_all()

    def start_software(self, software_id):
        ok, msg = self.api.post(f"/api/software/{software_id}/start")
        try:
            disp = json.dumps(msg, default=str) if isinstance(msg, (dict, list)) else str(msg)
        except Exception:
            disp = str(msg)
        self.append_log(f"POST /api/software/{software_id}/start -> {disp}")
        if not ok:
            QMessageBox.critical(self, "Error", f"Start failed: {msg}")
        self.refresh_all()

    def stop_software(self, software_id):
        ok, msg = self.api.post(f"/api/software/{software_id}/stop")
        try:
            disp = json.dumps(msg, default=str) if isinstance(msg, (dict, list)) else str(msg)
        except Exception:
            disp = str(msg)
        self.append_log(f"POST /api/software/{software_id}/stop -> {disp}")
        if not ok:
            QMessageBox.critical(self, "Error", f"Stop failed: {msg}")
        self.refresh_all()

    def append_log(self, message: str):
        ts = time.strftime('%Y-%m-%d %H:%M:%S')
        try:
            self.log_view.append(f"[{ts}] {message}")
        except Exception:
            pass
