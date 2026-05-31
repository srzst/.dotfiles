#!/usr/bin/env python3
import json
import subprocess
import time
import urllib.request
import urllib.parse
import socket

POLL_INTERVAL  = 60
ALERT_COOLDOWN = 300

CPU_THRESHOLD  = 0.70
MEM_THRESHOLD  = 0.90
SWAP_THRESHOLD = 0.30

INFISICAL_PROJECT = "bc893247-af3f-4118-a8ec-bcb429338acb"
INFISICAL_ENV     = "dev"


def _infisical(key: str, path: str) -> str:
    r = subprocess.run([
        "infisical", "secrets", "get", key,
        "--projectId", INFISICAL_PROJECT,
        "--env",       INFISICAL_ENV,
        "--path",      path,
        "--plain", "--silent",
    ], capture_output=True, text=True, check=False)
    return r.stdout.strip()


def load_secrets() -> dict:
    return {
        "tg_token":   _infisical("telegram_bot_token_evervz", "/telegram"),
        "tg_chat_id": _infisical("chat_id_evervz",            "/telegram"),
    }


def send_telegram(text: str, secrets: dict) -> None:
    token   = secrets.get("tg_token", "")
    chat_id = secrets.get("tg_chat_id", "")
    if not token or not chat_id:
        return
    try:
        data = urllib.parse.urlencode({"chat_id": chat_id, "text": text}).encode()
        urllib.request.urlopen(
            f"https://api.telegram.org/bot{token}/sendMessage", data, timeout=10
        )
    except Exception as e:
        print(f"[TG] 전송 실패: {e}")


SSH_KEY  = "/root/.ssh/main_ssh_key"
SSH_USER = "root"


def get_swap_ratio(host: str) -> float:
    """VM에 SSH 접속해 swap 사용률 반환. 실패 시 0.0."""
    try:
        r = subprocess.run([
            "ssh", "-i", SSH_KEY,
            "-o", "StrictHostKeyChecking=no",
            "-o", "ConnectTimeout=5",
            f"{SSH_USER}@{host}",
            "awk '/SwapTotal/{t=$2} /SwapFree/{f=$2} END{if(t>0) print (t-f)/t; else print 0}' /proc/meminfo",
        ], capture_output=True, text=True, timeout=10)
        return float(r.stdout.strip()) if r.returncode == 0 else 0.0
    except Exception:
        return 0.0


def get_vm_stats(node: str) -> list[dict]:
    stats = []
    for vm_type in ("qemu", "lxc"):
        r = subprocess.run(
            ["pvesh", "get", f"/nodes/{node}/{vm_type}", "--output-format", "json"],
            capture_output=True, text=True
        )
        if r.returncode != 0:
            continue
        try:
            vms = json.loads(r.stdout)
        except json.JSONDecodeError:
            continue
        for vm in vms:
            if vm.get("status") != "running":
                continue
            maxmem = vm.get("maxmem", 1) or 1
            name   = vm.get("name", str(vm.get("vmid")))
            stats.append({
                "vmid":       vm.get("vmid"),
                "name":       name,
                "type":       vm_type,
                "cpu":        float(vm.get("cpu", 0)),
                "mem_ratio":  vm.get("mem", 0) / maxmem,
                "swap_ratio": get_swap_ratio(name),
            })
    return stats


def main() -> None:
    print("[pve-monitor] 시작")
    node    = socket.gethostname()
    secrets = load_secrets()
    if not secrets.get("tg_token"):
        print("[pve-monitor] WARN: Telegram 시크릿 로드 실패")

    last_alert: dict[str, float] = {}

    while True:
        try:
            now = time.time()
            for vm in get_vm_stats(node):
                vmid = str(vm["vmid"])
                name = vm["name"]
                cpu  = vm["cpu"]
                mem  = vm["mem_ratio"]

                swap = vm["swap_ratio"]

                alerts = []
                if cpu >= CPU_THRESHOLD:
                    alerts.append(f"CPU {cpu * 100:.1f}% (임계: {CPU_THRESHOLD * 100:.0f}%)")
                if mem >= MEM_THRESHOLD:
                    alerts.append(f"메모리 {mem * 100:.1f}% (임계: {MEM_THRESHOLD * 100:.0f}%)")
                if swap >= SWAP_THRESHOLD:
                    alerts.append(f"Swap {swap * 100:.1f}% (임계: {SWAP_THRESHOLD * 100:.0f}%)")

                if not alerts:
                    last_alert.pop(vmid, None)
                    continue

                if now - last_alert.get(vmid, 0) < ALERT_COOLDOWN:
                    continue

                last_alert[vmid] = now
                text = (
                    f"[PVE 알림] {node} / {name} (VMID {vmid})\n"
                    + "\n".join(alerts)
                )
                print(f"[pve-monitor] 알림 발송: {text}")
                send_telegram(text, secrets)

        except Exception as e:
            print(f"[pve-monitor] 오류: {e}")

        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    main()
