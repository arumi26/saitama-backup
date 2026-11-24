#!/usr/bin/env python3
"""Minimal static server for the two-origin postMessage PoC harness.

Usage:
    python3 serve.py <root-dir> <port>

Run it TWICE on two different ports so host and attacker are genuinely
cross-origin (127.0.0.1:8000 vs 127.0.0.1:8001).  Start each in its own
background terminal so they don't share a shell.

    python3 serve.py .           8000   # host (partner page + sdk.js)
    python3 serve.py ./attacker  8001   # attacker origin
"""
import http.server
import socketserver
import sys
import os

ROOT = sys.argv[1] if len(sys.argv) > 1 else "."
PORT = int(sys.argv[2]) if len(sys.argv) > 2 else 8000


class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=ROOT, **kwargs)

    def end_headers(self):
        # keep the harness cross-origin friendly; no caching so re-runs are clean
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        # prefix logs so you can tell the two servers apart in evidence capture
        sys.stderr.write("LOG %d " % PORT + (fmt % args) + "\n")


socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("0.0.0.0", PORT), Handler) as httpd:
    sys.stderr.write("serving %s on :%d\n" % (os.path.abspath(ROOT), PORT))
    httpd.serve_forever()
