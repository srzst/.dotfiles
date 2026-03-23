#!/bin/bash
REPO="$HOME/.dotfiles"

# ============================================================
# install_ubuntu_sv.sh
# Ubuntu 서버 전용 경량 설치 스크립트
# 사용자: x / 암호: (Bitwarden 참고)
# root 계정 활성화 동일 암호
# ============================================================

# ============================================================
# 버전 변수
# ============================================================
INFISICAL_PROJECT_ID="bc893247-af3f-4118-a8ec-bcb429338acb"
INFISICAL_ENV="dev"

# ============================================================
# 사전 입력 (스크립트 실행 전 모든 입력값 수집)
# ============================================================


# 1. Infisical 서비스 토큰
if [ ! -f ~/.bashrc_secrets ]; then
  # echo "토큰 URL을 입력하세요:"
  # read -r TOKEN_URL
  # INFISICAL_INPUT_TOKEN=$(curl -fsSL "$TOKEN_URL")
  # echo "export INFISICAL_TOKEN=\"$INFISICAL_INPUT_TOKEN\"" > ~/.bashrc_secrets
  # chmod 600 ~/.bashrc_secrets
  #----
  echo "Infisical 서비스 토큰을 입력하세요 (입력 후 Enter):"
  read -r INFISICAL_INPUT_TOKEN
  echo "export INFISICAL_TOKEN=\"$INFISICAL_INPUT_TOKEN\"" > ~/.bashrc_secrets
  chmod 600 ~/.bashrc_secrets
  echo "OK ~/.bashrc_secrets 생성 완료"
else
  echo "OK ~/.bashrc_secrets 이미 존재 (스킵)"
fi
source ~/.bashrc_secrets
echo "OK Infisical 토큰 로드 완료"

# 2. 유저 암호 (sudo 인증 + root 암호 겸용)
echo ""
echo "현재 사용자($USER) 암호를 입력하세요 (sudo 인증 + root 암호 겸용):"
read -rs USER_PASSWORD
echo ""
ROOT_PASSWORD="$USER_PASSWORD"
echo "OK 입력값 확인 완료 - 설치를 시작합니다."

# sudo 인증 캐시
echo "$USER_PASSWORD" | sudo -S -v 2>/dev/null
echo "OK sudo 인증 완료"

SUDO_PASS_FILE=$(mktemp)
chmod 600 "$SUDO_PASS_FILE"
echo "$USER_PASSWORD" > "$SUDO_PASS_FILE"
unset USER_PASSWORD

while true; do sudo -S -v < "$SUDO_PASS_FILE" 2>/dev/null; sleep 50; done &
SUDO_KEEPALIVE_PID=$!
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null; rm -f $SUDO_PASS_FILE" EXIT

# ============================================================
# 이하 자동 설치 (입력 없이 진행)
# ============================================================
# 시스템 업데이트
echo "시스템 업데이트 중..."
sudo apt update && sudo apt upgrade -y
echo "OK 시스템 업데이트 완료"

# 기본 패키지 설치
echo "패키지 설치 중..."
sudo apt install -y \
  curl wget vim git htop net-tools sudo \
  python3 python3-pip pipx \
  build-essential unzip zip rclone \
  tree tmux
echo "OK 패키지 설치 완료"

# # PowerShell 7+ 설치
# echo "PowerShell 설치 중..."
# curl -sSL https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -
# curl -sSL https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/prod.list \
#   | sudo tee /etc/apt/sources.list.d/microsoft-prod.list
# sudo apt update
# sudo apt install -y powershell
# echo "OK PowerShell 설치 완료"

export PATH="$HOME/.local/bin:/usr/local/bin:$PATH"

# Infisical CLI 설치
if ! command -v infisical &>/dev/null; then
  echo "Infisical CLI 설치 중..."
  curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo bash
  sudo apt install -y infisical
  echo "OK Infisical CLI 설치 완료"
else
  echo "OK Infisical CLI 이미 설치됨 (스킵)"
fi

# Infisical secrets 복원 함수
fetch_secret() {
  local key="$1"
  local path="${2:-/}"
  INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get "$key" \
    --projectId="$INFISICAL_PROJECT_ID" \
    --env="$INFISICAL_ENV" \
    --path="$path" \
    --plain --silent 2>/dev/null | tr -d '\n'
}

# secrets 복원
mkdir -p ~/.aws
fetch_secret "config" "/aws" > ~/.aws/config
fetch_secret "credentials" "/aws" > ~/.aws/credentials
chmod 600 ~/.aws/credentials
echo "OK .aws 완료"

mkdir -p ~/.backblaze
fetch_secret "backblazeapi" "/backblaze" > ~/.backblaze/backblazeapi
chmod 600 ~/.backblaze/backblazeapi
echo "OK .backblaze 완료"

fetch_secret "git_credentials" "/github" > ~/.git-credentials
chmod 600 ~/.git-credentials
echo "OK .git-credentials 완료"

mkdir -p ~/.ssh
fetch_secret "github_private_ssh_os_srzst" "/github" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
echo "OK SSH 개인키 복원 완료"

mkdir -p ~/.config/rclone
fetch_secret "rclone_onedrive_sv" "/rclone" > ~/.config/rclone/rclone.conf
chmod 600 ~/.config/rclone/rclone.conf
echo "OK rclone.conf 복원 완료"

# 시간대 설정
sudo timedatectl set-timezone Asia/Seoul
echo "OK 시간대 설정 완료: Asia/Seoul"

# root 계정 활성화
echo "root:$ROOT_PASSWORD" | sudo chpasswd
echo "OK root 계정 활성화 완료"

# Git 설정
git config --global user.email "x@srzst.com"
git config --global user.name "x"
git config --global pull.rebase true
echo "OK Git 설정 완료"

# 글로벌 gitignore 설정
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
echo "OK 글로벌 gitignore 설정 완료"

# git-credentials credential helper 설정
git config --global credential.helper store
echo "OK credential.helper 설정 완료"

# SSH config 설정
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

# GitHub known_hosts 등록
ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
echo "OK GitHub known_hosts 등록 완료"

# GitHub SSH 연결 테스트
echo ""
echo "GitHub SSH 연결 테스트 중..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "OK GitHub SSH 인증 성공" \
  || echo "WARN GitHub SSH 인증 실패 - 키 또는 GitHub 등록 확인 필요"

# 저장소 clone
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

# .bashrc_secrets 로드 구문 추가
if ! grep -q 'bashrc_secrets' "$REPO/Alias/ubuntu/.bashrc" 2>/dev/null; then
  echo '' >> "$REPO/Alias/ubuntu/.bashrc"
  echo '[[ -f ~/.bashrc_secrets ]] && source ~/.bashrc_secrets' >> "$REPO/Alias/ubuntu/.bashrc"
  echo "OK .bashrc에 secrets 로드 구문 추가 완료"
fi

# symlink
rm -f ~/.bashrc
ln -sf "$REPO/Alias/ubuntu/.bashrc" ~/.bashrc
echo "OK .bashrc 연결 완료"

rm -f ~/.vimrc
ln -sf "$REPO/Vim/.vimrc" ~/.vimrc
echo "OK .vimrc 연결 완료"

# 글로벌 gitattributes 설정
ln -sf "$REPO/.gitattributes" ~/.gitattributes_global
git config --global core.attributesFile ~/.gitattributes_global
echo "OK Git 글로벌 attributes 연결 완료"

# Cron 등록
(crontab -l 2>/dev/null | grep -v 'dotfiles.*git pull\|dotfolders.*git pull'; \
  echo "0 */3 * * * cd $HOME/.dotfiles && git pull origin main && cd $HOME/.dotfolders && git pull origin main") | crontab -
echo "OK Cron 등록 완료 (3시간마다 pull)"

# Tailscale 설치 및 인증
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

# pipx / gita 설치
pipx install gita
pipx ensurepath
export PATH="$HOME/.local/bin:$PATH"
gita add "$REPO" 2>/dev/null
gita add "$HOME/.dotfolders" 2>/dev/null
echo "OK gita 설치 및 .dotfiles/.dotfolders 등록 완료"

# .dotfiles remote HTTPS 변경
git -C "$REPO" remote set-url origin "https://github.com/srzst/.dotfiles.git"
echo "OK remote HTTPS 변경 완료: .dotfiles"

# root 환경 동기화
echo ""
echo "root 환경 동기화 중..."
sudo mkdir -p /root/.config
sudo ln -sf "$REPO/Alias/ubuntu/.bashrc" /root/.bashrc
sudo ln -sf "$HOME/.bashrc_secrets" /root/.bashrc_secrets
sudo ln -sf "$REPO/Vim/.vimrc" /root/.vimrc
echo "OK root 환경 동기화 완료"

echo ""
echo "OK Ubuntu 서버 설치 완료"
echo "INFO 재시작을 권장합니다: sudo reboot"