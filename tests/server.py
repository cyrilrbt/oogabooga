#!/usr/bin/env python3
"""Local manual integration fixture: no third-party accounts required."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import base64

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/auth' and self.headers.get('Authorization') != 'Basic ' + base64.b64encode(b'test:browser').decode():
            self.send_response(401)
            self.send_header('WWW-Authenticate', 'Basic realm="Browser test"')
            self.end_headers()
            return
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        if self.path == '/cookie':
            self.send_header('Set-Cookie', 'browser_test=persisted; Max-Age=86400; HttpOnly; SameSite=Lax; Path=/')
        self.end_headers()
        if self.path == '/popup':
            body = '<button onclick="window.opener.document.title=\'Popup OK\';window.close()">Complete popup</button>'
        else:
            cookie = 'PASS: persistent cookie received' if 'browser_test=persisted' in self.headers.get('Cookie', '') else 'No test cookie received yet'
            body = f'''<h1>Oogabooga browser test</h1><p>{cookie}</p>
            <p>{'PASS: HTTP authentication' if self.path == '/auth' else ''}</p>
            <p><a href="/cookie">Set persistent cookie</a> · <a href="/">Check cookie</a> · <a href="/auth">HTTP auth (test / browser)</a></p>
            <button onclick="window.open('/popup','auth','width=500,height=400')">Test login popup</button>
            <p><a href="/second">Second page for back/forward</a></p>'''
        self.wfile.write(('<!doctype html><meta charset="utf-8"><title>Browser fixture</title><style>body{font:18px system-ui;max-width:850px;margin:60px auto;background:#f5f3ee;color:#222}a{color:#245bc0}button{padding:12px}</style>' + body).encode())

if __name__ == '__main__':
    print('Open http://localhost:8765 — HTTP auth: test / browser', flush=True)
    ThreadingHTTPServer(('127.0.0.1', 8765), Handler).serve_forever()
