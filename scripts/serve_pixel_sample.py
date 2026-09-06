"""Serve the actual Godot Web export on loopback only."""
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
from urllib.parse import unquote, urlsplit
import socket

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'godot-client/web'
LIBRARY=ROOT/'asset-library'
class Handler(SimpleHTTPRequestHandler):
    def __init__(self,*args,**kwargs):super().__init__(*args,directory=str(BASE),**kwargs)
    def translate_path(self,path):
        route=unquote(urlsplit(path).path)
        if route == '/library' or route.startswith('/library/'):
            relative=route[len('/library'):].lstrip('/')
            target=(LIBRARY/relative).resolve()
            if not target.is_relative_to(LIBRARY.resolve()):
                return str(LIBRARY/'__invalid_path__')
            return str(target)
        return super().translate_path(path)
    def end_headers(self):
        self.send_header('Cross-Origin-Opener-Policy','same-origin')
        self.send_header('Cross-Origin-Embedder-Policy','require-corp')
        self.send_header('Cache-Control','no-cache')
        super().end_headers()

print('Godot sample: http://127.0.0.1:8780/',flush=True)
print('Asset library: http://127.0.0.1:8780/library/',flush=True)
class LocalServer(ThreadingHTTPServer):
    allow_reuse_address=False
    def server_bind(self):
        # Windows SO_REUSEADDR can let two preview servers receive requests
        # on the same port. Fail clearly instead of serving mixed versions.
        if hasattr(socket,'SO_EXCLUSIVEADDRUSE'):
            self.socket.setsockopt(socket.SOL_SOCKET,socket.SO_EXCLUSIVEADDRUSE,1)
        super().server_bind()

if __name__=='__main__':
    LocalServer(('127.0.0.1',8780),Handler).serve_forever()
