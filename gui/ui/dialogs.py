import os
from PyQt6.QtWidgets import (QDialog, QVBoxLayout, QLabel, QPushButton,
                             QProgressBar, QTextEdit, QFormLayout, QLineEdit,
                             QFileDialog, QHBoxLayout, QMessageBox, QCheckBox)
from PyQt6.QtCore import Qt

class ErrorDetailDialog(QDialog):
    def __init__(self, error_msg, detail_trace):
        super().__init__()
        self.setWindowTitle("Application Error")
        self.setMinimumSize(500, 400)
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel(f"<b>An unexpected error occurred:</b><br>{error_msg}"))
        self.details = QTextEdit()
        self.details.setPlainText(detail_trace)
        self.details.setReadOnly(True)
        layout.addWidget(self.details)
        btn_layout = QHBoxLayout()
        copy_btn = QPushButton("Copy to Clipboard")
        copy_btn.clicked.connect(self.copy_data)
        close_btn = QPushButton("Close")
        close_btn.clicked.connect(self.close)
        btn_layout.addWidget(copy_btn)
        btn_layout.addStretch()
        btn_layout.addWidget(close_btn)
        layout.addLayout(btn_layout)

    def copy_data(self):
        from PyQt6.QtWidgets import QApplication
        QApplication.clipboard().setText(self.details.toPlainText())
        QMessageBox.information(self, "Copied", "Error details copied to clipboard.")

class EditDeviceDialog(QDialog):
    def __init__(self, parent, device_info=None):
        super().__init__(parent)
        self.setWindowTitle("Configure Device / Software")
        self.setMinimumSize(450, 300)
        self.device_info = device_info or {}
        self.init_ui()

    def init_ui(self):
        layout = QFormLayout(self)
        self.name_edit = QLineEdit(self.device_info.get('name', ''))
        self.hw_id_edit = QLineEdit(self.device_info.get('hw_id', ''))
        self.hw_id_edit.setReadOnly(True) if 'hw_id' in self.device_info else None
        self.sw_path_edit = QLineEdit(self.device_info.get('sw_path', ''))
        self.browse_btn = QPushButton("Browse...")
        self.browse_btn.clicked.connect(self.browse_sw)
        sw_layout = QHBoxLayout()
        sw_layout.addWidget(self.sw_path_edit)
        sw_layout.addWidget(self.browse_btn)
        self.params_edit = QLineEdit(self.device_info.get('params', ''))
        self.minimize_check = QCheckBox("Start Minimized")
        self.minimize_check.setChecked(self.device_info.get('minimize', True))
        layout.addRow("Friendly Name:", self.name_edit)
        layout.addRow("Hardware ID:", self.hw_id_edit)
        layout.addRow("Software Executable:", sw_layout)
        layout.addRow("Startup Parameters:", self.params_edit)
        layout.addRow("", self.minimize_check)
        btns = QHBoxLayout()
        save_btn = QPushButton("Save Configuration")
        save_btn.clicked.connect(self.save_data)
        cancel_btn = QPushButton("Cancel")
        cancel_btn.clicked.connect(self.reject)
        btns.addWidget(save_btn)
        btns.addWidget(cancel_btn)
        layout.addRow(btns)

    def browse_sw(self):
        file_path, _ = QFileDialog.getOpenFileName(self, "Select Executable", "C:\\", "Executables (*.exe)")
        if file_path:
            self.sw_path_edit.setText(file_path)

    def save_data(self):
        if not self.name_edit.text() or not self.hw_id_edit.text():
            QMessageBox.warning(self, "Input Error", "Name and Hardware ID are required.")
            return
        self.result_data = {
            "name": self.name_edit.text(),
            "hw_id": self.hw_id_edit.text(),
            "sw_path": self.sw_path_edit.text(),
            "params": self.params_edit.text(),
            "minimize": self.minimize_check.isChecked()
        }
        self.accept()


class JSONViewerDialog(QDialog):
    def __init__(self, title: str, text: str, parent=None):
        super().__init__(parent)
        self.setWindowTitle(title or 'JSON Viewer')
        self.setMinimumSize(600, 400)
        layout = QVBoxLayout(self)
        self.text = QTextEdit()
        self.text.setReadOnly(True)
        self.text.setPlainText(text or '')
        layout.addWidget(self.text)
        btn_layout = QHBoxLayout()
        copy_btn = QPushButton('Copy')
        copy_btn.clicked.connect(self.copy_text)
        save_btn = QPushButton('Save...')
        save_btn.clicked.connect(self.save_text)
        close_btn = QPushButton('Close')
        close_btn.clicked.connect(self.close)
        btn_layout.addWidget(copy_btn)
        btn_layout.addWidget(save_btn)
        btn_layout.addStretch()
        btn_layout.addWidget(close_btn)
        layout.addLayout(btn_layout)

    def copy_text(self):
        from PyQt6.QtWidgets import QApplication
        QApplication.clipboard().setText(self.text.toPlainText())
        QMessageBox.information(self, 'Copied', 'JSON copied to clipboard.')

    def save_text(self):
        file_path, _ = QFileDialog.getSaveFileName(self, 'Save JSON', 'response.json', 'JSON Files (*.json);;All Files (*)')
        if file_path:
            try:
                with open(file_path, 'w', encoding='utf-8') as fh:
                    fh.write(self.text.toPlainText())
                QMessageBox.information(self, 'Saved', f'Saved to {file_path}')
            except Exception as e:
                QMessageBox.critical(self, 'Error', f'Failed to save file: {e}')
