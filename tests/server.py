#!/usr/bin/env python3
"""Local manual integration fixture: no third-party accounts required."""
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import base64
import argparse
from pathlib import Path
from urllib.parse import urlsplit, parse_qs
from html import escape

class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlsplit(self.path).path
        fixture_files = {
            '/engine/features': ('fixtures/engine-features.html', 'text/html; charset=utf-8'),
            '/engine/features.css': ('fixtures/engine-features.css', 'text/css; charset=utf-8'),
            '/engine/image.png': ('engine-image.png', 'image/png'),
        }
        if path in fixture_files:
            file, mime = fixture_files[path]
            data = (Path(__file__).parent / file).read_bytes()
            self.send_response(200)
            self.send_header('Content-Type', mime)
            self.send_header('Content-Length', str(len(data)))
            self.end_headers()
            self.wfile.write(data)
            return
        if path == '/engine/missing.png':
            self.send_error(404)
            return
        if path == '/engine/result':
            query = parse_qs(urlsplit(self.path).query)
            body = '<title>GET Result</title><h1>Form submitted</h1><p>' + escape(str(query)) + '</p><p><a href="features">Return to features</a></p>'
            self.send_response(200)
            self.send_header('Content-Type', 'text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(body.encode())
            return
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
            if self.path.startswith('/engine/css'):
                body = '''<!doctype html><meta charset="utf-8"><title>Assembly CSS Gallery</title>
                <style>
                body { background: #f6f1e7; color: #293747; font-family: Arial, sans-serif; font-size: 16px; line-height: 1.5; }
                h1 { color: #2450aa; font-size: 32px; margin: 8px 0 12px; }
                h2 { color: #7842a8; font-size: 22px; }
                .notice { background-color: #fff0c2; margin: 12px 16px; }
                #priority { color: #18623b; font-weight: 700; }
                body .detail { font-style: italic; }
                .hidden { display: none; }
                .center { text-align: center; }
                a { color: #1958a8; text-decoration: underline; }
                </style>
                <h1>CSS, from assembly</h1>
                <p>The engine parses these rules, matches selectors, resolves the cascade, and computes styles in handwritten ARM64 assembly.</p>
                <h2>Colors and typography</h2>
                <p class="notice">Named, hex, and rgb() colors; serif, sans-serif, and monospace font families; relative font sizes and line heights.</p>
                <p class="detail">This paragraph inherits its color and font family, with an italic descendant rule.</p>
                <p id="priority" class="detail">ID, class, and type selectors participate in the cascade.</p>
                <p style="color: #a0334c; font-size: 20px; margin: 10px 0">Inline styles work, too.</p>
                <p class="center">Centered paragraphs with native glyph shaping.</p>
                <p class="hidden">HIDDEN CONTENT MUST NOT RENDER 🌐</p>
                <p><a href="/engine/second">Links still work after hidden Unicode content</a></p>
                <p>This is a text-flow CSS subset. Linked sheets, boxes, images, and GET forms are available in the <a href="/engine/features">features fixture</a>. Flex/grid, positioning, and JavaScript are not implemented.</p>'''
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
