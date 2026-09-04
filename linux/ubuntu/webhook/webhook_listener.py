#!/usr/bin/env python3
"""
GitHub Webhook Aggregator (shorten 전용)
GitHub push → 전체 서버 SSH sync → 텔레그램 통합 리포트
"""
import hashlib
import hmac
import json
import subprocess
import urllib.request
import urllib.parse
from concurrent.futures import ThreadPoolExecutor, as_completed
from http.server import BaseHTTPRequestHandler, HTTPServer

# ============================================================
# CONFIG
# ============================================================
PORT = 9000

TARGET_SERVERS = [
    {"name": "shorten", "host": "shorten"},
    {"name": "W1",      "host": "W1"},
    {"name": "W2",      "host": "W2"},
    {"name": "W3",      "host": "W3"},
    {"name": "W5",      "host": "W5"},
    {"name": "pve",     "host": "pve"},
]

REPOS    = ["/home/x/.dotfiles", "/home/x/.dotfolders"]
SSH_KEY  = "/home/x/.ssh/main_ssh_key"
SSH_USER = "x"

# 빈 리스트 = 모든 push에 sync. 특정 경로만 트리거하려면 경로 추가.
# 예: WATCH_PATHS = ["linux/ubuntu/", "linux/ubuntusv/", "common/"]
WATCH_PATHS: list[str] = []

INFISICAL_PROJECT = "bc893247-af3f-4118-a8ec-bcb429338acb"
INFISICAL_ENV     = "dev"
# ============================================================


def _infisical(key: str, path: str) -> str:
    r = subprocess.run([
        "infisical", "secrets", "get", key,
        "--projectId", INFISICAL_PROJECT,
        "--env", INFISICAL_ENV,
        "--path", path,
        "--plain", "--silent",
    ], capture_output=True, text=True, check=False)
    return r.stdout.strip()


def load_secrets() -> dict:
    return {
        "webhook_secret": _infisical("github_webhook_secret", "/github"),
        "tg_token":       _infisical("telegram_bot_token_srzst", "/telegram"),
        "tg_chat_id":     _infisical("chat_id_srzst", "/telegram"),
    }


SECRETS: dict = {}


def send_telegram(text: str):
    token   = SECRETS.get("tg_token", "")
    chat_id = SECRETS.get("tg_chat_id", "")
    if not token or not chat_id:
        return
    try:
        data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
        urllib.request.urlopen(
            f"https://api.telegram.org/bot{token}/sendMessage", data, timeout=10
        )
    except Exception as e:
        print(f"[TG] 실패: {e}")


def sync_server(server: dict) -> tuple[str, bool, str]:
    name = server["name"]
    host = server["host"]
    cmd  = " && ".join(
        f"cd {repo} && git fetch origin && git reset --hard origin/main"
        for repo in REPOS
    )
    try:
        r = subprocess.run([
            "ssh", "-i", SSH_KEY,
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=10",
            f"{SSH_USER}@{host}", cmd,
        ], capture_output=True, text=True, timeout=30)
        ok = r.returncode == 0
        return name, ok, r.stderr.strip() if not ok else "OK"
    except Exception as e:
        return name, False, str(e)


class WebhookHandler(BaseHTTPRequestHandler):

    def do_POST(self):
        length  = int(self.headers.get("Content-Length", 0))
        payload = self.rfile.read(length)

        sig      = self.headers.get("X-Hub-Signature-256", "")
        secret   = SECRETS.get("webhook_secret", "").encode()
        expected = "sha256=" + hmac.new(secret, payload, hashlib.sha256).hexdigest()

        if not hmac.compare_digest(sig, expected):
            self.send_response(403)
            self.end_headers()
            self.wfile.write(b"Forbidden")
            return

        data     = json.loads(payload)
        modified = []
        for commit in data.get("commits", []):
            modified += commit.get("added", []) + commit.get("modified", []) + commit.get("removed", [])

        if WATCH_PATHS and not any(f.startswith(p) for f in modified for p in WATCH_PATHS):
            self.send_response(200)
            self.end_headers()
            self.wfile.write(b"OK")
            return

        commit_msg = data.get("head_commit", {}).get("message", "-")
        files_str  = "\n  ".join(modified[:5]) + ("\n  ..." if len(modified) > 5 else "")

        results = []
        with ThreadPoolExecutor(max_workers=len(TARGET_SERVERS)) as pool:
            futures = {pool.submit(sync_server, s): s for s in TARGET_SERVERS}
            for future in as_completed(futures):
                results.append(future.result())

        results.sort(key=lambda x: x[0])
        lines     = [
            f"{'✓' if ok else '✗'} {name}" + (f" - {msg}" if not ok else "")
            for name, ok, msg in results
        ]
        lines_str = "\n".join(lines)
        msg = (
            f"[dotfiles] 배포\n"
            f"{lines_str}\n"
            f"커밋: {commit_msg}\n"
            f"파일:\n  {files_str}"
        )
        send_telegram(msg)

        self.send_response(200)
        self.end_headers()
        self.wfile.write(b"OK")

    def log_message(self, format, *args):
        pass


if __name__ == "__main__":
    SECRETS.update(load_secrets())
    server = HTTPServer(("0.0.0.0", PORT), WebhookHandler)
    print(f"[webhook] 포트 {PORT} 대기 중")
    server.serve_forever()
