#!/bin/bash
REPO="$HOME/.dotfiles"

# ============================================================
# install_mac.sh 
# 사용자: x / 암호: (Bitwarden 참고)
# chmod +x ~/.dotfiles/_install/install_mac.sh
# bash ~/.dotfiles/_install/install_mac.sh
# ============================================================

# ============================================================
# 버전 변수 (업데이트 시 여기만 수정)
# ※ 버전 확인: https://github.com/bitwarden/sdk-sm/releases
# ============================================================
BWS_VERSION="2.0.0"
BWS_URL_ARM="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-aarch64-apple-darwin-${BWS_VERSION}.zip"
BWS_URL_X86="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-x86_64-apple-darwin-${BWS_VERSION}.zip"

# BWS 액세스 토큰 입력 (가장 먼저)
if [ ! -f ~/.zshrc_secrets ]; then
  echo "BWS 액세스 토큰을 입력하세요 (입력 후 Enter):"
  read -r BWS_INPUT_TOKEN
  echo "export BWS_ACCESS_TOKEN=\"$BWS_INPUT_TOKEN\"" > ~/.zshrc_secrets
  chmod 600 ~/.zshrc_secrets
  echo "OK ~/.zshrc_secrets 생성 완료"
else
  echo "OK ~/.zshrc_secrets 이미 존재 (스킵)"
fi
source ~/.zshrc_secrets
echo "OK BWS 토큰 로드 완료"

# Git 설정
git config --global user.email "x@srzst.com"
git config --global user.name "x"
echo "OK Git 설정 완료"

# FIX: bws CLI 이미 설치된 경우 스킵
BWS_BIN="$HOME/bws/bws"
if [ ! -f "$BWS_BIN" ]; then
  echo "bws CLI 설치 중..."
  mkdir -p ~/bws
  if [[ $(uname -m) == 'arm64' ]]; then
    curl -L -o ~/bws/bws.zip "$BWS_URL_ARM"
  else
    curl -L -o ~/bws/bws.zip "$BWS_URL_X86"
  fi
  unzip -o ~/bws/bws.zip -d ~/bws
  chmod +x "$BWS_BIN"
  rm ~/bws/bws.zip
  echo "OK bws CLI 설치 완료"
else
  echo "OK bws CLI 이미 설치됨 (스킵)"
fi

# BWS secrets 복원 함수
fetch_secret() {
  "$BWS_BIN" secret get "$1" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])"
}

# SSH 개인키 복원 (BWS)
echo ""
echo "SSH 개인키 복원 중 (BWS: github_private_ssh_os_srzst)..."
mkdir -p ~/.ssh
fetch_secret "1eb6113c-83a3-4500-8d6c-b401000f48e3" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
echo "OK SSH 개인키 복원 완료"

# SSH config 설정
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

# GitHub 연결 테스트
echo ""
echo "GitHub SSH 연결 테스트 중..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "OK GitHub SSH 인증 성공" \
  || echo "WARN GitHub SSH 인증 실패 - BWS 키 또는 GitHub 등록 확인 필요"

# 나머지 BWS secrets 복원
mkdir -p ~/.aws
fetch_secret "95831a03-5ddd-46de-ac7c-b40000d57326" > ~/.aws/config
fetch_secret "96f60cf0-88f7-474d-9336-b40000d54799" > ~/.aws/credentials
chmod 600 ~/.aws/credentials
echo "OK .aws 완료"
mkdir -p ~/.backblaze
fetch_secret "fd5852f6-8474-4fac-9888-b40000d8ea90" > ~/.backblaze/backblazeapi
chmod 600 ~/.backblaze/backblazeapi
echo "OK .backblaze 완료"
fetch_secret "711d2b06-8271-4470-8e63-b40000d9129f" > ~/.git-credentials
chmod 600 ~/.git-credentials
echo "OK .git-credentials 완료"

# 글로벌 gitignore 설정
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
grep -qxF '.pwsh_secrets*' ~/.gitignore_global 2>/dev/null || echo '.pwsh_secrets*' >> ~/.gitignore_global
echo "OK 글로벌 gitignore 설정 완료"

# Private 저장소 clone (SSH 키 복원 후)
echo ""
echo "Private 저장소 clone 중..."
CLONE_DIR="$HOME"
repos=(
  "git@github.com:srzst/.myConfig"
  "git@github.com:srzst/xwin"
  "git@github.com:srzst/script"
  "git@github.com:srzst/scriptos"
)
for repo in "${repos[@]}"; do
  repo_name=$(basename "$repo")
  if [ ! -d "$CLONE_DIR/$repo_name" ]; then
    git clone "$repo" "$CLONE_DIR/$repo_name"
    echo "OK $repo_name clone 완료"
  else
    echo "OK $repo_name 이미 존재 (스킵)"
  fi
done

# 심볼릭 링크
rm -f ~/.zshrc
ln -sf "$REPO/Alias/macOS/.zshrc" ~/.zshrc
echo "OK .zshrc 연결 완료"
rm -f ~/.vimrc
ln -sf "$REPO/Vim/.vimrc" ~/.vimrc
echo "OK .vimrc 연결 완료"
rm -rf ~/.config/nvim
mkdir -p ~/.config
ln -sf "$REPO/neovim" ~/.config/nvim
echo "OK Neovim 연결 완료"
rm -rf ~/.config/yazi
ln -sf "$REPO/yazi" ~/.config/yazi
echo "OK Yazi 설정 연결 완료"
mkdir -p "$HOME/Library/Application Support/Code/User"
ln -sf "$REPO/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
echo "OK VSCode keybindings 연결 완료"
mkdir -p "$HOME/Library/Application Support/Cursor/User"
ln -sf "$REPO/vscode/keybindings.json" "$HOME/Library/Application Support/Cursor/User/keybindings.json"
echo "OK Cursor keybindings 연결 완료"
mkdir -p ~/.config/zed
ln -sf "$REPO/zed/settings.json" ~/.config/zed/settings.json
echo "OK Zed 설정 연결 완료"

# secrets 로드 구문 추가 (symlink 연결 후, repo 파일에 직접 추가)
if ! grep -q 'zshrc_secrets' "$REPO/Alias/macOS/.zshrc" 2>/dev/null; then
  echo '[[ -f ~/.zshrc_secrets ]] && source ~/.zshrc_secrets' >> "$REPO/Alias/macOS/.zshrc"
  echo "OK .zshrc에 secrets 로드 구문 추가 완료"
fi

# Homebrew 설치 및 패키지
if ! command -v brew &>/dev/null; then
  echo ""
  echo "Homebrew 설치 중..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ $(uname -m) == 'arm64' ]]; then
    echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$REPO/Alias/macOS/.zshrc"
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
  echo "OK Homebrew 설치 완료"
else
  echo "OK Homebrew 이미 설치됨 (스킵)"
fi

echo ""
echo "Homebrew 앱 설치 중..."
brew install git python python-tk node ffmpeg yt-dlp pngpaste wget terminal-notifier pipx
brew install neovim lazygit
brew install yazi sevenzip jq poppler fd ripgrep fzf zoxide imagemagick
brew install --cask \
  google-chrome brave-browser microsoft-edge \
  visual-studio-code cursor zed \
  github hammerspoon karabiner-elements \
  obsidian tabby shottr mountain-duck \
  popclip keka dockdoor raycast hiddenbar \
  font-hack-nerd-font font-symbols-only-nerd-font
echo "OK Homebrew 앱 설치 완료"

# pipx / gita / pip / npm
pipx ensurepath
# FIX: PATH 직접 갱신 (bash 세션에서 zsh 설정 source 불가)
export PATH="$HOME/.local/bin:$PATH"
pipx install gita
echo "OK pipx/gita 설치 완료"

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

gita add "$REPO" 2>/dev/null
echo "OK gita .dotfiles 등록 완료"

# LaunchAgents 설정
echo ""
echo "LaunchAgents 설정 중..."
LAUNCH_AGENTS_SRC="$REPO/_install/mac/LaunchAgents"
LAUNCH_AGENTS_DST="$HOME/Library/LaunchAgents"
mkdir -p "$LAUNCH_AGENTS_DST"
if [ -d "$LAUNCH_AGENTS_SRC" ]; then
  for plist in "$LAUNCH_AGENTS_SRC"/*.plist; do
    cp "$plist" "$LAUNCH_AGENTS_DST/"
    launchctl load "$LAUNCH_AGENTS_DST/$(basename $plist)" 2>/dev/null
    echo "OK $(basename $plist) 로드 완료"
  done
fi

# KeyBindings 설정
KEYBINDINGS_SRC="$REPO/_install/mac/KeyBindings/DefaultKeyBinding.dict"
KEYBINDINGS_DST="$HOME/Library/KeyBindings"
if [ -f "$KEYBINDINGS_SRC" ]; then
  mkdir -p "$KEYBINDINGS_DST"
  cp "$KEYBINDINGS_SRC" "$KEYBINDINGS_DST/"
  echo "OK KeyBindings 설정 완료"
fi

# macOS 시스템 설정
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

# GitHub Desktop 호환 - remote URL HTTPS로 변경
declare -A https_repos=(
  ["$REPO"]="https://github.com/srzst/.dotfiles.git"
  ["$HOME/.myConfig"]="https://github.com/srzst/.myConfig.git"
  ["$HOME/xwin"]="https://github.com/srzst/xwin.git"
  ["$HOME/script"]="https://github.com/srzst/script.git"
  ["$HOME/scriptos"]="https://github.com/srzst/scriptos.git"
)
for path in "${!https_repos[@]}"; do
  if [ -d "$path" ]; then
    git -C "$path" remote set-url origin "${https_repos[$path]}"
    echo "OK remote HTTPS 변경: ${https_repos[$path]}"
  fi
done
echo "OK 전체 remote URL HTTPS로 변경 완료 (GitHub Desktop 호환)"

# LazyVim 초기화 (Neovim 플러그인 동기화)
nvim --headless "+Lazy! sync" +qa 2>/dev/null
echo "OK LazyVim 초기화 완료"

echo ""
echo "OK Mac 설치 완료"
echo "INFO 재시작 후 모든 설정이 적용됩니다."