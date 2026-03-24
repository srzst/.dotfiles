<!-- Windows\README.md -->

# Windows 설치 가이드

https://srz.st/wRi

---

## 설치 명령어 확인

```powershell
irm dl.srz.st/wi
```

---

## 사전 요구사항 (최초 1회)

```powershell
winget install -e --id Git.Git --source winget; $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + $env:PATH; Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 스크립트 구성

동일한 베이스 스크립트에 CONFIG 값만 고정한 파일로 관리합니다.
로직 수정 시 `install_windows.ps1` 하나만 수정 후 반영합니다.

| 파일                               | TARGET   | MODE          | 용도                     |
| ---------------------------------- | -------- | ------------- | ------------------------ |
| `00_recover_windows.ps1`           | 0 (복구) | -             | 임시 설치 항목 원상 복구 |
| `01_basic_bootstrap_windows.ps1`   | 1 (기본) | 2 (bootstrap) | 신규 PC 전체 설치        |
| `02_minimal_bootstrap_windows.ps1` | 2 (경량) | 2 (bootstrap) | 심볼릭 링크 + Scoop      |
| `03_instant_bootstrap_windows.ps1` | 3 (임시) | 2 (bootstrap) | Secrets + Git/SSH만      |

---

## 실행

```powershell
# 기본
irm https://raw.githubusercontent.com/srzst/.dotfiles/main/windows/install/01_basic_bootstrap_windows.ps1 | iex

# 경량
irm https://raw.githubusercontent.com/srzst/.dotfiles/main/windows/install/02_minimal_bootstrap_windows.ps1 | iex

# 임시
irm https://raw.githubusercontent.com/srzst/.dotfiles/main/windows/install/03_instant_bootstrap_windows.ps1 | iex

# 복구
irm https://raw.githubusercontent.com/srzst/.dotfiles/main/windows/install/00_recover_windows.ps1 | iex

# install 모드 (토큰 직접 입력)
git clone https://github.com/srzst/.dotfiles $HOME\.dotfiles
& "$HOME\.dotfiles\windows\install\install_windows.ps1"
```

---

## CONFIG 옵션

| 변수      | 값           | 설명                                                                     |
| --------- | ------------ | ------------------------------------------------------------------------ |
| `$TARGET` | 0: 복구      | 임시 설치 항목 원상 복구                                                 |
|           | 1: 기본      | Secrets + Git/SSH + 심볼릭 링크 + Scoop + winget 앱 + pip + 앱 설정 복원 |
|           | 2: 경량      | Secrets + Git/SSH + 심볼릭 링크 + Scoop + pipx                           |
|           | 3: 임시      | Secrets + Git/SSH만                                                      |
| `$MODE`   | 1: install   | Infisical 토큰 직접 입력 (환경변수 있으면 자동 로드)                     |
|           | 2: bootstrap | openssl 암호화 파일로 토큰 자동 복호화                                   |

### bootstrap 토큰 파일 생성 (t.enc)

바탕화면의 `t.txt`에 Infisical 토큰 저장 후 실행:

```powershell
openssl enc -aes-256-cbc -pbkdf2 -in "$HOME\Desktop\t.txt" -out "$HOME\Desktop\t.enc" -pass pass:"서버암호"
```

생성된 `t.enc` → R2 (`dl.srz.st/t.enc`) 업로드.

---

## 설치 항목

### Secrets (Infisical)

토큰 최초 입력 시 사용자 환경변수 `INFISICAL_TOKEN`에 저장. 이후 자동 스킵.

| 파일            | 경로                           |
| --------------- | ------------------------------ |
| SSH 개인키      | `~\.ssh\id_ed25519`            |
| AWS config      | `~\.aws\config`                |
| AWS credentials | `~\.aws\credentials`           |
| Backblaze API   | `~\.backblaze\backblazeapi`    |
| Git credentials | `~\.git-credentials`           |
| rclone config   | `~\.config\rclone\rclone.conf` |

### 심볼릭 링크

| 링크 대상                             | 원본                                   |
| ------------------------------------- | -------------------------------------- |
| `$PROFILE`                            | `windows\Alias\PowerShell\profile.ps1` |
| `~/AppData/Local/nvim`                | `common\neovim\`                       |
| `~/AppData/Roaming/yazi/config`       | `common\yazi\`                         |
| `~/AppData/Roaming/Zed/settings.json` | `common\zed\settings.json`             |

### 패키지

- **Scoop:** gsudo, vim, curl, rclone, Hack-NF, autohotkey1.1, python, nodejs, neovim, neovide, lazygit, yazi, fzf, zoxide, ripgrep, fd, jq, 7zip, ffmpeg, imagemagick, tabby, pipx 외
- **Winget:** VS Code, Cursor, Brave, Bitwarden, GitHub Desktop, PowerToys, Obsidian, Typora, Mountain Duck, Figma, LocalSend, Zed, Bandizip, CopyQ, KakaoTalk 외
- **pip:** pyperclip, requests, boto3, pillow, pywin32, pandas, gspread 외
- **pipx:** gita

### 앱 설정 복원 (`.dotfolders` 기준)

- WinSnap — 설치 + 레지스트리 복원
- FastStone Capture — 설치 + 설정 심볼릭 링크
- Mountain Duck — 라이선스 + 북마크 복원
- Windows Terminal — 설정 심볼릭 링크
- Tabby — 설정 심볼릭 링크
- Snipdo — 설정 복사
- Raycast — 설치 후 수동 복원 필요 (하단 참고)

---

## 설치 후 작업

### GitBash `.bashrc` 연결

GitBash에서 실행:

```bash
REPO="/c/Users/$USERNAME/.dotfiles"
rm ~/.bashrc
ln -sf "$REPO/windows/Alias/GitBash/.bashrc" ~/.bashrc
```

### Raycast 설정 복원

Raycast 최초 실행 및 튜토리얼 완료 후:

```powershell
Stop-Process -Name 'Raycast' -Force -ErrorAction SilentlyContinue
Copy-Item "$HOME\.dotfolders\windows\Raycast\settings.db" "$env:LOCALAPPDATA\Raycast\" -Force
Copy-Item "$HOME\.dotfolders\windows\Raycast\settings_v2.db" "$env:LOCALAPPDATA\Raycast\" -Force
```

---

## 수동 설치 항목

| 앱                | 링크                                   |
| ----------------- | -------------------------------------- |
| Jump Desktop      | https://jumpdesktop.com/download.html  |
| PhotoScape X Pro  | Microsoft Store                        |
| Zoho Mail Desktop | https://zoho.com/mail/desktop-app.html |

---

## 로그

설치 완료 후 `~\install_windows_YYYYMMDD_HHmmss.log` 확인.
