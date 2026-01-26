"""Launcher for debug sessions: starts mock API server then runs the desktop GUI.

Usage: run with the same Python interpreter used for the GUI (venv).
"""
import subprocess
import sys
import os
import signal

HERE = os.path.dirname(__file__)
MOCK = os.path.join(HERE, 'mock_stub.py')
# Launch GUI as a module from the repository root so the `gui` package is importable
REPO_ROOT = os.path.dirname(HERE)

def main():
    # Start mock server as a subprocess
    print('Starting mock API server...')
    mock_proc = subprocess.Popen([sys.executable, MOCK], cwd=HERE)
    try:
        print('Starting GUI (module)...')
        # Launch the GUI as a module from the repository root so `import gui.*` works
        gui_proc = subprocess.Popen([sys.executable, '-m', 'gui.main', '--api', 'http://localhost:5000'], cwd=REPO_ROOT)
        gui_proc.wait()
    except KeyboardInterrupt:
        print('Interrupted by user')
    finally:
        try:
            print('Stopping mock server...')
            mock_proc.send_signal(signal.SIGINT)
            mock_proc.wait(timeout=5)
        except Exception:
            mock_proc.kill()

if __name__ == '__main__':
    main()
