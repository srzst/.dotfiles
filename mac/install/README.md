# macOS 부트스트랩

`01_basic_bootstrap_mac.sh` — macOS 초기 세팅 자동화 스크립트.

```bash
bash 01_basic_bootstrap_mac.sh
```

설치 유형 선택 (1~4) → 복호화 암호 입력 → 이후 전부 자동.

---

## 설치 유형

| 선택 | 설명 |
| ---- | ---- |
| 1) 기본 | 전체 앱/패키지 설치 + 설정 완전 적용 |
| 2) 경량 | 핵심 패키지만 설치 (GUI 앱 제외) |
| 3) 임시 | 시크릿/토큰 설정만 (패키지 설치 없음) |
| 4) 복구 | SSH 키 · 자격증명 · 환경변수 초기화 |

---

## 처리 항목

- Homebrew 설치 → Infisical CLI 설치
- 토큰 복호화 (`t.enc` → `~/.zshrc_secrets`)
- SSH 키 쌍 복원 (`main_ssh_key`, `id_ed25519`)
- AWS · Backblaze · rclone · git 자격증명 복원
- Keychain 시크릿 주입 (`tailscale_authkey`, gist 토큰 등)
- `.dotfiles` / `.dotfolders` clone + 심볼릭 링크 적용
- Homebrew 패키지 / Cask / pip 설치
- macOS 시스템 설정 (Finder, Dock, 트랙패드 등)
- LaunchAgents 등록

---

## 사전 조건: Infisical 시크릿 등록

> 전체 시크릿 구조 참고: `~/.dotfolders/keychain+env/_infisical_rule/README.md`

| 경로 | 키 | 용도 |
| ---- | ---- | ---- |
| `/` | `main_ssh_private_key` | SSH 마스터 개인키 (멀티라인) |
| `/` | `main_ssh_public_key` | SSH 마스터 공개키 (멀티라인) |
| `/` | `tailscale_authkey` | Tailscale 인증 키 (Keychain 저장) |
| `/github` | `github_private_ssh_os_srzst` | GitHub SSH 개인키 (`~/.ssh/id_ed25519`, 멀티라인) |
| `/github` | `git_credentials` | Git HTTPS 자격증명 (`~/.git-credentials`, 멀티라인) |
| `/github` | `gistup_md_manual_srzst` | Gist 업로드 키 (Keychain 저장) |
| `/github` | `token_gist_sndzin` | Gist 토큰 sndzin (Keychain 저장) |
| `/github` | `token_gist_srzst` | Gist 토큰 srzst (Keychain 저장) |
| `/aws` | `config` | AWS CLI 설정 (멀티라인) |
| `/aws` | `credentials` | AWS 자격증명 (멀티라인) |
| `/backblaze` | `backblazeapi` | Backblaze B2 API 키 (멀티라인) |

---

## 토큰 배포 방식

스크립트는 `https://dl.srz.st/t.enc` 에서 AES-256 암호화된 토큰을 다운로드 후  
복호화 암호 입력으로 복호화하여 `~/.zshrc_secrets`에 저장 (`MODE=2` 기본값).

macOS에서는 `INFISICAL_TOKEN`을 Keychain에 저장하지 않고 `~/.zshrc_secrets`로 관리.  
Python 스크립트에서 Keychain 접근이 필요한 경우 `_infisical_rule/README.md`의 Python 함수 참고.
