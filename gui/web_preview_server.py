import http.server
import socketserver
import logging
import os

PORT = 8000
# Serve the dedicated `web_preview` folder (so index.html and assets load correctly)
ROOT = os.path.join(os.path.dirname(__file__), 'web_preview')
os.makedirs(os.path.join(ROOT, 'logs'), exist_ok=True)
os.makedirs(os.path.join(os.path.dirname(__file__), 'logs'), exist_ok=True)
logging.basicConfig(filename=os.path.join(os.path.dirname(__file__), 'logs', 'web_preview.log'), level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

class PreviewHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def log_message(self, format, *args):
        logging.info(format % args)

    def send_error(self, code, message=None, explain=None):
        logging.error('HTTP error %s %s', code, message)
        super().send_error(code, message, explain)

def run():
    with socketserver.TCPServer(('127.0.0.1', PORT), PreviewHandler) as httpd:
        logging.info('Serving web preview at http://127.0.0.1:%d', PORT)
        print(f'Web preview available at http://127.0.0.1:{PORT}/')
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass

if __name__ == '__main__':
    run()
