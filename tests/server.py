#!/usr/bin/env python3
"""Local manual integration fixture: no third-party accounts required."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import base64
import argparse

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/engine/redirect':
            self.send_response(302)
            self.send_header('Location', '/engine/')
            self.end_headers()
            return
        if self.path.startswith('/engine/'):
            body = '''<!doctype html><meta charset="utf-8"><title>Assembly Engine Fixture</title>
            <style>body { color: red }</style>
            <h1>Built from assembly</h1>
            <p>This page is parsed and wrapped by the experimental assembly engine. Native text services draw the glyphs. WebKit is available from the Navigate menu when you need it.</p>
            <h2>Text, structure &amp; links</h2>
            <p>Unicode stays readable: café, naïve, &#x1F310;. Entities work: &lt;tag&gt; &quot;quotes&quot;.</p>
            <ul><li>Paragraphs and headings</li><li>Comments and scripts are excluded</li><li>Relative HTTP(S) links navigate inside the engine</li></ul>
            <pre>    assembly layout
    preserves indentation
      and line breaks</pre>
            <p><a href="second?one=1&amp;two=2">Open the second page</a> · <a href="/engine/redirect">Follow a redirect</a></p>
            <p><a href="javascript:alert(1)">Script URL (never executable)</a></p>
            <script>document.write('SCRIPT MUST NOT RUN')</script><!-- COMMENT MUST NOT RENDER -->'''
            if self.path.startswith('/engine/second'):
                body = '<!doctype html><meta charset="utf-8"><title>Second Assembly Page</title><h1>Link navigation works</h1><p>This is the second page. Use Back to return.</p><p><a href="/engine/">Return to the fixture</a></p>'
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(body.encode())
            return
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
    parser = argparse.ArgumentParser()
    parser.add_argument('--port', type=int, default=8765)
    args = parser.parse_args()
    print(f'Open http://localhost:{args.port} — /engine/ for the assembly fixture; HTTP auth: test / browser', flush=True)
    ThreadingHTTPServer(('127.0.0.1', args.port), Handler).serve_forever()
