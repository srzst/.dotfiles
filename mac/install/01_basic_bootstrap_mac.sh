#!/bin/bash
exec < /dev/tty

# ============================================================
# CONFIG
# ============================================================
TARGET=1  # 0: 복구  1: 기본  2: 경량  3: 임시
MODE=2    # 1: install  2: bootstrap

BOOTSTRAP_TOKEN_URL="https://dl.srz.st/t.enc"
INFISICAL_PROJECT_ID="bc893247-af3f-4118-a8ec-bcb429338acb"
INFISICAL_ENV="dev"
REPO="$HOME/.dotfiles"
FOLDERS="$HOME/.dotfolders"
MACHINE_TYPE="main"
# ============================================================

# ============================================================
# Homebrew 선행 설치 (bootstrap 시 필수)
# ============================================================
if ! command -v brew &>/dev/null; then
  echo "Homebrew 설치 중..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ $(uname -m) == 'arm64' ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  echo "OK Homebrew 설치 완료"
else
  echo "OK Homebrew 이미 설치됨 (스킵)"
  if [[ $(uname -m) == 'arm64' ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# ============================================================
# Infisical CLI 설치
# ============================================================
if ! command -v infisical &>/dev/null; then
  echo "Infisical CLI 설치 중..."
  brew install infisical/get-cli/infisical
  echo "OK Infisical CLI 설치 완료"
else
  echo "OK Infisical CLI 이미 설치됨 (스킵)"
fi

# ============================================================
# 토큰 취득
# ============================================================
if [ "$MODE" -eq 2 ]; then
  echo "t.enc 복호화로 Infisical 토큰 취득 중..."
  curl -sL "$BOOTSTRAP_TOKEN_URL" -o /tmp/t.enc
  read -s -p "복호화 암호: " DECODE_PASS; echo
  INFISICAL_TOKEN=$(openssl enc -aes-256-cbc -pbkdf2 -d -in /tmp/t.enc -pass pass:"$DECODE_PASS" 2>/dev/null | tr -d '\n\r')
  rm -f /tmp/t.enc
  if [ -z "$INFISICAL_TOKEN" ]; then
    echo "ERR 토큰 복호화 실패"
    exit 1
  fi
  echo "export INFISICAL_TOKEN=\"$INFISICAL_TOKEN\"" > ~/.zshrc_secrets
  chmod 600 ~/.zshrc_secrets
  echo "OK 토큰 취득 완료"
else
  if [ ! -f ~/.zshrc_secrets ]; then
    read -rp "Infisical 서비스 토큰: " INFISICAL_INPUT_TOKEN
    echo "export INFISICAL_TOKEN=\"$INFISICAL_INPUT_TOKEN\"" > ~/.zshrc_secrets
    chmod 600 ~/.zshrc_secrets
    echo "OK ~/.zshrc_secrets 생성 완료"
  fi
  source ~/.zshrc_secrets
  echo "OK Infisical 토큰 로드 완료"
fi
export INFISICAL_TOKEN

# ============================================================
# fetch_secret 함수
# ============================================================
fetch_secret() {
  local key="$1"
  local path="${2:-/}"
  INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get "$key" \
    --projectId="$INFISICAL_PROJECT_ID" \
    --env="$INFISICAL_ENV" \
    --path="$path" \
    --plain --silent 2>/dev/null | tr -d '\n'
}

# ============================================================
# Git 설정
# ============================================================
git config --global user.email "x@srzst.com"
git config --global user.name "x"
echo "OK Git 설정 완료"

# ============================================================
# 파일 시크릿 복원 (TARGET != 3)
# ============================================================
if [ "$TARGET" -ne 3 ]; then
  echo ""
  echo "파일 시크릿 복원 중..."
  declare -A file_secrets=(
    ["github_private_ssh_os_srzst"]="/github:$HOME/.ssh/id_ed25519:600"
    ["config"]="/aws:$HOME/.aws/config:644"
    ["credentials"]="/aws:$HOME/.aws/credentials:600"
    ["backblazeapi"]="/backblaze:$HOME/.backblaze/backblazeapi:600"
    ["git_credentials"]="/github:$HOME/.git-credentials:600"
  )
  for key in "${!file_secrets[@]}"; do
    IFS=':' read -r path dest perm <<< "${file_secrets[$key]}"
    val=$(fetch_secret "$key" "$path")
    if [ -n "$val" ]; then
      mkdir -p "$(dirname "$dest")"
      echo "$val" > "$dest"
      chmod "$perm" "$dest"
      echo "OK 파일 저장: $dest"
    else
      echo "WARN 파일 저장 실패 (값 없음): $key"
    fi
  done
  echo "OK 파일 시크릿 복원 완료"
fi

# ============================================================
# Keychain 시크릿 주입 (TARGET != 3)
# ============================================================
if [ "$TARGET" -ne 3 ]; then
  echo ""
  echo "Keychain 시크릿 주입 중..."
  declare -A keychain_secrets=(
    ["tailscale_authkey"]="/"
    ["gistup_md_manual_srzst"]="/github"
    ["token_gist_sndzin"]="/github"
    ["token_gist_srzst"]="/github"
  )
  for key in "${!keychain_secrets[@]}"; do
    path="${keychain_secrets[$key]}"
    val=$(fetch_secret "$key" "$path")
    if [ -n "$val" ]; then
      security add-generic-password -a "$USER" -s "$key" -w "$val" -U 2>/dev/null
      echo "OK Keychain 저장: $key"
    else
      echo "WARN Keychain 저장 실패 (값 없음): $key"
    fi
  done
  echo "OK Keychain 주입 완료"
fi

# TARGET=0: 복구 후 종료
if [ "$TARGET" -eq 0 ]; then
  echo ""
  echo "OK 복구 완료 (TARGET=0)"
  exit 0
fi

# ============================================================
# SSH config 설정
# ============================================================
mkdir -p ~/.ssh
if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  User git
EOF
  chmod 600 ~/.ssh/config
  echo "OK SSH config 설정 완료"
else
  sed -i '' '/Host github.com/,/^$/s|IdentityFile.*|IdentityFile ~/.ssh/id_ed25519|' ~/.ssh/config
  echo "OK SSH config 업데이트 완료"
fi

# ============================================================
# GitHub SSH 연결 테스트
# ============================================================
echo ""
echo "GitHub SSH 연결 테스트 중..."
ssh-keyscan -T 5 github.com >> ~/.ssh/known_hosts 2>/dev/null
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "OK GitHub SSH 인증 성공" \
  || echo "WARN GitHub SSH 인증 실패 - Infisical 키 또는 GitHub 등록 확인 필요"

# ============================================================
# 글로벌 gitignore 설정
# ============================================================
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
grep -qxF '.pwsh_secrets*' ~/.gitignore_global 2>/dev/null || echo '.pwsh_secrets*' >> ~/.gitignore_global
echo "OK 글로벌 gitignore 설정 완료"

# ============================================================
# .dotfiles clone
# ============================================================
echo ""
echo ".dotfiles clone 중..."
if [ ! -d "$REPO" ]; then
  git clone "git@github.com:srzst/.dotfiles" "$REPO" 2>/dev/null || \
  git clone "https://github.com/srzst/.dotfiles" "$REPO"
  echo "OK .dotfiles clone 완료"
else
  git -C "$REPO" pull
  echo "OK .dotfiles 이미 존재 (pull 완료)"
fi

# ============================================================
# 글로벌 gitattributes 설정
# ============================================================
ln -sf "$REPO/.gitattributes" ~/.gitattributes_global
git config --global core.attributesFile ~/.gitattributes_global
echo "OK Git 글로벌 attributes 연결 완료"

# ============================================================
# .dotfolders clone
# ============================================================
echo ""
echo ".dotfolders clone 중..."
if [ ! -d "$FOLDERS" ]; then
  git clone "git@github.com:srzst/.dotfolders" "$FOLDERS" 2>/dev/null
  echo "OK .dotfolders clone 완료"
else
  echo "OK .dotfolders 이미 존재 (스킵)"
fi

# ============================================================
# Private 저장소 clone (기본만)
# ============================================================
if [ "$TARGET" -eq 1 ]; then
  echo ""
  echo "Private 저장소 clone 중..."
  repos=(
    "git@github.com:srzst/.myConfig"
    "git@github.com:srzst/xwin"
    "git@github.com:srzst/script"
    "git@github.com:srzst/scriptos"
  )
  for repo in "${repos[@]}"; do
    repo_name=$(basename "$repo")
    if [ ! -d "$HOME/$repo_name" ]; then
      git clone "$repo" "$HOME/$repo_name" 2>/dev/null
      echo "OK $repo_name clone 완료"
    else
      echo "OK $repo_name 이미 존재 (스킵)"
    fi
  done
fi

# ============================================================
# 심볼릭 링크 - .dotfiles (공통)
# ============================================================
echo ""
echo "심볼릭 링크 설정 중..."
rm -f ~/.zshrc
ln -sf "$REPO/mac/Alias/.zshrc" ~/.zshrc
echo "OK .zshrc 연결 완료"
rm -f ~/.vimrc
ln -sf "$REPO/Common/Vim/.vimrc" ~/.vimrc
echo "OK .vimrc 연결 완료"
rm -rf ~/.config/nvim
mkdir -p ~/.config
ln -sf "$REPO/Common/neovim" ~/.config/nvim
echo "OK Neovim 연결 완료"
rm -rf ~/.config/yazi
ln -sf "$REPO/Common/yazi" ~/.config/yazi
echo "OK Yazi 설정 연결 완료"
mkdir -p ~/.config/zed
ln -sf "$REPO/Common/zed/settings.json" ~/.config/zed/settings.json
echo "OK Zed 설정 연결 완료"
mkdir -p "$HOME/Library/Application Support/Code/User"
rm -f "$HOME/Library/Application Support/Code/User/keybindings.json"
ln -sf "$REPO/common/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
echo "OK VSCode keybindings 연결 완료"
rm -f "$HOME/Library/Application Support/Code/User/settings.json"
ln -sf "$REPO/common/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
echo "OK VSCode settings 연결 완료"
mkdir -p "$HOME/Library/Application Support/Cursor/User"
rm -f "$HOME/Library/Application Support/Cursor/User/keybindings.json"
ln -sf "$REPO/common/cursor/keybindings.json" "$HOME/Library/Application Support/Cursor/User/keybindings.json"
echo "OK Cursor keybindings 연결 완료"
rm -f "$HOME/Library/Application Support/Cursor/User/settings.json"
ln -sf "$REPO/common/cursor/settings.json" "$HOME/Library/Application Support/Cursor/User/settings.json"
echo "OK Cursor settings 연결 완료"

# ============================================================
# 심볼릭 링크 - .dotfolders/mac (기본/경량)
# ============================================================
if [ "$TARGET" -le 2 ]; then
  rm -rf ~/.hammerspoon
  ln -sf "$FOLDERS/mac/.hammerspoon" ~/.hammerspoon
  echo "OK Hammerspoon 연결 완료"
  mkdir -p ~/.config/karabiner
  rm -f ~/.config/karabiner/karabiner.json
  ln -sf "$FOLDERS/mac/karabiner/karabiner.json" ~/.config/karabiner/karabiner.json
  echo "OK Karabiner 연결 완료"
  mkdir -p ~/.config/raycast
  rm -f ~/.config/raycast/config.json
  ln -sf "$FOLDERS/mac/raycast/config.json" ~/.config/raycast/config.json
  rm -rf ~/.config/raycast/extensions
  ln -sf "$FOLDERS/mac/raycast/extensions" ~/.config/raycast/extensions
  echo "OK Raycast 연결 완료"
  mkdir -p "$HOME/Library/Application Support/tabby"
  rm -f "$HOME/Library/Application Support/tabby/config.yaml"
  ln -sf "$FOLDERS/common/tabby/config.yaml" "$HOME/Library/Application Support/tabby/config.yaml"
  echo "OK Tabby 연결 완료"
fi

# ============================================================
# secrets 로드 구문 추가
# ============================================================
if ! grep -q 'zshrc_secrets' "$REPO/mac/Alias/.zshrc" 2>/dev/null; then
  echo '[[ -f ~/.zshrc_secrets ]] && source ~/.zshrc_secrets' >> "$REPO/mac/Alias/.zshrc"
  echo "OK .zshrc에 secrets 로드 구문 추가 완료"
fi

if [[ $(uname -m) == 'arm64' ]]; then
  if ! grep -q 'brew shellenv' "$REPO/mac/Alias/.zshrc" 2>/dev/null; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$REPO/mac/Alias/.zshrc"
  fi
fi

# ============================================================
# Homebrew 패키지 설치
# ============================================================
echo ""
echo "Homebrew 앱 설치 중..."
if [ "$TARGET" -eq 1 ]; then
  brew install git python python-tk node ffmpeg yt-dlp pngpaste wget terminal-notifier pipx rclone
  brew install neovim lazygit
  brew install yazi sevenzip jq poppler fd ripgrep fzf zoxide imagemagick
  brew install --cask \
    google-chrome brave-browser microsoft-edge \
    visual-studio-code cursor zed \
    github hammerspoon karabiner-elements \
    obsidian tabby shottr mountain-duck \
    popclip keka dockdoor raycast hiddenbar alt-tab \
    font-hack-nerd-font font-symbols-only-nerd-font
elif [ "$TARGET" -eq 2 ]; then
  brew install git python node wget pipx
  brew install neovim lazygit
  brew install yazi fd ripgrep fzf zoxide
  brew install --cask \
    visual-studio-code zed \
    font-hack-nerd-font font-symbols-only-nerd-font
elif [ "$TARGET" -eq 3 ]; then
  brew install git python wget
  brew install neovim
fi
echo "OK Homebrew 앱 설치 완료"

# ============================================================
# pipx / gita 설치 (기본/경량)
# ============================================================
if [ "$TARGET" -le 2 ]; then
  pipx ensurepath
  export PATH="$HOME/.local/bin:$PATH"
  pipx install gita
  echo "OK pipx/gita 설치 완료"
fi

# ============================================================
# pip 패키지 설치 (기본만)
# ============================================================
if [ "$TARGET" -eq 1 ]; then
  echo ""
  echo "pip 패키지 설치 중..."
  pip3 install \
    boto3 pillow pync pyobjc requests mistune \
    watchdog pyperclip plyer PyQt5 b2sdk cloudinary \
    pynput pygments dropbox pandas tabulate \
    oauth2client gspread google-api-python-client
  echo "OK pip 패키지 설치 완료"

  npm install -g electron
  echo "OK npm 패키지 설치 완료"
fi

# ============================================================
# gita 등록 (기본/경량)
# ============================================================
if [ "$TARGET" -le 2 ]; then
  gita add "$REPO" 2>/dev/null
  echo "OK gita .dotfiles 등록 완료"
fi

# ============================================================
# LaunchAgents / KeyBindings 설정 (기본만)
# ============================================================
if [ "$TARGET" -eq 1 ]; then
  echo ""
  echo "LaunchAgents 설정 중..."
  LAUNCH_AGENTS_SRC="$FOLDERS/mac/LaunchAgents"
  LAUNCH_AGENTS_DST="$HOME/Library/LaunchAgents"
  mkdir -p "$LAUNCH_AGENTS_DST"
  if [ -d "$LAUNCH_AGENTS_SRC" ]; then
    for plist in "$LAUNCH_AGENTS_SRC"/*.plist; do
      cp "$plist" "$LAUNCH_AGENTS_DST/"
      launchctl load "$LAUNCH_AGENTS_DST/$(basename $plist)" 2>/dev/null
      echo "OK $(basename $plist) 로드 완료"
    done
  fi

  KEYBINDINGS_SRC="$FOLDERS/mac/KeyBindings/DefaultKeyBinding.dict"
  KEYBINDINGS_DST="$HOME/Library/KeyBindings"
  if [ -f "$KEYBINDINGS_SRC" ]; then
    mkdir -p "$KEYBINDINGS_DST"
    cp "$KEYBINDINGS_SRC" "$KEYBINDINGS_DST/"
    echo "OK KeyBindings 설정 완료"
  fi
fi

# ============================================================
# macOS 시스템 설정 (기본/경량)
# ============================================================
if [ "$TARGET" -le 2 ]; then
  echo ""
  echo "macOS 시스템 설정 중..."
  defaults write com.apple.finder AppleShowAllFiles -bool true
  killall Finder
  echo "OK Finder 숨김 파일 표시 완료"
  sudo nvram SystemAudioVolume=%80 2>/dev/null
  echo "OK 부팅음 끄기 완료"
  defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
  defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1
  echo "OK 트랙패드 탭 클릭 완료"
  defaults write com.apple.dock autohide -bool true
  killall Dock
  echo "OK Dock 자동 숨기기 완료"
  defaults write NSGlobalDomain NSAutomaticQuoteSubstitutionEnabled -bool false
  echo "OK 스마트 인용 부호 끄기 완료"
  defaults write NSGlobalDomain NSAutomaticPeriodSubstitutionEnabled -bool false
  echo "OK 스페이스바 마침표 끄기 완료"
  defaults write NSGlobalDomain com.apple.keyboard.fnState -bool true
  echo "OK 기능키 활성화 완료"
  defaults write com.apple.menuextra.battery ShowPercent -string "YES"
  echo "OK 배터리 퍼센트 표시 완료"
fi

# ============================================================
# GitHub Desktop 호환 - remote HTTPS 변경 (기본만)
# ============================================================
if [ "$TARGET" -eq 1 ]; then
  declare -A https_repos=(
    ["$REPO"]="https://github.com/srzst/.dotfiles.git"
    ["$HOME/.myConfig"]="https://github.com/srzst/.myConfig.git"
    ["$HOME/xwin"]="https://github.com/srzst/xwin.git"
    ["$HOME/script"]="https://github.com/srzst/script.git"
    ["$HOME/scriptos"]="https://github.com/srzst/scriptos.git"
  )
  for repo_path in "${!https_repos[@]}"; do
    if [ -d "$repo_path" ]; then
      git -C "$repo_path" remote set-url origin "${https_repos[$repo_path]}"
      echo "OK remote HTTPS 변경: ${https_repos[$repo_path]}"
    fi
  done
  echo "OK 전체 remote URL HTTPS로 변경 완료 (GitHub Desktop 호환)"
fi

# ============================================================
# LazyVim 초기화
# ============================================================
nvim --headless "+Lazy! sync" +qa 2>/dev/null
echo "OK LazyVim 초기화 완료"

echo ""
echo "OK Mac 설치 완료 (TARGET=$TARGET, MODE=$MODE)"
echo "INFO 재시작 후 모든 설정이 적용됩니다."