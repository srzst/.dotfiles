# .dotfiles

개인 개발 환경 설정 파일 모음.

> ⚠️ **개인화된 설정 파일임.** BWS(Bitwarden Secrets Manager) 액세스 토큰 없이는 secrets 복원이 불가하며, 스크립트가 정상 동작하지 않음.

## 구조

```
.dotfiles/
├── Alias/
│   ├── macOS/
│   │   └── .zshrc
│   ├── ubuntu/
│   │   └── .bashrc
│   └── Windows/
│       ├── GitBash/
│       │   └── .bashrc
│       └── PowerShell/
│           └── profile.ps1
├── neovim/
│   ├── lua/
│   │   ├── config/
│   │   └── plugins/
│   ├── .gitignore
│   ├── .neoconf.json
│   ├── init.lua
│   ├── lazy-lock.json
│   ├── lazyvim.json
│   ├── LICENSE
│   ├── README.md
│   └── stylua.toml
├── Vim/
│   └── .vim.rc
├── vscode/
│   └── keybindings.json
├── yazi/
│   ├── keymap.toml
│   └── yazi.toml
├── zed/
│   └── settings.json
├── _install/
│   ├── bak/
│   ├── mac/
│   │   ├── KeyBindings/
│   │   │   └── DefaultKeyBinding.dict
│   │   └── LaunchAgents/
│   │       ├── com.user.clip_history.plist
│   │       ├── com.user.url_changer.plist
│   │       ├── launch_agents_reload.sh
│   │       └── readmore.md
│   ├── install_mac.sh
│   ├── install_ubuntu.sh
│   ├── install_ubuntu_sv.sh
│   └── install_windows.ps1
├── .gitattributes
└── readme.md
```

## 에디터 구성

| 명령 | 도구           | 용도                             |
| ---- | -------------- | -------------------------------- |
| `v`  | nvim (LazyVim) | 메인 에디터                      |
| `vi` | vim            | 보조 에디터 (같은 머신에서 병행) |

---

## 설치 방법

### 사전 요구사항

Hack Nerd Font 설치 필요 (Ubuntu 서버라면 불필요)

| 환경    | 설치 방법                                                                                                                                                                             |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Windows | [Hack.zip](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/Hack.zip) / [FiraCode.zip](https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/FiraCode.zip) |
| macOS   | `brew install --cask font-hack-nerd-font`                                                                                                                                             |
| Ubuntu  | `sudo apt install fonts-hack`                                                                                                                                                         |

### 0. bws CLI

bws CLI는 설치 스크립트가 자동 설치함. 버전 변경 시 각 스크립트 상단의 `BWS_VERSION` 변수만 수정.

| 환경    | 설치 경로           |
| ------- | ------------------- |
| macOS   | `~/bws/bws`         |
| Ubuntu  | `~/bws/bws`         |
| Windows | `$HOME\bws\bws.exe` |

> 최신 버전 확인: https://github.com/bitwarden/sdk-sm/releases

### 1. Clone

```bash
git clone https://github.com/srzst/.dotfiles ~/.dotfiles
```

### 2. 설치 스크립트 실행

각 OS별 스크립트를 직접 실행. 실행 후 **BWS 액세스 토큰 입력** → 설치 진행.

**macOS:**

```bash
bash ~/.dotfiles/_install/install_mac.sh
```

**Ubuntu (24.04 기준):**

```bash
bash ~/.dotfiles/_install/install_ubuntu.sh
```

**Ubuntu 서버 경량 버전:**

```bash
bash ~/.dotfiles/_install/install_ubuntu_sv.sh
```

> 서버 버전은 Neovim/LazyVim, Yazi, lazygit, pip 패키지 제외. 기본 미러 사용.

**Windows (관리자 권한 PowerShell):**

```powershell
& "$HOME\.dotfiles\_install\install_windows.ps1"
```

Windows는 실행 후 머신 타입 선택:

```
머신 타입을 선택하세요:
  1) main  - 데스크탑 / 노트북
  2) vm    - 가상머신
```

> macOS: Homebrew, Neovim/LazyVim, lazygit, Yazi, LaunchAgents, macOS 시스템 설정 포함  
> Ubuntu: 미러 서버 변경, 시스템 업데이트, Neovim/LazyVim, lazygit, Yazi, Tailscale 포함  
> Ubuntu 서버: 시스템 업데이트, 기본 패키지, BWS/secrets, Tailscale 포함 (경량)  
> Windows: Scoop / Chocolatey 패키지, Neovim/LazyVim, xwin 스케줄 작업 등록 포함

**GitBash 추가 작업** (Windows 설치 완료 후 GitBash에서 실행):

```bash
REPO="/c/Users/$USERNAME/.dotfiles"
rm ~/.bashrc
ln -sf "$REPO/Alias/Windows/GitBash/.bashrc" ~/.bashrc
```

### 3. BWS 액세스 토큰

스크립트 실행 직후 BWS 액세스 토큰 입력 요청. 토큰은 Bitwarden Secrets Manager 콘솔에서 확인/발급.

토큰은 로컬 전용으로 저장되며 git에는 포함되지 않음:

| 환경    | 저장 방식                            |
| ------- | ------------------------------------ |
| macOS   | `~/.zshrc_secrets` 파일              |
| Ubuntu  | `~/.bashrc_secrets` 파일             |
| Windows | 사용자 환경변수 (`BWS_ACCESS_TOKEN`) |

> 이미 존재하면 스킵. 글로벌 gitignore(`~/.gitignore_global`)에도 자동 등록.

### 4. secrets 복원 (BWS)

토큰 설정 후 스크립트가 자동으로 아래 파일들을 Bitwarden에서 가져와 생성:

| 파일                        | 설명                              |
| --------------------------- | --------------------------------- |
| `~/.aws/config`             | AWS CLI 설정                      |
| `~/.aws/credentials`        | AWS 액세스 키                     |
| `~/.backblaze/backblazeapi` | Backblaze API 토큰                |
| `~/.git-credentials`        | Git 인증 정보                     |
| `~/.ssh/id_ed25519`         | SSH 개인키                        |
| Tailscale Auth Key          | Tailscale 자동 인증 (Ubuntu 전용) |

> Tailscale Auth Key 만료 시: Tailscale Admin Console → Auth Key 재발급 → BWS `tailscale_authkey` 값 업데이트

---

## 심볼릭 링크 경로

| 환경                | 원본 경로                                                        | 링크 대상                              |
| ------------------- | ---------------------------------------------------------------- | -------------------------------------- |
| macOS               | `~/.zshrc`                                                       | `Alias/macOS/.zshrc`                   |
| macOS VSCode        | `~/Library/Application Support/Code/User/keybindings.json`       | `vscode/keybindings.json`              |
| macOS Cursor        | `~/Library/Application Support/Cursor/User/keybindings.json`     | `vscode/keybindings.json`              |
| macOS Zed           | `~/.config/zed/settings.json`                                    | `zed/settings.json`                    |
| Ubuntu              | `~/.bashrc`                                                      | `Alias/ubuntu/.bashrc`                 |
| Neovim (Mac/Ubuntu) | `~/.config/nvim`                                                 | `neovim/`                              |
| Yazi (Mac/Ubuntu)   | `~/.config/yazi`                                                 | `yazi/`                                |
| Vim (Mac/Ubuntu)    | `~/.vimrc`                                                       | `Vim/.vim.rc`                          |
| Windows PowerShell  | `~/Documents/WindowsPowerShell/Microsoft.PowerShell_profile.ps1` | `Alias/Windows/PowerShell/profile.ps1` |
| PowerShell Core     | `~/Documents/PowerShell/Microsoft.PowerShell_profile.ps1`        | `Alias/Windows/PowerShell/profile.ps1` |
| GitBash             | `~/.bashrc`                                                      | `Alias/Windows/GitBash/.bashrc`        |
| Neovim (Windows)    | `~/AppData/Local/nvim`                                           | `neovim/`                              |
| Yazi (Windows)      | `~/AppData/Roaming/yazi/config`                                  | `yazi/`                                |
| Zed (Windows)       | `~/AppData/Roaming/Zed/settings.json`                            | `zed/settings.json`                    |

---

## GitHub Desktop 호환

설치 스크립트 마지막에 모든 저장소의 remote URL을 HTTPS로 자동 변경. 첫 push 시 GitHub 로그인 팝업이 뜨며, 이후 자격 증명 관리자가 자동 처리.

| 저장소      | URL                                      |
| ----------- | ---------------------------------------- |
| `.dotfiles` | `https://github.com/srzst/.dotfiles.git` |
| `.myConfig` | `https://github.com/srzst/.myConfig.git` |
| `xwin`      | `https://github.com/srzst/xwin.git`      |
| `script`    | `https://github.com/srzst/script.git`    |
| `scriptos`  | `https://github.com/srzst/scriptos.git`  |

> Ubuntu는 `.dotfiles`, `.myConfig` 2개만 clone 및 HTTPS 변경.

---

## 설정 파일 수정 후

```bash
gacp "변경 내용"
```

다른 머신에서:

```bash
gpl
```
