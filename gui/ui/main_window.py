import os
import json
import time
import requests
import logging
from PyQt6.QtWidgets import (QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
                             QTableWidget, QTableWidgetItem, QPushButton,
                             QLabel, QHeaderView, QMessageBox, QTextEdit,
                             QTabWidget, QFrame)
from PyQt6.QtCore import Qt, QTimer, QUrl
from PyQt6.QtGui import QDesktopServices, QPixmap
from gui.api_client import ApiClient
from gui.screenshot import capture_screenshot
try:
    from gui.signals import notifier
except Exception:
    notifier = None
from .dialogs import EditDeviceDialog, JSONViewerDialog

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
        # Always perform an initial one-time refresh (safely)
        try:
            self.refresh_all()
        except Exception:
            logging.exception("Initial refresh_all() failed")

    def setup_ui(self):
        try:
            central_widget = QWidget()
            self.setCentralWidget(central_widget)
            main_layout = QVBoxLayout(central_widget)

            # Apply base stylesheet matching mockup palette
            self.setStyleSheet('''
                QWidget { background: #f4f7fb; color: #0b2a2a; font-family: Inter, Arial, sans-serif; }
                QPushButton { background: #ffffff; border: 1px solid #e6eef8; padding: 6px 10px; border-radius: 6px }
                QPushButton#nav { background: transparent; text-align: left; padding: 10px; font-weight: 600 }
                QLabel.title { font-weight: 700; font-size: 18px; color: #0b2a2a }
                QLabel.kpi { font-weight: 800; font-size: 28px; color: #062e2a }
                QLabel.muted { color: #6b7280; font-size: 12px }
                QTabWidget::pane { border: none; }
            ''')

            # Banner shown when using simulated/fallback data
            self.sim_banner = QLabel("")
            self.sim_banner.setStyleSheet('background-color: #ffcccc; color: #660000; padding: 6px;')
            self.sim_banner.setVisible(False)
            main_layout.addWidget(self.sim_banner)
            # Top bar (title + controls)
            header_layout = QHBoxLayout()
            top_title = QLabel("Dashboard")
            top_title.setObjectName('topTitle')
            top_title.setProperty('class', 'title')
            top_title.setStyleSheet("font-weight:700; font-size:20px; color: white; background: linear-gradient(90deg,#06b39a,#0aa99d); padding:10px 16px; border-radius:8px")
            header_layout.addWidget(top_title)
            header_layout.addStretch()
            self.lbl_summary = QLabel("Devices: 0 | Running: 0")
            self.lbl_summary.setStyleSheet('color:#e6fffb')
            header_layout.addWidget(self.lbl_summary)
            btn_refresh = QPushButton("Refresh")
            btn_refresh.clicked.connect(self.refresh_all)
            header_layout.addWidget(btn_refresh)
            main_layout.addLayout(header_layout)

            # Quick endpoint links (main page links) with last-fetch badges
            endpoints = ['/health', '/health/ready', '/api/health', '/api/devices', '/api/software', '/api/agents']
            endpoints_layout = QHBoxLayout()
            endpoints_layout.setSpacing(6)
            self.endpoint_time_labels = {}
            for ep in endpoints:
                # create vertical group for button + small label
                container = QWidget()
                v = QVBoxLayout(container)
                v.setContentsMargins(0, 0, 0, 0)
                b = QPushButton(ep)
                b.setToolTip(f"GET {ep}")
                b.clicked.connect(lambda _, p=ep: self.show_endpoint(p))
                lbl = QLabel('Last: -')
                lbl.setStyleSheet('color: #666666; font-size: 11px;')
                lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
                v.addWidget(b)
                v.addWidget(lbl)
                endpoints_layout.addWidget(container)
                self.endpoint_time_labels[ep] = lbl
            main_layout.addLayout(endpoints_layout)

            # Main content area with left navigation and right pages
            content_layout = QHBoxLayout()

            # Left navigation pane
            nav_widget = QFrame()
            nav_widget.setFrameShape(QFrame.Shape.StyledPanel)
            nav_widget.setFixedWidth(220)
            nav_widget.setStyleSheet('background: rgba(10,169,157,0.06); padding:12px; border-radius:10px')
            nav_layout = QVBoxLayout(nav_widget)
            nav_layout.setContentsMargins(0, 0, 0, 0)
            nav_layout.setSpacing(6)
            btn_overview = QPushButton('Overview')
            btn_overview.setObjectName('nav')
            btn_devices = QPushButton('Devices')
            btn_devices.setObjectName('nav')
            btn_software = QPushButton('Software')
            btn_software.setObjectName('nav')
            btn_logs = QPushButton('Logs')
            btn_logs.setObjectName('nav')
            nav_layout.addWidget(btn_overview)
            nav_layout.addWidget(btn_devices)
            nav_layout.addWidget(btn_software)
            nav_layout.addWidget(btn_logs)
            nav_layout.addStretch()

            content_layout.addWidget(nav_widget)

            # Use a tabbed layout so each main resource has its own page
            self.tabs = QTabWidget()

            # Overview tab - build KPI cards and recent events to mirror mockup
            overview_page = QWidget()
            ov_layout = QVBoxLayout(overview_page)
            # KPI row
            kpi_row = QHBoxLayout()
            kpi_row.setSpacing(12)
            def make_card(title, value, chip_text, chip_color):
                w = QFrame()
                w.setObjectName('card')
                w.setStyleSheet('background:#ffffff; border:1px solid #e6eef8; border-radius:10px; padding:12px')
                l = QVBoxLayout(w)
                t = QLabel(title)
                t.setProperty('class', 'muted')
                v = QLabel(str(value))
                v.setProperty('class', 'kpi')
                chip = QLabel(chip_text)
                chip.setStyleSheet(f'background:{chip_color}; color:#fff; padding:6px 10px; border-radius:14px; font-weight:600')
                row = QHBoxLayout()
                col = QVBoxLayout()
                col.addWidget(t)
                col.addWidget(v)
                row.addLayout(col)
                row.addStretch()
                row.addWidget(chip)
                l.addLayout(row)
                return w

            kpi_row.addWidget(make_card('Server', 'Listening', 'Online', '#06b39a'))
            kpi_row.addWidget(make_card('Agent', 'Connected', '1 host', '#ffb86b'))
            kpi_row.addWidget(make_card('Devices', '0', 'New:0', '#0b7ff1'))
            kpi_row.addWidget(make_card('Processes', '0', 'Stable', '#6b7280'))
            ov_layout.addLayout(kpi_row)

            # Middle content: Recent Events + Quick Actions / Mini Chart
            mid = QHBoxLayout()
            recent = QFrame()
            recent.setStyleSheet('background:#ffffff; border:1px solid #e6eef8; border-radius:8px; padding:12px')
            recent.setMinimumWidth(620)
            r_layout = QVBoxLayout(recent)
            r_title = QLabel('Recent Events')
            r_title.setProperty('class','title')
            r_layout.addWidget(r_title)
            self.overview_activity = QTextEdit()
            self.overview_activity.setReadOnly(True)
            self.overview_activity.setFixedHeight(380)
            r_layout.addWidget(self.overview_activity)

            side = QVBoxLayout()
            quick = QFrame()
            quick.setStyleSheet('background:#ffffff; border:1px solid #e6eef8; border-radius:8px; padding:12px')
            q_layout = QVBoxLayout(quick)
            q_title = QLabel('Quick Actions')
            q_title.setProperty('class','title')
            q_layout.addWidget(q_title)
            # sample quick actions
            btn_refresh_devices = QPushButton('Refresh Devices')
            btn_refresh_devices.clicked.connect(self.refresh_all)
            q_layout.addWidget(btn_refresh_devices)

            btn_open_devices = QPushButton('Open Devices Page')
            btn_open_devices.clicked.connect(lambda: self.tabs.setCurrentIndex(1))
            q_layout.addWidget(btn_open_devices)

            btn_capture = QPushButton('Capture Screenshot')
            btn_capture.clicked.connect(lambda: self._quick_capture())
            q_layout.addWidget(btn_capture)
            mini = QFrame()
            mini.setStyleSheet('background:#ffffff; border:1px solid #e6eef8; border-radius:8px; padding:12px')
            mini.setFixedHeight(200)
            m_layout = QVBoxLayout(mini)
            m_title = QLabel('Mini Chart')
            m_title.setProperty('class','title')
            m_layout.addWidget(m_title)
            m_layout.addWidget(QLabel('(chart placeholder)'))

            side.addWidget(quick)
            side.addWidget(mini)
            mid.addWidget(recent)
            mid.addLayout(side)
            ov_layout.addLayout(mid)

            self.tabs.addTab(overview_page, "Overview")

            # Devices tab
            dev_page = QWidget()
            dev_layout = QVBoxLayout(dev_page)
            self.table_devices = QTableWidget(0, 5)
            self.table_devices.setHorizontalHeaderLabels(["Friendly Name", "Hardware ID", "Status", "Last Seen", "Actions"])
            self.table_devices.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
            dev_layout.addWidget(self.table_devices)
            self.tabs.addTab(dev_page, "Devices")

            # Software tab
            sw_page = QWidget()
            sw_layout = QVBoxLayout(sw_page)
            self.table_software = QTableWidget(0, 5)
            self.table_software.setHorizontalHeaderLabels(["Name", "Executable Path", "Status", "Auto Start", "Actions"])
            self.table_software.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
            sw_layout.addWidget(self.table_software)
            self.tabs.addTab(sw_page, "Software")

            # Logs tab (move activity log into a page)
            logs_page = QWidget()
            logs_layout = QVBoxLayout(logs_page)
            self.log_label = QLabel("Activity Log")
            logs_layout.addWidget(self.log_label)
            # Inline thumbnail preview for the most recent screenshot
            self.screenshot_thumb = QLabel()
            self.screenshot_thumb.setFixedSize(320, 180)
            self.screenshot_thumb.setStyleSheet('border: 1px solid #cccccc; background: #111; color: #fff;')
            self.screenshot_thumb.setAlignment(Qt.AlignmentFlag.AlignCenter)
            self.screenshot_thumb.setText('No screenshot')
            logs_layout.addWidget(self.screenshot_thumb)
            btn_view = QPushButton('View Latest Screenshot')
            btn_view.setToolTip('Open the most recent screenshot captured by the app')
            btn_view.clicked.connect(self.open_latest_screenshot)
            logs_layout.addWidget(btn_view)
            self.log_view = QTextEdit()
            self.log_view.setReadOnly(True)
            logs_layout.addWidget(self.log_view)
            self.tabs.addTab(logs_page, "Logs")
            # Refresh thumbnail when Logs tab becomes active
            try:
                self.tabs.currentChanged.connect(lambda idx: self.refresh_latest_thumbnail() if idx == self.tabs.indexOf(logs_page) else None)
            except Exception:
                pass
            # Listen for screenshot events so thumbnail updates instantly
            try:
                if notifier is not None:
                    notifier.screenshot_captured.connect(self.on_new_screenshot)
            except Exception:
                logging.exception('Failed to connect to screenshot notifier')
            content_layout.addWidget(self.tabs, 1)

            main_layout.addLayout(content_layout)

            # Wire up navigation buttons to switch tabs
            btn_overview.clicked.connect(lambda: self.tabs.setCurrentIndex(0))
            btn_devices.clicked.connect(lambda: self.tabs.setCurrentIndex(1))
            btn_software.clicked.connect(lambda: self.tabs.setCurrentIndex(2))
            btn_logs.clicked.connect(lambda: self.tabs.setCurrentIndex(3))
        except Exception:
            logging.exception('Failed to build UI')
            try:
                path = capture_screenshot('ui_setup_error')
                try:
                    # persist to activity log so thumbnail can pick it up
                    if path:
                        self.append_log(f'ui_setup_error screenshot={path}')
                except Exception:
                    logging.exception('Failed to append ui_setup_error to activity log')
                QMessageBox.critical(self, 'UI Error', f'Failed to initialize the UI. See logs/desktop_gui.log for details. Screenshot: {path if path else "n/a"}')
            except Exception:
                pass

    def refresh_all(self):
        try:
            devices = self.api.get_devices() or []
            software = self.api.get_software() or []
        except Exception:
            logging.exception('refresh_all top-level failure')
            try:
                path = capture_screenshot('refresh_error')
                self.append_log(f'refresh_all failed; screenshot={path}')
            except Exception:
                logging.exception('Failed to capture screenshot for refresh_all')
            return

        # Log API responses into activity log for debugging
        try:
            self.append_log(f"GET /api/devices -> {json.dumps(devices, default=str)[:1000]}")
        except Exception:
            try:
                self.append_log(f"GET /api/devices -> {str(devices)}")
            except Exception:
                pass
        try:
            self.append_log(f"GET /api/software -> {json.dumps(software, default=str)[:1000]}")
        except Exception:
            try:
                self.append_log(f"GET /api/software -> {str(software)}")
            except Exception:
                pass

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

        # Update overview summary if present
        try:
            if hasattr(self, 'overview_summary'):
                self.overview_summary.setText(f"Devices: {len(devices)} | Software: {len(software)}")
        except Exception:
            pass

        # Show simulated-data banner if API client used fallback
        try:
            if hasattr(self.api, 'last_simulated') and self.api.last_simulated:
                self.sim_banner.setText('Using simulated/fallback data (backend unreachable)')
                self.sim_banner.setVisible(True)
            else:
                self.sim_banner.setVisible(False)
        except Exception:
            pass

        # Update timestamps for devices/software
        try:
            ts = time.strftime('%Y-%m-%d %H:%M:%S')
            sim_suffix = ' (sim)' if getattr(self.api, 'last_simulated', False) else ''
            if '/api/devices' in self.endpoint_time_labels:
                self.endpoint_time_labels['/api/devices'].setText(f'Last: {ts}{sim_suffix}')
            if '/api/software' in self.endpoint_time_labels:
                self.endpoint_time_labels['/api/software'].setText(f'Last: {ts}{sim_suffix}')
        except Exception:
            pass

        # Populate overview recent activity from persisted log
        try:
            if hasattr(self, 'overview_activity'):
                log_path = os.path.join('logs', 'desktop_activity.log')
                if os.path.exists(log_path):
                    with open(log_path, 'r', encoding='utf-8') as fh:
                        lines = fh.readlines()
                    # show last 50 lines
                    tail = ''.join(lines[-50:]) if lines else ''
                    self.overview_activity.setPlainText(tail)
                else:
                    self.overview_activity.setPlainText('')
        except Exception:
            pass

    def show_endpoint(self, path: str):
        """Fetch the given endpoint and display its JSON in the activity log.
        If the endpoint is devices/software, refresh the corresponding tables.
        """
        try:
            # Use ApiClient helpers for known endpoints
            if path == '/api/devices':
                self.append_log('Manual refresh: /api/devices')
                devices = self.api.get_devices() or []
                # refresh tables
                self.refresh_all()
                try:
                    pretty = json.dumps(devices, indent=2)
                except Exception:
                    pretty = str(devices)
                dlg = JSONViewerDialog(f'GET {path}', pretty, parent=self)
                dlg.exec()
                return
            if path == '/api/software':
                self.append_log('Manual refresh: /api/software')
                software = self.api.get_software() or []
                self.refresh_all()
                try:
                    pretty = json.dumps(software, indent=2)
                except Exception:
                    pretty = str(software)
                dlg = JSONViewerDialog(f'GET {path}', pretty, parent=self)
                dlg.exec()
                return

            # Generic GET for other endpoints
            try:
                r = requests.get(f"{self.api.base.rstrip('/')}{path}", timeout=5)
                r.raise_for_status()
                body = r.json() if r.headers.get('Content-Type','').startswith('application/json') else r.text
                pretty = json.dumps(body, indent=2) if isinstance(body, (dict, list)) else str(body)
                self.append_log(f"GET {path} -> {pretty[:2000]}")
                # show full JSON in modal
                dlg = JSONViewerDialog(f'GET {path}', pretty, parent=self)
                dlg.exec()
                # update timestamp badge
                try:
                    ts = time.strftime('%Y-%m-%d %H:%M:%S')
                    sim_suffix = ' (sim)' if getattr(self.api, 'last_simulated', False) else ''
                    if path in self.endpoint_time_labels:
                        self.endpoint_time_labels[path].setText(f'Last: {ts}{sim_suffix}')
                except Exception:
                    pass
            except Exception as e:
                # Show error and fall back to ApiClient if it can help
                self.append_log(f"GET {path} failed: {e}")
                try:
                    p = capture_screenshot('show_endpoint_error')
                    if p:
                        self.append_log(f'show_endpoint_error screenshot={p}')
                except Exception:
                    logging.exception('Failed to capture screenshot for show_endpoint error')
        except Exception:
            logging.exception('show_endpoint failed for %s', path)

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
            try:
                p = capture_screenshot('toggle_error')
                if p:
                    self.append_log(f'toggle_error screenshot={p}')
            except Exception:
                logging.exception('Failed to capture screenshot for toggle_device error')
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
            try:
                p = capture_screenshot('start_software_error')
                if p:
                    self.append_log(f'start_software_error screenshot={p}')
            except Exception:
                logging.exception('Failed to capture screenshot for start_software error')
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
            try:
                p = capture_screenshot('stop_software_error')
                if p:
                    self.append_log(f'stop_software_error screenshot={p}')
            except Exception:
                logging.exception('Failed to capture screenshot for stop_software error')
            QMessageBox.critical(self, "Error", f"Stop failed: {msg}")
        self.refresh_all()

    def append_log(self, message: str):
        ts = time.strftime('%Y-%m-%d %H:%M:%S')
        try:
            entry = f"[{ts}] {message}"
            self.log_view.append(entry)
            # Also persist to a file for post-mortem
            try:
                os.makedirs('logs', exist_ok=True)
                with open(os.path.join('logs', 'desktop_activity.log'), 'a', encoding='utf-8') as fh:
                    fh.write(entry + '\n')
            except Exception:
                logging.exception('Failed to write desktop_activity.log')
            # Refresh inline thumbnail if a new screenshot may have been saved
            try:
                # Best-effort: update thumbnail whenever logs change
                if hasattr(self, 'screenshot_thumb'):
                    self.refresh_latest_thumbnail()
            except Exception:
                logging.exception('Failed to refresh screenshot thumbnail')
        except Exception:
            pass

    def refresh_latest_thumbnail(self):
        try:
            folder = os.path.join('logs', 'screenshots')
            if not os.path.isdir(folder):
                self.screenshot_thumb.setText('No screenshot')
                self.screenshot_thumb.setPixmap(QPixmap())
                return
            files = [os.path.join(folder, f) for f in os.listdir(folder) if f.lower().endswith('.png')]
            if not files:
                self.screenshot_thumb.setText('No screenshot')
                self.screenshot_thumb.setPixmap(QPixmap())
                return
            latest = max(files, key=os.path.getmtime)
            pix = QPixmap(latest)
            if pix and not pix.isNull():
                scaled = pix.scaled(self.screenshot_thumb.width(), self.screenshot_thumb.height(), Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
                self.screenshot_thumb.setPixmap(scaled)
                self.screenshot_thumb.setText('')
            else:
                self.screenshot_thumb.setText('Could not load')
        except Exception:
            logging.exception('Failed to refresh_latest_thumbnail')

    def on_new_screenshot(self, path: str):
        """Called when a new screenshot file has been created elsewhere in the app.
        Load and display the provided image path immediately.
        """
        try:
            if not path or not os.path.exists(path):
                # fallback to scanning the folder
                self.refresh_latest_thumbnail()
                return
            pix = QPixmap(path)
            if pix and not pix.isNull():
                scaled = pix.scaled(self.screenshot_thumb.width(), self.screenshot_thumb.height(), Qt.AspectRatioMode.KeepAspectRatio, Qt.TransformationMode.SmoothTransformation)
                self.screenshot_thumb.setPixmap(scaled)
                self.screenshot_thumb.setText('')
            else:
                self.screenshot_thumb.setText('Could not load')
        except Exception:
            logging.exception('on_new_screenshot failed')

    def open_latest_screenshot(self):
        try:
            folder = os.path.join('logs', 'screenshots')
            if not os.path.isdir(folder):
                QMessageBox.information(self, 'No screenshots', 'No screenshots found.')
                return
            files = [os.path.join(folder, f) for f in os.listdir(folder) if f.lower().endswith('.png')]
            if not files:
                QMessageBox.information(self, 'No screenshots', 'No screenshots found.')
                return
            latest = max(files, key=os.path.getmtime)
            # Try to open with the system default viewer
            opened = QDesktopServices.openUrl(QUrl.fromLocalFile(os.path.abspath(latest)))
            if not opened:
                QMessageBox.information(self, 'Open screenshot', f'Could not open {latest}.')
            else:
                self.append_log(f'Opened screenshot: {latest}')
        except Exception as e:
            logging.exception('Failed to open latest screenshot')
            QMessageBox.critical(self, 'Error', f'Failed to open latest screenshot: {e}')

    def _quick_capture(self):
        """Handler for Overview quick-action 'Capture Screenshot' button."""
        try:
            path = capture_screenshot('manual_inspect')
            if path:
                self.append_log(f'QuickCapture saved={path}')
                QMessageBox.information(self, 'Screenshot', f'Screenshot saved: {path}')
            else:
                QMessageBox.warning(self, 'Screenshot', 'Failed to capture screenshot (no primary screen available)')
        except Exception as e:
            logging.exception('Quick capture failed')
            QMessageBox.critical(self, 'Error', f'Failed to capture screenshot: {e}')
