#!/usr/bin/env python3
"""Mock /forgot_password server to validate scripts/reset_probe.sh locally.

Planted flaws (a correct probe must report ALL of these):
  1. User enumeration  -> known email returns 84 bytes, unknown returns 67 (timing gap too)
  2. Token leak in response -> known email's JSON body contains resetPasswordLink?token=...
  3. Host-header poisoning  -> reset link host follows X-Forwarded-Host / Host
  4. No rate limiting       -> 5 rapid requests, never a 429

Run:  python3 mock_reset_server.py          # listens on 127.0.0.1:8899
Then: BASE=http://127.0.0.1:8899 EMAIL=me@x.tld KNOWN=real@target.tld \
        ./scripts/reset_probe.sh
If the probe reports nothing against this mock, the probe is broken.
"""
from http.server import BaseHTTPRequestHandler, HTTPServer
import urllib.parse, time

KNOWN = "real@target.tld"


class H(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def do_GET(self):
        if self.path in ("/forgot_password", "/reset"):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"<html>reset form</html>")
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        if self.path != "/forgot_password":
            self.send_response(404)
            self.end_headers()
            return
        n = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(n).decode(errors="replace")
        q = urllib.parse.parse_qs(body)
        email = (q.get("email") or [""])[0]
        # flaw 3: reflect attacker-controlled host into the reset link
        host = self.headers.get("X-Forwarded-Host") or self.headers.get("Host", "")
        if email == KNOWN:
            # flaw 1 + 2: known email -> longer body that leaks the token
            resp = f'{{"status":"ok","resetPasswordLink":"http://{host}/reset?token=ABC123SECRET"}}'.encode()
            self.send_response(200)
        else:
            time.sleep(0.3)  # flaw 1: timing side-channel
            resp = b'{"status":"ok","msg":"If the account exists you will get an email"}'
            self.send_response(200)
        # flaw 4: no rate limiting anywhere
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(resp)))
        self.end_headers()
        self.wfile.write(resp)


if __name__ == "__main__":
    HTTPServer(("127.0.0.1", 8899), H).serve_forever()
