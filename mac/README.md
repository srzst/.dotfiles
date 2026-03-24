# macOS 설치 가이드

https://srz.st/Oxn

---

## 설치 명령어 확인

```bash
curl dl.srz.st/mi
```

---

## 사전 요구사항 (최초 1회)

```bash
xcode-select --install
```

---

## 스크립트 구성

동일한 베이스 스크립트에 CONFIG 값만 고정한 파일로 관리합니다.
로직 수정 시 `01_basic_bootstrap_mac.sh` 하나만 수정 후 반영합니다.

| 파일                          | TARGET   | MODE          | 용도                     |
| ----------------------------- | -------- | ------------- | ------------------------ |
| `00_recover_mac.sh`           | 0 (복구) | -             | 임시 설치 항목 원상 복구 |
| `01_basic_bootstrap_mac.sh`   | 1 (기본) | 2 (bootstrap) | 신규 Mac 전체 설치       |
| `02_minimal_bootstrap_mac.sh` | 2 (경량) | 2 (bootstrap) | 심볼릭 링크 + Homebrew   |
| `03_instant_bootstrap_mac.sh` | 3 (임시) | 2 (bootstrap) | Secrets + Git/SSH만      |

---

## 실행

```bash
# 기본
curl -sL https://raw.githubusercontent.com/srzst/.dotfiles/main/mac/install/01_basic_bootstrap_mac.sh | bash

# 경량
curl -sL https://raw.githubusercontent.com/srzst/.dotfiles/main/mac/install/02_minimal_bootstrap_mac.sh | bash

# 임시
curl -sL https://raw.githubusercontent.com/srzst/.dotfiles/main/mac/install/03_instant_bootstrap_mac.sh | bash

# 복구
curl -sL https://raw.githubusercontent.com/srzst/.dotfiles/main/mac/install/00_recover_mac.sh | bash

# install 모드 (토큰 직접 입력)
git clone https://github.com/srzst/.dotfiles ~/.dotfiles
bash ~/.dotfiles/mac/install/01_basic_bootstrap_mac.sh
```

---

## CONFIG 옵션

| 변수     | 값           | 설명                                                            |
| -------- | ------------ | --------------------------------------------------------------- |
| `TARGET` | 0: 복구      | 임시 설치 항목 원상 복구                                        |
|          | 1: 기본      | Secrets + Git/SSH + 심볼릭 링크 + Homebrew + pip + 앱 설정 복원 |
|          | 2: 경량      | Secrets + Git/SSH + 심볼릭 링크 + Homebrew + pipx               |
|          | 3: 임시      | Secrets + Git/SSH만                                             |
| `MODE`   | 1: install   | Infisical 토큰 직접 입력 (환경변수 있으면 자동 로드)            |
|          | 2: bootstrap | openssl 암호화 파일로 토큰 자동 복호화                          |

### bootstrap 토큰 파일 생성 (t.enc)

바탕화면의 `t.txt`에 Infisical 토큰 저장 후 실행:

```bash
openssl enc -aes-256-cbc -pbkdf2 -in ~/Desktop/t.txt -out ~/Desktop/t.enc -pass pass:"서버암호"
```

생성된 `t.enc` → R2 (`dl.srz.st/t.enc`) 업로드.

---

## 설치 항목

### Secrets (Infisical)

토큰 최초 입력 시 `~/.zshrc_secrets`에 저장. 이후 자동 스킵.

| 파일            | 경로                        |
| --------------- | --------------------------- |
| SSH 개인키      | `~/.ssh/id_ed25519`         |
| AWS config      | `~/.aws/config`             |
| AWS credentials | `~/.aws/credentials`        |
| Backblaze API   | `~/.backblaze/backblazeapi` |
| Git credentials | `~/.git-credentials`        |

### Keychain

| 키                       | 경로      |
| ------------------------ | --------- |
| `tailscale_authkey`      | `/`       |
| `gistup_md_manual_srzst` | `/github` |
| `token_gist_sndzin`      | `/github` |
| `token_gist_srzst`       | `/github` |

### 심볼릭 링크

| 링크 대상                                         | 원본                           |
| ------------------------------------------------- | ------------------------------ |
| `~/.zshrc`                                        | `mac/Alias/.zshrc`             |
| `~/.vimrc`                                        | `Common/Vim/.vimrc`            |
| `~/.config/nvim`                                  | `Common/neovim/`               |
| `~/.config/yazi`                                  | `Common/yazi/`                 |
| `~/.config/zed/settings.json`                     | `Common/zed/settings.json`     |
| `~/.hammerspoon`                                  | `.dotfolders/mac/.hammerspoon` |
| `~/.config/karabiner/karabiner.json`              | `.dotfolders/mac/karabiner/`   |
| `~/.config/raycast/`                              | `.dotfolders/mac/raycast/`     |
| `~/Library/Application Support/tabby/config.yaml` | `.dotfolders/mac/Tabby/`       |

### 패키지

- **Homebrew (CLI):** git, python, node, ffmpeg, yt-dlp, pngpaste, wget, terminal-notifier, pipx, rclone, neovim, lazygit, yazi, sevenzip, jq, poppler, fd, ripgrep, fzf, zoxide, imagemagick
- **Homebrew (Cask):** Google Chrome, Brave, Edge, VS Code, Cursor, Zed, GitHub Desktop, Hammerspoon, Karabiner-Elements, Obsidian, Tabby, Shottr, Mountain Duck, PopClip, Keka, Dockdoor, Raycast, HiddenBar, Alt-Tab, Hack Nerd Font
- **pip:** boto3, pillow, pync, pyobjc, requests, mistune, watchdog, pyperclip, plyer, PyQt5, b2sdk, cloudinary, pynput, pygments, dropbox, pandas, tabulate, oauth2client, gspread, google-api-python-client
- **pipx:** gita
- **npm:** electron

### 앱 설정 복원 (`.dotfolders` 기준)

- Hammerspoon — 심볼릭 링크
- Karabiner-Elements — 심볼릭 링크
- Raycast — 심볼릭 링크
- Tabby — 심볼릭 링크
- LaunchAgents — plist 복사 + launchctl 등록
- KeyBindings — `DefaultKeyBinding.dict` 복사

---

## 설치 후 작업

### macOS 시스템 설정

스크립트 자동 적용 항목:

- Finder 숨김 파일 표시
- 부팅음 끄기
- 트랙패드 탭 클릭 활성화
- Dock 자동 숨기기
- 스마트 인용 부호 끄기
- 스페이스바 마침표 끄기
- Fn 기능키 활성화
- 배터리 퍼센트 표시

### GitHub Desktop 호환

remote URL 자동으로 HTTPS로 변경됨 (`.myConfig`, `xwin`, `script`, `scriptos`).

---

## 수동 설치 항목

| 앱               | 링크                                   |
| ---------------- | -------------------------------------- |
| Jump Desktop     | https://jumpdesktop.com/download.html  |
| PhotoScape X Pro | Mac App Store                          |
| Zoho Mail        | https://zoho.com/mail/desktop-app.html |

---

## 로그

설치 과정은 터미널 출력으로 확인. 별도 로그 파일 없음.
