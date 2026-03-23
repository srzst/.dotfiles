#!/bin/bash
REPO="$HOME/.dotfiles"

# ============================================================
# bootstrap_ubuntu_sv.sh
# Ubuntu 서버 전용 원스탑 설치 스크립트
# curl https://dl.srz.st/u.sh | bash
# ============================================================

# ============================================================
# 버전 변수
# ============================================================
INFISICAL_PROJECT_ID="bc893247-af3f-4118-a8ec-bcb429338acb"
INFISICAL_ENV="dev"

# ============================================================
# 기본 패키지 설치 (age/Infisical 설치 전 선행)
# ============================================================
sudo apt-get update -qq
sudo apt-get install -y curl wget git apt-transport-https
echo "OK 기본 패키지 설치 완료"

# ============================================================
# 패스워드 입력 (sudo 인증용 - age/Infisical 설치에 필요)
# ============================================================
read -s -p "서버 암호: " USER_PASSWORD
echo ""
echo "$USER_PASSWORD" | sudo -S -v 2>/dev/null
echo "OK sudo 인증 완료"

SUDO_PASS_FILE=$(mktemp)
chmod 600 "$SUDO_PASS_FILE"
echo "$USER_PASSWORD" > "$SUDO_PASS_FILE"

while true; do sudo -S -v < "$SUDO_PASS_FILE" 2>/dev/null; sleep 50; done &
SUDO_KEEPALIVE_PID=$!
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null; rm -f $SUDO_PASS_FILE" EXIT

# ============================================================
# age 설치
# ============================================================
if ! command -v age &>/dev/null; then
  AGE_VERSION=$(curl -sL https://api.github.com/repos/FiloSottile/age/releases/latest | grep tag_name | cut -d'"' -f4)
  curl -sL "https://github.com/FiloSottile/age/releases/download/${AGE_VERSION}/age-${AGE_VERSION}-linux-amd64.tar.gz" | \
    sudo tar -xz -C /usr/local/bin --strip-components=1 age/age age/age-keygen
  echo "OK age 설치 완료"
fi

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
# Infisical 토큰 복호화
# ============================================================
read -s -p "패스워드: " PASS
echo ""
TMP_ENC=$(mktemp /tmp/t_XXXXXX.age)
curl -sL "https://dl.srz.st/t.age" -o "$TMP_ENC"
INFISICAL_INPUT_TOKEN=$(echo "$PASS" | age -d "$TMP_ENC" 2>/dev/null)
rm -f "$TMP_ENC"
if [ -z "$INFISICAL_INPUT_TOKEN" ]; then
  echo "ERR 토큰 복호화 실패"
  exit 1
fi
echo "export INFISICAL_TOKEN=\"$INFISICAL_INPUT_TOKEN\"" > ~/.bashrc_secrets
chmod 600 ~/.bashrc_secrets
export INFISICAL_TOKEN="$INFISICAL_INPUT_TOKEN"
echo "OK 토큰 주입 완료"

# ============================================================
# main_password 로드 (root 암호 겸용)
# ============================================================
ROOT_PASSWORD=$(INFISICAL_TOKEN="$INFISICAL_INPUT_TOKEN" infisical secrets get "main_password" \
  --projectId="$INFISICAL_PROJECT_ID" \
  --env="$INFISICAL_ENV" \
  --path="/" \
  --plain --silent 2>/dev/null | tr -d '\n')
if [ -z "$ROOT_PASSWORD" ]; then
  echo "ERR main_password 복원 실패"
  exit 1
fi
echo "OK root 암호 로드 완료"
echo "OK 입력값 확인 완료 - 설치를 시작합니다."
unset USER_PASSWORD

# ============================================================
# 시스템 업데이트
# ============================================================
echo "시스템 업데이트 중..."
sudo apt update && sudo apt upgrade -y
echo "OK 시스템 업데이트 완료"

# ============================================================
# 기본 패키지 설치
# ============================================================
echo "패키지 설치 중..."
sudo apt install -y \
  curl wget vim git htop net-tools sudo \
  python3 python3-pip pipx \
  build-essential unzip zip rclone \
  tree tmux apt-transport-https
echo "OK 패키지 설치 완료"

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# ============================================================
# Infisical CLI 설치 (재확인)
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
# Secrets 복원
# ============================================================
mkdir -p ~/.aws
fetch_secret_multiline "config" "/aws" > ~/.aws/config
fetch_secret_multiline "credentials" "/aws" > ~/.aws/credentials
chmod 600 ~/.aws/credentials
echo "OK .aws 완료"

mkdir -p ~/.backblaze
fetch_secret_multiline "backblazeapi" "/backblaze" > ~/.backblaze/backblazeapi
chmod 600 ~/.backblaze/backblazeapi
echo "OK .backblaze 완료"

fetch_secret_multiline "git_credentials" "/github" > ~/.git-credentials
chmod 600 ~/.git-credentials
echo "OK .git-credentials 완료"

mkdir -p ~/.ssh
fetch_secret_multiline "github_private_ssh_os_srzst" "/github" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
echo "OK SSH 개인키 복원 완료"

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
# 심볼릭 링크
# ============================================================
rm -f ~/.bashrc
ln -sf "$REPO/linux/ubuntu/Alias/.bashrc" ~/.bashrc
echo "OK .bashrc 연결 완료"

rm -f ~/.vimrc
ln -sf "$REPO/common/Vim/.vimrc" ~/.vimrc
echo "OK .vimrc 연결 완료"

# ============================================================
# 글로벌 gitattributes 설정
# ============================================================
ln -sf "$REPO/.gitattributes" ~/.gitattributes_global
git config --global core.attributesFile ~/.gitattributes_global
echo "OK Git 글로벌 attributes 연결 완료"

# ============================================================
# Cron 등록
# ============================================================
(crontab -l 2>/dev/null | grep -v 'dotfiles.*git pull\|dotfolders.*git pull'; \
  echo "0 */3 * * * cd $HOME/.dotfiles && git pull origin main && cd $HOME/.dotfolders && git pull origin main") | crontab -
echo "OK Cron 등록 완료 (3시간마다 pull)"

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
# pipx / gita 설치
# ============================================================
pipx install gita
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"
gita add "$REPO" 2>/dev/null
gita add "$HOME/.dotfolders" 2>/dev/null
echo "OK gita 설치 및 .dotfiles/.dotfolders 등록 완료"

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
echo "OK root 환경 동기화 완료"

echo ""
echo "OK Ubuntu 서버 설치 완료"
echo "INFO 재시작을 권장합니다: sudo reboot"