# webhook_listener.py

GitHub push 이벤트를 받아 전체 서버 dotfiles/dotfolders 를 자동 sync 하는 Python 웹훅 집계 리스너.
shorten 서버 단독 운영, Tailscale SSH 로 각 서버에 sync 명령 전달 후 텔레그램 통합 리포트 발송.

---

## 기본 구조

```
GitHub push
    ↓
shorten (webhook_listener.py, port 9000)
    ↓ Tailscale SSH
W1 / W2 / W3 / W5 / pve
    ↓
텔레그램 통합 리포트 1회
```

---

## 최초 세팅 시 해야 할 것

### 1. shorten 서버에 서비스 배포

```bash
bash ~/.dotfolders/linux/ubuntusv/PremiumUrlShorten/6_webhook_setup.sh
```

### 2. Cloudflare Tunnel 에 라우팅 추가 (shorten 만)

```
Public Hostname : mywebhook.도메인
Service         : http://localhost:9000
```

### 3. GitHub 웹훅 정리

`.dotfiles`, `.dotfolders` 각각.

- 기존 W1~W5 PHP 웹훅 URL **제거**
- shorten URL 로 새로 등록

| 항목         | 값                                         |
| ------------ | ------------------------------------------ |
| Payload URL  | `https://mywebhook.도메인`                 |
| Content type | `application/json`                         |
| Secret       | infisical `/webhook/github_webhook_secret` |
| Events       | Push event 만                              |

---

## 이후 신규 서버 추가 시

`TARGET_SERVERS` 에 항목만 추가하면 됨.

```python
TARGET_SERVERS = [
    {"name": "W1",  "host": "W1"},
    ...
    {"name": "신규", "host": "신규hostname"},
]
```

GitHub 웹훅 추가 등록 불필요. shorten 이 알아서 포함해서 sync.

---

## Infisical 시크릿

| 경로        | 키                         |
| ----------- | -------------------------- |
| `/github`   | `github_webhook_secret`    |
| `/telegram` | `telegram_bot_token_srzst` |
| `/telegram` | `chat_id_srzst`            |
