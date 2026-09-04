<!-- Linux\Ubuntu\README.md -->

# Ubuntu 기본 설치 가이드

https://srz.st/qiP

### 설치 명령어 확인

- **Ubuntu / macOS**:

  ```bash
  curl dl.srz.st/ui
  ```

- **Windows (PowerShell)**:

  ```powershell
  irm dl.srz.st/ui
  ```

---

## 스크립트 구성

동일한 베이스 스크립트에 CONFIG 값만 고정한 파일 3개로 관리합니다.
로직 수정 시 `install_ubuntu.sh` 하나만 수정 후 나머지 두 파일에 반영합니다.

| 파일                     | MODE          | MIRROR     | TARGET     | 용도                        |
| ------------------------ | ------------- | ---------- | ---------- | --------------------------- |
| `bootstrap_ubuntu_sv.sh` | 2 (bootstrap) | 1 (기본)   | 1 (server) | 신규 서버, 토큰 자동 복호화 |
| `install_ubuntu_sv.sh`   | 1 (install)   | 2 (카카오) | 1 (server) | 기존 서버, 토큰 직접 입력   |
| `install_ubuntu.sh`      | 1 (install)   | 2 (카카오) | 2 (dev)    | 개발 환경                   |

---

## 실행

**bootstrap (신규 서버):**

```bash
curl -s https://raw.githubusercontent.com/srzst/.dotfiles/main/linux/ubuntu/install/bootstrap_ubuntu_sv.sh | bash
```

**install:**

```bash
git clone https://github.com/srzst/.dotfiles.git ~/.dotfiles
bash ~/.dotfiles/linux/ubuntu/install/install_ubuntu_sv.sh
# 또는
bash ~/.dotfiles/linux/ubuntu/install/install_ubuntu.sh
```

---

## CONFIG 옵션

| 변수     | 값           | 설명                                                            |
| -------- | ------------ | --------------------------------------------------------------- |
| `MODE`   | 1: install   | Infisical 토큰 직접 입력 (`~/.bashrc_secrets` 있으면 자동 로드) |
|          | 2: bootstrap | openssl 암호화 파일로 토큰 자동 복호화                          |
| `MIRROR` | 1: 기본      | archive.ubuntu.com                                              |
|          | 2: 카카오    | mirror.kakao.com                                                |
| `TARGET` | 1: server    | 경량 설치                                                       |
|          | 2: dev       | 개발 도구 포함                                                  |

---

## bootstrap 토큰 파일 생성 (t.enc)

바탕화면의 `t.txt`에 Infisical 토큰 저장 후 실행:

```powershell
openssl enc -aes-256-cbc -pbkdf2 -in "$HOME\Desktop\t.txt" -out "$HOME\Desktop\t.enc" -pass pass:"서버암호"
```

생성된 `t.enc` → R2 (`dl.srz.st/t.enc`) 업로드.

---

## server 설치 항목

- 시스템 업데이트
- 기본 패키지: curl, wget, vim, git, htop, python3, pipx, rclone, tmux 외
- Infisical CLI
- Tailscale
- pipx / gita

## dev 추가 설치 항목

- PowerShell 7+
- Neovim (latest), lazygit
- Yazi + 의존성 (ffmpeg, jq, poppler, fd, ripgrep, fzf, zoxide, imagemagick)
- pip 패키지: boto3, pillow, gspread, pandas 외

---

## Secrets 복원

| 파일            | 경로                           |
| --------------- | ------------------------------ |
| SSH 개인키      | `~/.ssh/id_ed25519`            |
| AWS config      | `~/.aws/config`                |
| AWS credentials | `~/.aws/credentials`           |
| Backblaze API   | `~/.backblaze/backblazeapi`    |
| Git credentials | `~/.git-credentials`           |
| rclone config   | `~/.config/rclone/rclone.conf` |

---

## 심볼릭 링크

### server / dev 공통

| 링크 대상   | 원본                         |
| ----------- | ---------------------------- |
| `~/.bashrc` | `linux/ubuntu/Alias/.bashrc` |
| `~/.vimrc`  | `common/Vim/.vimrc`          |

### dev 추가

| 링크 대상        | 원본            |
| ---------------- | --------------- |
| `~/.config/nvim` | `common/neovim` |
| `~/.config/yazi` | `common/yazi`   |

---

## root 환경 동기화

### server / dev 공통

- `/root/.bashrc` → `linux/ubuntu/Alias/.bashrc`
- `/root/.vimrc` → `common/Vim/.vimrc`

### dev 추가

- `/root/.config/nvim` → `common/neovim`
- `/root/.config/yazi` → `common/yazi`

---

## 공통

- Infisical 토큰: `install` 모드 최초 입력 시 `~/.bashrc_secrets` 저장, 이후 스킵
- Cron: 3시간마다 `.dotfiles` / `.dotfolders` pull 자동 등록
- 시간대: `Asia/Seoul` 자동 설정
- Tailscale Auth Key 만료 시 Infisical에서 `tailscale_authkey` 갱신 후 재실행
