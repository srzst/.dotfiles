# Ubuntu 서버 부트스트랩

`bootstrap_ubuntu_sv.sh` — Ubuntu 24.04 서버 초기 세팅 자동화 스크립트.

```bash
bash bootstrap_ubuntu_sv.sh
```

서버 암호 입력 → hostname 선택 → 이후 전부 자동.

---

## 처리 항목

- hostname 설정 (W1 / W2 / W3 / W5 / shorten / multi / 직접 입력)
- 공통 패키지 설치 (`curl`, `git`, `rclone`, `python3` 등)
- Infisical CLI 설치 + 토큰 복호화 (`t.enc` → `~/.bashrc_secrets`)
- `x` 유저 생성 + sudoers 등록
- SSH 키 쌍 복원 (`main_ssh_key`, `id_ed25519`)
- AWS · Backblaze · rclone 자격증명 복원
- `.dotfiles` / `.dotfolders` clone + 심볼릭 링크 적용
- Tailscale 설치 및 인증
- root 환경 동기화
- git cron 등록 (3시간 주기 fetch+reset)

---

## 사전 조건: Infisical 시크릿 등록

> 전체 시크릿 구조 참고: `~/.dotfolders/keychain+env/_infisical_rule/README.md`

| 경로 | 키 | 용도 |
| ---- | ---- | ---- |
| `/` | `main_password` | 서버 root 비밀번호 · x 유저 비밀번호 |
| `/` | `main_ssh_private_key` | SSH 마스터 개인키 (멀티라인) |
| `/` | `main_ssh_public_key` | SSH 마스터 공개키 (멀티라인) |
| `/` | `tailscale_authkey` | Tailscale 인증 키 |
| `/github` | `github_private_ssh_os_srzst` | GitHub SSH 개인키 (`~/.ssh/id_ed25519`, 멀티라인) |
| `/github` | `git_credentials` | Git HTTPS 자격증명 (`~/.git-credentials`, 멀티라인) |
| `/rclone` | `rclone_conf` | 범용 rclone 설정 (멀티라인) |
| `/rclone` | `rclone_onedrive_sv_pve` | Proxmox용 OneDrive 설정 (멀티라인) |
| `/aws` | `config` | AWS CLI 설정 (멀티라인) |
| `/aws` | `credentials` | AWS 자격증명 (멀티라인) |
| `/backblaze` | `backblazeapi` | Backblaze B2 API 키 (멀티라인) |

### dev 모드 추가 시크릿 (`TARGET=2`)

| 경로 | 키 | 용도 |
| ---- | ---- | ---- |
| `/github` | `gistup_md_manual_srzst` | Gist 업로드 키 |
| `/github` | `token_gist_sndzin` | Gist 토큰 (sndzin) |
| `/github` | `token_gist_srzst` | Gist 토큰 (srzst) |

---

## 토큰 배포 방식

스크립트는 `https://dl.srz.st/t.enc` 에서 AES-256 암호화된 토큰을 다운로드 후  
서버 암호로 복호화하여 `~/.bashrc_secrets`에 저장 (`MODE=2` 기본값).
