#!/usr/bin/env python3
"""One-shot Linear agent-app OAuth token minter.

Starts a local listener on :8080, opens the authorize URL (actor=app), catches
the redirect, exchanges the code for an app access token, and prints it.

Register redirect URI  http://localhost:8080/callback  in the Linear OAuth app.
Run:  LINEAR_CLIENT_ID=... LINEAR_CLIENT_SECRET=... python3 mint-token.py
(or just run it and paste the id/secret when prompted).
"""
import http.server
import json
import os
import secrets
import sys
import urllib.parse
import urllib.request
import webbrowser

CLIENT_ID = os.environ.get("LINEAR_CLIENT_ID") or input("Client ID: ").strip()
CLIENT_SECRET = os.environ.get("LINEAR_CLIENT_SECRET") or input("Client secret: ").strip()

PORT = 8080
REDIRECT = f"http://localhost:{PORT}/callback"
SCOPE = "read,write,app:assignable,app:mentionable"
STATE = secrets.token_urlsafe(16)

authorize = "https://linear.app/oauth/authorize?" + urllib.parse.urlencode(
    {
        "client_id": CLIENT_ID,
        "redirect_uri": REDIRECT,
        "response_type": "code",
        "scope": SCOPE,
        "actor": "app",
        "state": STATE,
    }
)

result = {}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):  # noqa: N802
        parsed = urllib.parse.urlparse(self.path)
        if parsed.path != "/callback":
            self.send_error(404)
            return
        params = urllib.parse.parse_qs(parsed.query)
        result["code"] = params.get("code", [None])[0]
        result["state"] = params.get("state", [None])[0]
        result["error"] = params.get("error", [None])[0]
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.end_headers()
        self.wfile.write(b"Got it. You can close this tab and return to the terminal.\n")

    def log_message(self, *_):
        pass


srv = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
print("\nOpen this URL to authorize (a browser tab should open automatically):\n")
print(authorize + "\n")
try:
    webbrowser.open(authorize)
except Exception:
    pass

# Serve requests until the callback delivers a code (ignores favicon etc.).
while "code" not in result and "error" not in result:
    srv.handle_request()

if result.get("error"):
    print(f"authorize failed: {result['error']}", file=sys.stderr)
    sys.exit(1)
if result.get("state") != STATE:
    print("state mismatch — possible CSRF, aborting", file=sys.stderr)
    sys.exit(1)
if not result.get("code"):
    print("no code received", file=sys.stderr)
    sys.exit(1)

data = urllib.parse.urlencode(
    {
        "grant_type": "authorization_code",
        "code": result["code"],
        "redirect_uri": REDIRECT,
        "client_id": CLIENT_ID,
        "client_secret": CLIENT_SECRET,
    }
).encode()
req = urllib.request.Request(
    "https://api.linear.app/oauth/token",
    data=data,
    headers={"Content-Type": "application/x-www-form-urlencoded"},
)
try:
    with urllib.request.urlopen(req) as resp:
        tok = json.load(resp)
except urllib.error.HTTPError as e:
    print(f"token exchange failed: {e.code}\n{e.read().decode()}", file=sys.stderr)
    sys.exit(1)

print("\n=== app access token (this is linear/app_token) ===\n")
print(tok.get("access_token", "<missing>"))
print("\nfull response:")
print(json.dumps(tok, indent=2))
