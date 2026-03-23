# Ubuntu 설치 가이드

https://srz.st/qiP

---

## 서버 (install_ubuntu_sv.sh)

경량 서버 전용. GUI/개발 도구 미포함.

```bash
bash ~/.dotfiles/linux/ubuntu/install/install_ubuntu_sv.sh
```

### 설치 항목

- 시스템 업데이트
- 기본 패키지: curl, wget, vim, git, htop, python3, pipx, rclone, tmux 외
- Infisical CLI
- Tailscale
- pipx / gita

### Secrets 복원

| 파일            | 경로                           |
| --------------- | ------------------------------ |
| SSH 개인키      | `~/.ssh/id_ed25519`            |
| AWS config      | `~/.aws/config`                |
| AWS credentials | `~/.aws/credentials`           |
| Backblaze API   | `~/.backblaze/backblazeapi`    |
| Git credentials | `~/.git-credentials`           |
| rclone config   | `~/.config/rclone/rclone.conf` |

### 심볼릭 링크

| 링크 대상   | 원본                         |
| ----------- | ---------------------------- |
| `~/.bashrc` | `linux/ubuntu/Alias/.bashrc` |
| `~/.vimrc`  | `Common/Vim/.vimrc`          |

### root 환경 동기화

- `/root/.bashrc` → `linux/ubuntu/Alias/.bashrc`
- `/root/.vimrc` → `Common/Vim/.vimrc`

---

## 데스크탑/개발 (install_ubuntu.sh)

서버 항목 전체 포함 + 개발 도구 추가.

```bash
bash ~/.dotfiles/linux/ubuntu/install/install_ubuntu.sh
```

### 추가 설치 항목

- PowerShell 7+
- Neovim (latest), lazygit
- Yazi + 의존성 (ffmpeg, jq, poppler, fd, ripgrep, fzf, zoxide, imagemagick)
- pip 패키지: boto3, pillow, gspread, pandas 외
- 미러 서버 선택 (기본 / 카카오)

### 추가 심볼릭 링크

| 링크 대상        | 원본            |
| ---------------- | --------------- |
| `~/.config/nvim` | `Common/neovim` |
| `~/.config/yazi` | `Common/yazi`   |

### root 환경 동기화 (추가)

- `/root/.config/nvim` → `Common/neovim`
- `/root/.config/yazi` → `Common/yazi`

---

## 공통

- Infisical 토큰: 최초 입력 시 `~/.bashrc_secrets` 저장, 이후 스킵
- Cron: 3시간마다 `.dotfiles` / `.dotfolders` pull 자동 등록
- 시간대: `Asia/Seoul` 자동 설정
- Tailscale Auth Key 만료 시 Infisical에서 `tailscale_authkey` 갱신 후 재실행
