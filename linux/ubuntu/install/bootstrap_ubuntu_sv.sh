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
REPO="/home/x/.dotfiles"
X_HOME="/home/x"
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
  tree tmux apt-transport-https software-properties-common
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
# x 유저 생성 (클라우드 환경 대응)
# ============================================================
if ! id -u x &>/dev/null; then
    sudo useradd -m -s /bin/bash x
    echo "x:$ROOT_PASSWORD" | sudo chpasswd
    sudo usermod -aG sudo x
    echo "x ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/x > /dev/null
    sudo chmod 0440 /etc/sudoers.d/x
    echo "OK x 유저 생성 완료"
else
    echo "OK x 유저 이미 존재 (스킵)"
fi
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
  # 여기서 raw 값을 그대로 가져옵니다.
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
# 파일 시크릿 복원 (Master SSH Key & Cloud Secrets)
# ============================================================
mkdir -p ~/.ssh ~/.aws ~/.backblaze
chmod 700 ~/.ssh

# 1. 범용 마스터 키 로드 (printf %b로 \n 문자열 대응)
printf "%b" "$(fetch_secret_multiline "main_ssh_private_key" "/")" > ~/.ssh/main_ssh_key
printf "%b" "$(fetch_secret_multiline "main_ssh_public_key" "/")" > ~/.ssh/main_ssh_key.pub

if [ ! -s ~/.ssh/main_ssh_key ]; then
    echo "ERROR 마스터 개인키 복원 실패 → Infisical 설정을 확인하세요."
    exit 1
fi

chmod 600 ~/.ssh/main_ssh_key
chmod 644 ~/.ssh/main_ssh_key.pub
echo "OK 마스터 SSH 키 쌍 복원 완료 (~/.ssh/main_ssh_key)"

# GitHub SSH 키 복원
printf "%b" "$(fetch_secret_multiline "github_private_ssh_os_srzst" "/github")" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
echo "OK GitHub SSH 키 복원 완료 (~/.ssh/id_ed25519)"

# 2. Self-Trust 설정 (이 서버에 대한 마스터 키 접속 허용)
if [ -f ~/.ssh/main_ssh_key.pub ]; then
    PUB_KEY_CONTENT=$(cat ~/.ssh/main_ssh_key.pub)
    if ! grep -qF "$PUB_KEY_CONTENT" ~/.ssh/authorized_keys 2>/dev/null; then
        echo "$PUB_KEY_CONTENT" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo "OK 마스터 공개키를 authorized_keys에 등록 완료"
    fi
fi

# 3. SSH Config 설정 (마스터 키 우선순위 및 깃허브 분리)
touch ~/.ssh/config
chmod 600 ~/.ssh/config
if ! grep -q "main_ssh_key" ~/.ssh/config 2>/dev/null; then
    cat >> ~/.ssh/config << 'EOF'

# Master Infrastructure Management Key
Host *
    IdentityFile ~/.ssh/main_ssh_key
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no
EOF
    echo "OK SSH Config 마스터 키 등록 완료"
fi

# 4. 기타 클라우드 시크릿 복원 (기존 방식에 printf %b만 추가하여 안전성 확보)
printf "%b" "$(fetch_secret_multiline "config" "/aws")" > ~/.aws/config
printf "%b" "$(fetch_secret_multiline "credentials" "/aws")" > ~/.aws/credentials
chmod 600 ~/.aws/credentials
echo "OK .aws 완료"

printf "%b" "$(fetch_secret_multiline "backblazeapi" "/backblaze")" > ~/.backblaze/backblazeapi
chmod 600 ~/.backblaze/backblazeapi
echo "OK .backblaze 완료"

printf "%b" "$(fetch_secret_multiline "git_credentials" "/github")" > ~/.git-credentials
chmod 600 ~/.git-credentials
echo "OK .git-credentials 완료"


mkdir -p ~/.config/rclone
printf "%b" "$(fetch_secret_multiline "rclone_conf" "/rclone")" > ~/.config/rclone/rclone.conf
printf "%b" "$(fetch_secret_multiline "rclone_onedrive_sv_pve" "/rclone")" >> ~/.config/rclone/rclone.conf
chmod 600 ~/.config/rclone/rclone.conf
echo "OK rclone.conf 복원 완료"

# ============================================================
# x 유저 환경 설정 (시크릿 파일 복사 + SSH 설정)
# ============================================================
sudo mkdir -p "$X_HOME/.ssh" "$X_HOME/.aws" "$X_HOME/.backblaze" "$X_HOME/.config/rclone"
sudo chmod 700 "$X_HOME/.ssh"

sudo cp ~/.ssh/main_ssh_key "$X_HOME/.ssh/main_ssh_key"
sudo cp ~/.ssh/main_ssh_key.pub "$X_HOME/.ssh/main_ssh_key.pub"
sudo chmod 600 "$X_HOME/.ssh/main_ssh_key"
sudo chmod 644 "$X_HOME/.ssh/main_ssh_key.pub"
sudo cp ~/.ssh/id_ed25519 "$X_HOME/.ssh/id_ed25519"
sudo chmod 600 "$X_HOME/.ssh/id_ed25519"

# 현재 유저 authorized_keys + main_ssh_key 모두 x 유저에게 부여
cat ~/.ssh/authorized_keys 2>/dev/null | sudo tee "$X_HOME/.ssh/authorized_keys" > /dev/null
PUB_KEY_CONTENT=$(cat ~/.ssh/main_ssh_key.pub)
if ! sudo grep -qF "$PUB_KEY_CONTENT" "$X_HOME/.ssh/authorized_keys" 2>/dev/null; then
    echo "$PUB_KEY_CONTENT" | sudo tee -a "$X_HOME/.ssh/authorized_keys" > /dev/null
fi
sudo chmod 600 "$X_HOME/.ssh/authorized_keys"

sudo tee "$X_HOME/.ssh/config" > /dev/null << 'EOF'
Host *
    IdentityFile ~/.ssh/main_ssh_key
    IdentityFile ~/.ssh/id_ed25519
    StrictHostKeyChecking no

Host github.com
    IdentityFile ~/.ssh/id_ed25519
    User git
EOF
sudo chmod 600 "$X_HOME/.ssh/config"

sudo cp ~/.git-credentials "$X_HOME/.git-credentials"
sudo chmod 600 "$X_HOME/.git-credentials"
sudo cp ~/.aws/config "$X_HOME/.aws/config" 2>/dev/null || true
sudo cp ~/.aws/credentials "$X_HOME/.aws/credentials" 2>/dev/null || true
sudo chmod 600 "$X_HOME/.aws/credentials" 2>/dev/null || true
sudo cp ~/.backblaze/backblazeapi "$X_HOME/.backblaze/backblazeapi" 2>/dev/null || true
sudo chmod 600 "$X_HOME/.backblaze/backblazeapi" 2>/dev/null || true
sudo cp ~/.config/rclone/rclone.conf "$X_HOME/.config/rclone/rclone.conf"
sudo chmod 600 "$X_HOME/.config/rclone/rclone.conf"
sudo cp ~/.bashrc_secrets "$X_HOME/.bashrc_secrets"
sudo chmod 600 "$X_HOME/.bashrc_secrets"
sudo chown -R x:x "$X_HOME/.ssh" "$X_HOME/.aws" "$X_HOME/.backblaze" "$X_HOME/.config" "$X_HOME/.git-credentials" "$X_HOME/.bashrc_secrets"
echo "OK x 유저 환경 설정 완료"

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
# Git 설정 (현재 유저 + x 유저)
# ============================================================
git config --global user.email "x@srzst.com"
git config --global user.name "x"
git config --global pull.rebase true
git config --global credential.helper store
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
echo "OK Git 설정 완료"

sudo -u x git config --global user.email "x@srzst.com"
sudo -u x git config --global user.name "x"
sudo -u x git config --global pull.rebase true
sudo -u x git config --global credential.helper store
sudo -u x git config --global core.excludesfile "$X_HOME/.gitignore_global"
sudo -u x bash -c "grep -qxF '*_secrets*' $X_HOME/.gitignore_global 2>/dev/null || echo '*_secrets*' >> $X_HOME/.gitignore_global"
echo "OK x 유저 Git 설정 완료"

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
  "https://github.com/srzst/.dotfiles.git"
  "https://github.com/srzst/.dotfolders.git"
)
for repo in "${repos[@]}"; do
  repo_name=$(basename "$repo" .git)
  if [ ! -d "$X_HOME/$repo_name" ]; then
    sudo -u x git clone "$repo" "$X_HOME/$repo_name"
    echo "OK $repo_name clone 완료"
  else
    sudo -u x git -C "$X_HOME/$repo_name" pull
    echo "OK $repo_name 이미 존재 (pull 완료)"
  fi
done

# ============================================================
# secrets 로드 구문 추가
# ============================================================
if ! sudo -u x grep -q 'bashrc_secrets' "$REPO/linux/ubuntu/Alias/.bashrc" 2>/dev/null; then
  sudo -u x bash -c "echo '' >> '$REPO/linux/ubuntu/Alias/.bashrc'"
  sudo -u x bash -c "echo '[[ -f ~/.bashrc_secrets ]] && source ~/.bashrc_secrets' >> '$REPO/linux/ubuntu/Alias/.bashrc'"
  echo "OK .bashrc에 secrets 로드 구문 추가 완료"
fi

# ============================================================
# 공통 심볼릭 링크 (x 유저)
# ============================================================
sudo -u x rm -f "$X_HOME/.bashrc"
sudo -u x ln -sf "$REPO/linux/ubuntu/Alias/.bashrc" "$X_HOME/.bashrc"
echo "OK .bashrc 연결 완료 (x)"

sudo -u x rm -f "$X_HOME/.vimrc"
sudo -u x ln -sf "$REPO/common/Vim/.vimrc" "$X_HOME/.vimrc"
echo "OK .vimrc 연결 완료 (x)"

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
sudo -u x ln -sf "$REPO/.gitattributes" "$X_HOME/.gitattributes_global"
sudo -u x git config --global core.attributesFile "$X_HOME/.gitattributes_global"
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
(sudo -u x crontab -l 2>/dev/null | grep -v 'dotfiles.*git pull\|dotfolders.*git pull'; \
  echo "0 */3 * * * cd $X_HOME/.dotfiles && git pull origin main && cd $X_HOME/.dotfolders && git pull origin main") | sudo -u x crontab -
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
sudo -u x pipx install gita
sudo -u x pipx ensurepath
sudo -u x bash -c "PATH=\"$X_HOME/.local/bin:/usr/local/bin:\$PATH\" gita add $X_HOME/.dotfiles" 2>/dev/null
sudo -u x bash -c "PATH=\"$X_HOME/.local/bin:/usr/local/bin:\$PATH\" gita add $X_HOME/.dotfolders" 2>/dev/null
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
sudo -u x git -C "$REPO" remote set-url origin "https://github.com/srzst/.dotfiles.git"
echo "OK remote HTTPS 변경 완료: .dotfiles"

# ============================================================
# root 환경 동기화
# ============================================================
echo ""
echo "root 환경 동기화 중..."
sudo mkdir -p /root/.config
sudo ln -sf "$REPO/linux/ubuntu/Alias/.bashrc" /root/.bashrc
sudo ln -sf "$X_HOME/.bashrc_secrets" /root/.bashrc_secrets
sudo ln -sf "$REPO/common/Vim/.vimrc" /root/.vimrc
if [ "$TARGET" = "2" ]; then
  sudo ln -sf "$REPO/common/neovim" /root/.config/nvim
  sudo ln -sf "$REPO/common/yazi" /root/.config/yazi
fi
echo "OK root 환경 동기화 완료"

echo ""
echo "OK Ubuntu 설치 완료"
echo "INFO 재시작을 권장합니다: sudo reboot"
