#!/bin/bash

# ============================================================
# CONFIG
# ============================================================
MODE=2    # 1: install  2: bootstrap
MIRROR=1  # 1: 기본(archive.ubuntu.com)  2: 카카오(mirror.kakao.com)
TARGET=1  # 1: server  2: dev

# BOOTSTRAP_TOKEN_URL="https://dl.srz.st/t.age"
BOOTSTRAP_TOKEN_URL="https://dl.srz.st/t.enc"
INFISICAL_PROJECT_ID="bc893247-af3f-4118-a8ec-bcb429338acb"
INFISICAL_ENV="dev"
REPO="$HOME/.dotfiles"
# ============================================================
# ============================================================
# 사전 입력
# ============================================================
exec < /dev/tty
read -s -p "서버 암호: " USER_PASSWORD; echo ""
SAVED_PASSWORD="$USER_PASSWORD"

echo "$USER_PASSWORD" | sudo -S -v 2>/dev/null
echo "OK sudo 인증 완료"

SUDO_PASS_FILE=$(mktemp); chmod 600 "$SUDO_PASS_FILE"
echo "$USER_PASSWORD" > "$SUDO_PASS_FILE"
while true; do sudo -S -v < "$SUDO_PASS_FILE" 2>/dev/null; sleep 50; done &
SUDO_KEEPALIVE_PID=$!
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null; rm -f $SUDO_PASS_FILE" EXIT
# ============================================================
# hostname 설정
# ============================================================
echo ""
echo "============================================================"
echo " hostname 을 선택하세요"
echo "============================================================"
echo " 1) W1"
echo " 2) W2"
echo " 3) W3"
echo " 4) W5"
echo " 5) shorten"
echo " 6) 직접 입력"
echo "------------------------------------------------------------"
read -p " 선택 (1-6): " HOSTNAME_CHOICE

case $HOSTNAME_CHOICE in
    1) NEW_HOSTNAME="W1" ;;
    2) NEW_HOSTNAME="W2" ;;
    3) NEW_HOSTNAME="W3" ;;
    4) NEW_HOSTNAME="W5" ;;
    5) NEW_HOSTNAME="shorten" ;;
    6) read -p " hostname 입력: " NEW_HOSTNAME ;;
    *) echo "오류: 올바른 번호를 선택하세요."; exit 1 ;;
esac

sudo hostnamectl set-hostname "$NEW_HOSTNAME"
sudo sed -i "s/127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
export HOSTNAME="$NEW_HOSTNAME"
echo "OK hostname 설정 완료: $NEW_HOSTNAME"
# ============================================================
# QEMU Guest Agent 설치 (Proxmox VM 환경)
# ============================================================
read -p "Proxmox VM 환경입니까? qemu-guest-agent 설치 (y/N): " INSTALL_QEMU
if [[ "$INSTALL_QEMU" =~ ^[Yy]$ ]]; then
    sudo apt update && sudo apt install -y qemu-guest-agent
    sudo systemctl enable --now qemu-guest-agent
    echo "OK qemu-guest-agent 설치 완료"
else
    echo "qemu-guest-agent 설치 건너뜀"
fi
# ============================================================
# 기본 패키지 설치 (선행)
# ============================================================
sudo apt-get update -qq
sudo apt-get install -y curl wget git apt-transport-https
echo "OK 기본 패키지 설치 완료"
# ============================================================
# 토큰 획득
# ============================================================
if [ "$MODE" = "2" ]; then
  # ── bootstrap: openssl 복호화로 토큰 획득 ──
  TMP_ENC=$(mktemp /tmp/t_XXXXXX.enc)
  curl -sL "$BOOTSTRAP_TOKEN_URL" -o "$TMP_ENC"
  INFISICAL_INPUT_TOKEN=$(openssl enc -d -aes-256-cbc -pbkdf2 -in "$TMP_ENC" -pass pass:"$SAVED_PASSWORD" 2>/dev/null | tr -d '\n')
  rm -f "$TMP_ENC"
  [ -z "$INFISICAL_INPUT_TOKEN" ] && echo "ERR 토큰 복호화 실패" && exit 1
  echo "OK 토큰 복호화 완료"

else
  # ── install: 토큰 직접 입력 ──
  if [ -f ~/.bashrc_secrets ]; then
    source ~/.bashrc_secrets
    INFISICAL_INPUT_TOKEN="$INFISICAL_TOKEN"
    echo "OK ~/.bashrc_secrets에서 토큰 로드"
  else
    read -p "Infisical 서비스 토큰: " -r INFISICAL_INPUT_TOKEN
  fi
fi

echo "export INFISICAL_TOKEN=\"$INFISICAL_INPUT_TOKEN\"" > ~/.bashrc_secrets
chmod 600 ~/.bashrc_secrets
export INFISICAL_TOKEN="$INFISICAL_INPUT_TOKEN"
echo "OK 토큰 주입 완료"
# ============================================================
# 미러 서버 적용
# ============================================================
if [ "$MIRROR" = "2" ]; then
  sudo sed -i 's|URIs: http://kr.archive.ubuntu.com/ubuntu|URIs: http://mirror.kakao.com/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources
  sudo sed -i 's|URIs: http://archive.ubuntu.com/ubuntu|URIs: http://mirror.kakao.com/ubuntu|g' /etc/apt/sources.list.d/ubuntu.sources
  sudo rm -rf /var/lib/apt/lists/*
  echo "OK 미러 서버 변경 완료: 카카오"
else
  echo "OK 미러 서버 유지: 기본"
fi

# ============================================================
# 시스템 업데이트
# ============================================================
echo "시스템 업데이트 중..."
sudo apt update && sudo apt upgrade -y
echo "OK 시스템 업데이트 완료"

# ============================================================
# 공통 패키지 설치
# ============================================================
echo "패키지 설치 중..."
sudo apt install -y \
  curl wget vim git htop net-tools sudo \
  python3 python3-pip pipx \
  build-essential unzip zip rclone \
  tree tmux apt-transport-https
echo "OK 공통 패키지 설치 완료"

# ============================================================
# dev 전용 패키지 설치
# ============================================================
if [ "$TARGET" = "2" ]; then
  echo "PowerShell 설치 중..."
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.gpg
  curl -sSL https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list \
    | sudo tee /etc/apt/sources.list.d/microsoft-prod.list
  sudo apt update
  sudo apt install -y powershell
  echo "OK PowerShell 설치 완료"

  echo "Yazi 의존성 설치 중..."
  sudo apt install -y ffmpeg 7zip jq poppler-utils fd-find ripgrep fzf zoxide imagemagick
  echo "OK Yazi 의존성 설치 완료"

  echo "Yazi 설치 중..."
  wget -qO yazi.zip https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-gnu.zip
  unzip -q yazi.zip -d yazi-temp
  sudo mv yazi-temp/*/yazi /usr/local/bin/
  sudo mv yazi-temp/*/ya /usr/local/bin/
  rm -rf yazi.zip yazi-temp
  echo "OK Yazi 설치 완료"
fi

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# ============================================================
# Infisical CLI 설치
# ============================================================
if ! command -v infisical &>/dev/null; then
  echo "Infisical CLI 설치 중..."
  curl -1sLf 'https://artifacts-cli.infisical.com/setup.deb.sh' | sudo -E bash
  sudo apt-get install -y infisical
  echo "OK Infisical CLI 설치 완료"
else
  echo "OK Infisical CLI 이미 설치됨 (스킵)"
fi
# ============================================================
# root 암호 결정
# ============================================================
if [ "$MODE" = "2" ]; then
  ROOT_PASSWORD=$(INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get "main_password" \
    --projectId="$INFISICAL_PROJECT_ID" --env="$INFISICAL_ENV" --path="/" \
    --plain --silent 2>/dev/null | tr -d '\n')
  [ -z "$ROOT_PASSWORD" ] && echo "ERR main_password 복원 실패" && exit 1
  echo "OK root 암호 로드 완료"
else
  ROOT_PASSWORD="$SAVED_PASSWORD"
fi

unset USER_PASSWORD SAVED_PASSWORD
echo "OK 입력값 확인 완료 - 설치를 시작합니다."
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

fetch_secret_multiline() {
  local key="$1"
  local path="${2:-/}"
  INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get "$key" \
    --projectId="$INFISICAL_PROJECT_ID" \
    --env="$INFISICAL_ENV" \
    --path="$path" \
    --plain --silent 2>/dev/null
}

# ============================================================
# dev 전용 환경변수 주입
# ============================================================
if [ "$TARGET" = "2" ]; then
  declare -A env_secrets=(
    ["tailscale_authkey"]="/"
    ["gistup_md_manual_srzst"]="/github"
    ["token_gist_sndzin"]="/github"
    ["token_gist_srzst"]="/github"
  )
  for key in "${!env_secrets[@]}"; do
    path="${env_secrets[$key]}"
    val=$(fetch_secret "$key" "$path")
    if [ -n "$val" ]; then
      echo "export $key=\"$val\"" >> ~/.bashrc_secrets
      echo "OK 환경변수 주입 완료: $key"
    else
      echo "WARN 환경변수 주입 실패: $key"
    fi
  done
fi

# ============================================================
# 파일 시크릿 복원
# ============================================================
mkdir -p ~/.ssh ~/.aws ~/.backblaze

fetch_secret_multiline "github_private_ssh_os_srzst" "/github" > ~/.ssh/id_ed25519
if [ ! -s ~/.ssh/id_ed25519 ]; then
  echo "ERROR SSH 개인키 복원 실패 → 토큰 및 키 이름 확인 후 재실행"
  exit 1
fi
chmod 600 ~/.ssh/id_ed25519
echo "OK SSH 개인키 복원 완료"

fetch_secret_multiline "config" "/aws" > ~/.aws/config
fetch_secret_multiline "credentials" "/aws" > ~/.aws/credentials
chmod 600 ~/.aws/credentials
echo "OK .aws 완료"

fetch_secret_multiline "backblazeapi" "/backblaze" > ~/.backblaze/backblazeapi
chmod 600 ~/.backblaze/backblazeapi
echo "OK .backblaze 완료"

fetch_secret_multiline "git_credentials" "/github" > ~/.git-credentials
chmod 600 ~/.git-credentials
echo "OK .git-credentials 완료"

mkdir -p ~/.config/rclone
fetch_secret_multiline "rclone_onedrive_sv" "/rclone" > ~/.config/rclone/rclone.conf
chmod 600 ~/.config/rclone/rclone.conf
echo "OK rclone.conf 복원 완료"

# ============================================================
# 시간대 설정
# ============================================================
sudo timedatectl set-timezone Asia/Seoul
echo "OK 시간대 설정 완료: Asia/Seoul"

# ============================================================
# root 계정 활성화
# ============================================================
echo "root:$ROOT_PASSWORD" | sudo chpasswd
echo "OK root 계정 활성화 완료"

# ============================================================
# Git 설정
# ============================================================
git config --global user.email "x@srzst.com"
git config --global user.name "x"
git config --global pull.rebase true
echo "OK Git 설정 완료"

# ============================================================
# 글로벌 gitignore 설정
# ============================================================
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
echo "OK 글로벌 gitignore 설정 완료"

# ============================================================
# credential helper 설정
# ============================================================
git config --global credential.helper store
echo "OK credential.helper 설정 완료"

# ============================================================
# SSH config 설정
# ============================================================
touch ~/.ssh/config
chmod 600 ~/.ssh/config
if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  User git
EOF
  echo "OK SSH config 설정 완료"
fi

# ============================================================
# GitHub known_hosts 등록
# ============================================================
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
echo "OK GitHub known_hosts 등록 완료"

# ============================================================
# GitHub SSH 연결 테스트
# ============================================================
echo ""
echo "GitHub SSH 연결 테스트 중..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "OK GitHub SSH 인증 성공" \
  || echo "WARN GitHub SSH 인증 실패 - 키 또는 GitHub 등록 확인 필요"

# ============================================================
# 저장소 clone
# ============================================================
echo ""
echo "저장소 clone 중..."
repos=(
  "git@github.com:srzst/.dotfiles.git"
  "git@github.com:srzst/.dotfolders.git"
)
for repo in "${repos[@]}"; do
  repo_name=$(basename "$repo" .git)
  if [ ! -d "$HOME/$repo_name" ]; then
    git clone "$repo" "$HOME/$repo_name"
    echo "OK $repo_name clone 완료"
  else
    git -C "$HOME/$repo_name" pull
    echo "OK $repo_name 이미 존재 (pull 완료)"
  fi
done

# ============================================================
# secrets 로드 구문 추가
# ============================================================
if ! grep -q 'bashrc_secrets' "$REPO/linux/ubuntu/Alias/.bashrc" 2>/dev/null; then
  echo '' >> "$REPO/linux/ubuntu/Alias/.bashrc"
  echo '[[ -f ~/.bashrc_secrets ]] && source ~/.bashrc_secrets' >> "$REPO/linux/ubuntu/Alias/.bashrc"
  echo "OK .bashrc에 secrets 로드 구문 추가 완료"
fi

# ============================================================
# 공통 심볼릭 링크
# ============================================================
rm -f ~/.bashrc
ln -sf "$REPO/linux/ubuntu/Alias/.bashrc" ~/.bashrc
echo "OK .bashrc 연결 완료"

rm -f ~/.vimrc
ln -sf "$REPO/common/Vim/.vimrc" ~/.vimrc
echo "OK .vimrc 연결 완료"

# ============================================================
# dev 전용 심볼릭 링크
# ============================================================
if [ "$TARGET" = "2" ]; then
  rm -rf ~/.config/nvim
  mkdir -p ~/.config
  ln -sf "$REPO/common/neovim" ~/.config/nvim
  echo "OK Neovim 연결 완료"

  rm -rf ~/.config/yazi
  ln -sf "$REPO/common/yazi" ~/.config/yazi
  echo "OK Yazi 설정 연결 완료"
fi

# ============================================================
# 글로벌 gitattributes 설정
# ============================================================
ln -sf "$REPO/.gitattributes" ~/.gitattributes_global
git config --global core.attributesFile ~/.gitattributes_global
echo "OK Git 글로벌 attributes 연결 완료"

# ============================================================
# dev 전용 바이너리 설치
# ============================================================
if [ "$TARGET" = "2" ]; then
  echo ""
  echo "Neovim 설치 중..."
  curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
  sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  rm nvim-linux-x86_64.tar.gz
  echo "OK Neovim 설치 완료"

  echo "lazygit 설치 중..."
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/')
  curl -Lo lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
  tar -xzf lazygit.tar.gz lazygit
  sudo mv lazygit /usr/local/bin/
  rm lazygit.tar.gz
  echo "OK lazygit 설치 완료"
fi

# ============================================================
# Cron 등록
# ============================================================
(crontab -l 2>/dev/null | grep -v 'dotfiles.*git pull\|dotfolders.*git pull'; \
  echo "0 */3 * * * cd $HOME/.dotfiles && git pull origin main && cd $HOME/.dotfolders && git pull origin main") | crontab -
echo "OK Cron 등록 완료 (3시간마다 pull)"

# ============================================================
# dev 전용 pip 패키지 설치
# ============================================================
if [ "$TARGET" = "2" ]; then
  echo ""
  echo "pip 패키지 설치 중..."
  pip3 install --break-system-packages \
    boto3 pillow requests mistune \
    b2sdk \
    pygments pandas tabulate \
    oauth2client gspread google-api-python-client \
    google-auth-oauthlib
  echo "OK pip 패키지 설치 완료"
fi

# ============================================================
# pipx / gita 설치
# ============================================================
pipx install gita
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"
gita add "$REPO" 2>/dev/null
gita add "$HOME/.dotfolders" 2>/dev/null
echo "OK gita 설치 및 .dotfiles/.dotfolders 등록 완료"

# ============================================================
# Tailscale 설치 및 인증
# ============================================================
echo ""
echo "Tailscale 설치 중..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "OK Tailscale 설치 완료"
tailscale_authkey=$(fetch_secret "tailscale_authkey" "/")
if [ -n "$tailscale_authkey" ]; then
  sudo tailscale up --authkey="$tailscale_authkey"
  echo "OK Tailscale 인증 완료"
else
  echo "INFO Tailscale Auth Key를 가져오지 못했습니다. 수동으로 실행하세요:"
  echo "  sudo tailscale up"
fi

# ============================================================
# GitHub Desktop 호환 - remote HTTPS 변경
# ============================================================
git -C "$REPO" remote set-url origin "https://github.com/srzst/.dotfiles.git"
echo "OK remote HTTPS 변경 완료: .dotfiles"

# ============================================================
# root 환경 동기화
# ============================================================
echo ""
echo "root 환경 동기화 중..."
sudo mkdir -p /root/.config
sudo ln -sf "$REPO/linux/ubuntu/Alias/.bashrc" /root/.bashrc
sudo ln -sf "$HOME/.bashrc_secrets" /root/.bashrc_secrets
sudo ln -sf "$REPO/common/Vim/.vimrc" /root/.vimrc
if [ "$TARGET" = "2" ]; then
  sudo ln -sf "$REPO/common/neovim" /root/.config/nvim
  sudo ln -sf "$REPO/common/yazi" /root/.config/yazi
fi
echo "OK root 환경 동기화 완료"

echo ""
echo "OK Ubuntu 설치 완료"
echo "INFO 재시작을 권장합니다: sudo reboot"