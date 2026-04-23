#!/bin/zsh
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
# Homebrew 및 시스템 PATH 설정 (강제 복구 및 보존)
# ============================================================
setup_brew_env() {
    # 1. 시스템 기본 경로와 Homebrew 경로를 명시적으로 확보 (기존 PATH 포함)
    export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"

    # 2. Apple Silicon Mac 환경 로드
    if [[ $(uname -m) == 'arm64' ]]; then
        if [[ -x /opt/homebrew/bin/brew ]]; then
            # PATH가 덮어씌워지지 않도록 eval 실행
            eval "$(/opt/homebrew/bin/brew shellenv)"
            # eval 이후에도 시스템 경로가 뒤로 밀리지 않도록 재차 보강
            export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
        fi
    fi
}

# 함수 즉시 실행하여 하위 명령어들의 경로 확보
setup_brew_env
if ! command -v brew &>/dev/null; then
    echo "Homebrew 설치 중..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    setup_brew_env
    echo "OK Homebrew 설치 완료"
else
    echo "OK Homebrew 이미 설치됨 (스킵)"
    setup_brew_env
fi

if ! command -v brew &>/dev/null && [[ -f /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
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
# 토큰 취득 (Zsh 호환성 수정)
# ============================================================
if [ "$MODE" -eq 2 ]; then
  echo "t.enc 복호화로 Infisical 토큰 취득 중..."
  curl -sL "$BOOTSTRAP_TOKEN_URL" -o /tmp/t.enc
  # Zsh read 문법 적용
  read -s "DECODE_PASS?복호화 암호: "; echo

  # 인코딩 오류 방지를 위해 tr 대신 Zsh 내장 치환 사용
  RAW_TOKEN=$(openssl enc -aes-256-cbc -pbkdf2 -d -in /tmp/t.enc -pass pass:"$DECODE_PASS" 2>/dev/null)
  INFISICAL_TOKEN="${RAW_TOKEN//[$'\t\r\n']/}"

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
    read "INFISICAL_INPUT_TOKEN?Infisical 서비스 토큰: "; echo
    echo "export INFISICAL_TOKEN=\"$INFISICAL_INPUT_TOKEN\"" > ~/.zshrc_secrets
    chmod 600 ~/.zshrc_secrets
    echo "OK ~/.zshrc_secrets 생성 완료"
  fi
  source ~/.zshrc_secrets
  echo "OK Infisical 토큰 로드 완료"
fi
export INFISICAL_TOKEN
# ============================================================
# fetch_secret: 멀티라인(SSH 키 등) 보존형 함수
# ============================================================

fetch_secret() {
    local key="$1"
    local secret_path="${2:-/}"
    local val

    # 1. Infisical에서 값 가져오기 (따옴표로 감싸서 공백/줄바꿈 보존)
    val=$(infisical secrets get "$key" \
        --projectId="$INFISICAL_PROJECT_ID" \
        --env="$INFISICAL_ENV" \
        --path="$secret_path" \
        --plain --silent 2>/dev/null)

    if [[ -z "$val" ]]; then
        return 1
    fi

    # 2. 정규화: 이스케이프된 \n 문자를 실제 줄바꿈으로 복원 (컨텍스트 규칙 반영)
    val="${val//\\n/$'\n'}"
    # Windows 스타일 \r 제거
    val="${val//$'\r'/}"

    # 3. 값 반환 (함수 결과값 출력 시 줄바꿈 유지를 위해 echo 대신 printf 활용 권장)
    printf "%s" "$val"
}
# ============================================================
# Git 설정
# ============================================================
git config --global user.email "x@srzst.com"
git config --global user.name "x"
echo "OK Git 설정 완료"
# ============================================================
# 파일 시크릿 복원 루프
# ============================================================
if [ "$TARGET" -ne 3 ]; then
    echo ""
    echo "파일 시크릿 복원 중..."

    typeset -A file_secrets
    file_secrets=(
        "github_private_ssh_os_srzst" "/github:$HOME/.ssh/id_ed25519:600"
        "config"                     "/aws:$HOME/.aws/config:644"
        "credentials"                "/aws:$HOME/.aws/credentials:600"
        "backblazeapi"               "/backblaze:$HOME/.backblaze/backblazeapi:600"
        "git_credentials"            "/github:$HOME/.git-credentials:600"
        "main_ssh_private_key"       "/:$HOME/.ssh/main_ssh_key:600"
        "main_ssh_public_key"        "/:$HOME/.ssh/main_ssh_key.pub:644"
    )

    for key in "${(k)file_secrets[@]}"; do
        val_info="${file_secrets[$key]}"
        # path 대신 secret_path 사용 (Zsh $PATH 충돌 방지)
        IFS=':' read -r secret_path dest perm <<EOF
$val_info
EOF
        # 값을 가져올 때 줄바꿈이 깨지지 않도록 변수에 담음
        val=$(fetch_secret "$key" "$secret_path")

        if [[ -n "$val" ]]; then
            mkdir -p "$(dirname "$dest")"
            # 파일 저장 시 반드시 "$val" (따옴표) 사용해야 멀티라인 유지됨
            echo "$val" > "$dest"
            chmod "$perm" "$dest"
            echo "OK 파일 저장 성공: $dest"
        else
            echo "WARN 파일 저장 실패 (값 없음): $key (경로: $secret_path)"
        fi
    done
    echo "OK 파일 시크릿 복원 완료"
fi
# ============================================================
# Keychain 시크릿 주입 (Windows 변수명과 매칭)
# ============================================================
if [ "$TARGET" -ne 3 ]; then
  echo ""
  echo "Keychain 시크릿 주입 중..."
  typeset -A keychain_secrets
  keychain_secrets=(
    "tailscale_authkey" "/"
    "gistup_md_manual_srzst" "/github"
    "personal_access_tokens_classic_sndzin" "/github"
    "personal_access_tokens_classic_srzst" "/github"
  )
  for key in "${(k)keychain_secrets[@]}"; do
    secret_path="${keychain_secrets[$key]}"
    val=$(fetch_secret "$key" "$secret_path")
    if [[ -n "$val" ]]; then
      security add-generic-password -a "$USER" -s "$key" -w "$val" -U 2>/dev/null
      echo "OK Keychain 저장: $key"
    else
      echo "WARN Keychain 저장 실패 (값 없음): $key (경로: $secret_path)"
    fi
  done
  echo "OK Keychain 주입 완료"
fi

# ============================================================
# SSH config 설정
# ============================================================
mkdir -p ~/.ssh
chmod 700 ~/.ssh

if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  User git
EOF
  echo "OK SSH config GitHub 설정 완료"
else
  sed -i '' '/Host github.com/,/IdentityFile/s|IdentityFile.*|IdentityFile ~/.ssh/id_ed25519|' ~/.ssh/config
  echo "OK SSH config GitHub 업데이트 완료"
fi

if ! grep -q "main_ssh_key" ~/.ssh/config 2>/dev/null; then
  echo -e "\nHost *\n  IdentityFile ~/.ssh/main_ssh_key\n  StrictHostKeyChecking no" >> ~/.ssh/config
  echo "OK SSH main_ssh_key config 추가 완료"
fi
chmod 600 ~/.ssh/config

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
# rclone 설정 복원
# ============================================================
mkdir -p ~/.config/rclone
val=$(fetch_secret "rclone_conf" "/rclone")
if [[ -n "$val" ]]; then
    printf "%s" "$val" > ~/.config/rclone/rclone.conf
    chmod 600 ~/.config/rclone/rclone.conf
    echo "OK rclone.conf 복원 완료"
else
    echo "WARN rclone.conf 복원 실패 (값 없음)"
fi

# ============================================================
# gh CLI GitHub 인증
# ============================================================
ghToken=$(fetch_secret "personal_access_tokens_classic_srzst" "/github")
if [[ -n "$ghToken" ]]; then
    echo "$ghToken" | gh auth login --with-token
    echo "OK gh CLI 인증 완료"
else
    echo "WARN gh CLI 인증 실패 → Infisical 토큰 확인 필요"
fi

# ============================================================
# 글로벌 gitignore 설정
# ============================================================
git config --global core.excludesfile ~/.gitignore_global
touch ~/.gitignore_global
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
# 심볼릭 링크 설정 (앱 및 설정 폴더 통합)
# ============================================================
echo ""
echo "심볼릭 링크 설정 중..."

# 1. 기본 설정 파일
ln -sf "$REPO/mac/Alias/.zshrc" ~/.zshrc
ln -sf "$REPO/Common/Vim/.vimrc" ~/.vimrc

# 2. .config 하위 디렉토리 생성
mkdir -p ~/.config/nvim ~/.config/yazi ~/.config/zed ~/.config/ghostty
mkdir -p "$HOME/Library/Application Support"
# 3. .dotfiles(REPO) 기반 설정 연결
ln -sf "$REPO/Common/neovim" ~/.config/nvim
ln -sf "$REPO/Common/yazi" ~/.config/yazi
ln -sf "$REPO/Common/zed/settings.json" ~/.config/zed/settings.json
ln -sf "$REPO/Common/zed/keymap.json"   ~/.config/zed/keymap.json
ln -sf "$REPO/Common/zed/tasks.json"    ~/.config/zed/tasks.json
# 4. .dotfolders(FOLDERS) 기반 설정 연결


# Ghostty
if [ -f "$FOLDERS/common/ghostty/config.ghosty" ]; then
    ln -sf "$FOLDERS/common/ghostty/config.ghosty" ~/.config/ghostty/config
    echo "OK Ghostty 연결 완료"
else
    echo "WARN Ghostty 파일을 찾을 수 없습니다: $FOLDERS/common/ghostty/config.ghosty"
fi

# BetterTouchTool
if [ -d "$FOLDERS/mac/btt" ]; then
    rm -rf "$HOME/Library/Application Support/BetterTouchTool"
    ln -s "$FOLDERS/mac/btt" "$HOME/Library/Application Support/BetterTouchTool"
    echo "OK BetterTouchTool 연결 완료"
fi

# Keyboard Maestro
if [ -d "$FOLDERS/mac/keyboard_maestro" ]; then
    rm -rf "$HOME/Library/Application Support/Keyboard Maestro"
    ln -s "$FOLDERS/mac/keyboard_maestro" "$HOME/Library/Application Support/Keyboard Maestro"
    echo "OK Keyboard Maestro 연결 완료"
fi

echo "OK 모든 심볼릭 링크 설정 완료"


# ============================================================
# LaunchAgents 등록 (사용자 커스텀 스크립트 자동 실행)
# ============================================================
echo -e "\nLaunchAgents 설정 및 로드 중..."

# 1. 시스템 LaunchAgents 디렉토리 생성
mkdir -p ~/Library/LaunchAgents

# 2. .dotfiles 내의 plist 파일들을 시스템 경로로 심볼릭 링크 연결
# (사용자님의 폴더 구조에 맞춰 경로 수정: $REPO/mac/LaunchAgents 로 가정)
AGENT_SRC="$REPO/mac/LaunchAgents"

if [ -d "$AGENT_SRC" ]; then
    for plist in "$AGENT_SRC"/*.plist; do
        filename=$(basename "$plist")
        ln -sf "$plist" ~/Library/LaunchAgents/"$filename"

        # 3. 에이전트 로드 (이미 로드된 경우 unload 후 다시 load)
        launchctl unload ~/Library/LaunchAgents/"$filename" 2>/dev/null
        launchctl load ~/Library/LaunchAgents/"$filename"
        echo "OK 에이전트 로드 완료: $filename"
    done
else
    echo "WARN LaunchAgents 소스 폴더를 찾을 수 없습니다: $AGENT_SRC"
fi
# ============================================================
# Homebrew 패키지 설치 (Raycast, BTT, KM 및 Zsh 플러그인 추가)
# ============================================================
echo ""
echo "Homebrew 앱 설치 중 (TARGET=$TARGET)..."
export HOMEBREW_NO_AUTO_UPDATE=1

typeset -a apps casks
if [ "$TARGET" -eq 1 ]; then
    # --- CLI Tools & Plugins ---
    apps=(
        git python python-tk node ffmpeg-full yt-dlp
        pngpaste wget terminal-notifier pipx rclone
        neovim lazygit eza yazi sevenzip jq poppler
        fd ripgrep fzf zoxide imagemagick
        zsh-syntax-highlighting zsh-autosuggestions
        font-d2coding-nerd-font font-d2coding
    )
    # --- GUI Applications (Casks) ---
    casks=(
        google-chrome
        raycast               # 런처
        hammerspoon           # 자동화
        karabiner-elements    # 키 매핑
        bettertouchtool       # 입력 장치 확장
        keyboard-maestro      # 매크로 자동화
        shottr                # 스크린샷
        popclip               # 텍스트 팝업 메뉴
        font-hack-nerd-font
        font-symbols-only-nerd-font
    )
elif [ "$TARGET" -eq 2 ]; then
    apps=(
        git python node wget pipx neovim
        lazygit yazi fd ripgrep fzf zoxide
        zsh-syntax-highlighting zsh-autosuggestions
    )
    casks=(
        raycast
        font-hack-nerd-font
        font-symbols-only-nerd-font
    )
else
    apps=(git python wget neovim)
fi

for app in "${apps[@]}"; do
    brew list --formula "$app" &>/dev/null || brew install "$app"
done
for cask in "${casks[@]}"; do
    brew list --cask "$cask" &>/dev/null || brew install --cask "$cask"
done
echo "OK Homebrew 앱 설치 완료"

# ============================================================
# 시작 프로그램(Login Items) 및 주요 앱 등록
# ============================================================
echo -e "\n시작 프로그램 등록 중..."

typeset -a login_apps
login_apps=(
    "Raycast"
    "Hammerspoon"
    "Karabiner-Elements"
    "Shottr"
    "BetterTouchTool"
    "Keyboard Maestro"
    "Bitwarden"
    "PopClip"
    "CleanShot X"
)

for app in "${login_apps[@]}"; do
    APP_PATH="/Applications/${app}.app"
    if [ -d "$APP_PATH" ]; then
        # 이미 등록되어 있는지 확인 후, 없을 때만 추가 (오류 방지)
        check_item=$(osascript -e "tell application \"System Events\" to get name of every login item" | grep -w "$app")
        if [ -z "$check_item" ]; then
            osascript -e "tell application \"System Events\" to make login item at end with properties {path:\"$APP_PATH\", hidden:false}" 2>/dev/null
            echo "OK 시작 프로그램 등록 완료: $app"
        else
            echo "SKIP 이미 등록됨: $app"
        fi
    fi
done
# ============================================================
# GitHub Desktop 호환 - remote HTTPS 변경
# ============================================================
if [ "$TARGET" -eq 1 ]; then
  typeset -A https_repos
  https_repos=(
    "$REPO" "https://github.com/srzst/.dotfiles.git"
    "$HOME/.myConfig" "https://github.com/srzst/.myConfig.git"
    "$HOME/xwin" "https://github.com/srzst/xwin.git"
    "$HOME/script" "https://github.com/srzst/script.git"
    "$HOME/scriptos" "https://github.com/srzst/scriptos.git"
  )
  for repo_path in "${(k)https_repos[@]}"; do
    if [ -d "$repo_path" ]; then
      git -C "$repo_path" remote set-url origin "${https_repos[$repo_path]}"
    fi
  done
  echo "OK remote URL HTTPS 변경 완료"
fi

echo ""
echo "OK Mac 설치 완료 (TARGET=$TARGET, MODE=$MODE)"


# 데이지  디스크 설치
