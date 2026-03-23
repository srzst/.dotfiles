# Windows 설치 가이드

## 사전 요구사항

Git 미설치 시:

```powershell
winget install -e --id Git.Git --source winget
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" + $env:PATH
```

실행 정책 설정 (최초 1회):

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## 설치

**관리자 권한 PowerShell**에서 실행:

```powershell
git clone https://github.com/srzst/.dotfiles $HOME\.dotfiles
& "$HOME\.dotfiles\Windows\install\install_windows.ps1"
```

---

## 설치 항목

### Secrets (Infisical)

토큰 최초 입력 시 사용자 환경변수 `INFISICAL_TOKEN`에 저장. 이후 자동 스킵.

복원 파일:

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
| `$PROFILE`                            | `Windows\Alias\PowerShell\profile.ps1` |
| `~/AppData/Local/nvim`                | `Common\neovim\`                       |
| `~/AppData/Roaming/yazi/config`       | `Common\yazi\`                         |
| `~/AppData/Roaming/Zed/settings.json` | `Common\zed\settings.json`             |

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
ln -sf "$REPO/Windows/Alias/GitBash/.bashrc" ~/.bashrc
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
