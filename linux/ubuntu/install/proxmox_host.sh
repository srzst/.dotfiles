#!/bin/bash

# ============================================================
# CONFIG
# ============================================================
MODE=2    # 1: install  2: bootstrap
TARGET=1  # 1: server  2: dev

BOOTSTRAP_TOKEN_URL="https://dl.srz.st/t.enc"
INFISICAL_PROJECT_ID="bc893247-af3f-4118-a8ec-bcb429338acb"
INFISICAL_ENV="dev"
REPO="/home/x/.dotfiles"
X_HOME="/home/x"
# ============================================================
# ============================================================
# 사전 입력 및 sudo 인증 유지
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
echo " 5) pve"
echo " 6) 직접 입력"
echo "------------------------------------------------------------"
read -p " 선택 (1-6): " HOSTNAME_CHOICE

case $HOSTNAME_CHOICE in
    1) NEW_HOSTNAME="W1" ;;
    2) NEW_HOSTNAME="W2" ;;
    3) NEW_HOSTNAME="W3" ;;
    4) NEW_HOSTNAME="W5" ;;
    5) NEW_HOSTNAME="pve" ;;
    6) read -p " hostname 입력: " NEW_HOSTNAME ;;
    *) echo "오류: 올바른 번호를 선택하세요."; exit 1 ;;
esac

sudo hostnamectl set-hostname "$NEW_HOSTNAME"
sudo sed -i "s/127.0.1.1.*/127.0.1.1 $NEW_HOSTNAME/" /etc/hosts
export HOSTNAME="$NEW_HOSTNAME"
echo "OK hostname 설정 완료: $NEW_HOSTNAME"

# ============================================================
# 기본 선행 패키지 설치
# ============================================================
sudo apt-get update -qq
sudo apt-get install -y curl wget git apt-transport-https gnupg dirmngr
echo "OK 기본 패키지 설치 완료"
# ============================================================
# 토큰 획득
# ============================================================
if [ "$MODE" = "2" ]; then
  TMP_ENC=$(mktemp /tmp/t_XXXXXX.enc)
  TMP_DEC=$(mktemp /tmp/t_XXXXXX.dec)
  
  curl -sL "$BOOTSTRAP_TOKEN_URL" -o "$TMP_ENC"
  
  # 괄호 감지 에러를 피하기 위해 파일로 먼저 온전히 복호화 추출
  openssl enc -d -aes-256-cbc -pbkdf2 -in "$TMP_ENC" -pass pass:"$SAVED_PASSWORD" -out "$TMP_DEC" 2>/dev/null
  
  # 복호화된 파일에서 널 바이트와 공백을 완전히 제거하여 변수에 주입
  INFISICAL_INPUT_TOKEN=$(tr -d '\000\r\n ' < "$TMP_DEC")
  
  rm -f "$TMP_ENC" "$TMP_DEC"
  
  if [ -z "$INFISICAL_INPUT_TOKEN" ] || [[ ! "$INFISICAL_INPUT_TOKEN" == st.* ]]; then
    echo "ERR 토큰 복호화 실패 또는 토큰 규격 불일치"
    exit 1
  fi
  echo "OK 토큰 복호화 완료"
else
  if [ -f ~/.bashrc_secrets ]; then
    source ~/.bashrc_secrets
    INFISICAL_INPUT_TOKEN="$INFISICAL_TOKEN"
    echo "OK ~/.bashrc_secrets에서 토큰 로드"
  else
    read -p "Infisical 서비스 토큰: " -r INFISICAL_INPUT_TOKEN
  fi
fi
# ============================================================
# 공통 패키지 설치
# ============================================================
echo "패키지 설치 중..."
sudo apt install -y curl wget rclone vim git htop net-tools sudo python3 python3-pip pipx
sudo apt install -y software-properties-common 2>/dev/null || true
echo "OK 공통 패키지 설치 완료"
# ============================================================
# RCLONE OFFICIAL STABLE INSTALLATION & UPGRADE
# ============================================================
# 데비안 내장 패키지 버그(OneDrive 대용량 unauthenticated) 방지를 위해 공식 빌드 강제
if ! command -v rclone &> /dev/null || [[ "$(rclone version | head -n 1 | awk '{print $2}')" < "v1.74.2" ]]; then
    curl https://rclone.org/install.sh | sudo bash -s -- --quiet
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
# root 암호 결정
# ============================================================
if [ "$MODE" = "2" ]; then
  ROOT_PASSWORD=$(INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get "main_password" \
    --projectId="$INFISICAL_PROJECT_ID" --env="$INFISICAL_ENV" --path="/" \
    --plain --silent 2>/dev/null | tr -d '\000\r\n ')
  [ -z "$ROOT_PASSWORD" ] && echo "ERR main_password 복원 실패" && exit 1
  echo "OK root 암호 로드 완료"
else
  ROOT_PASSWORD="$SAVED_PASSWORD"
fi

unset USER_PASSWORD SAVED_PASSWORD
echo "OK 입력값 확인 완료 - 설치를 시작합니다."
# ============================================================
# x 유저 생성 (Proxmox 호스트 내 일반 작업용 계정)
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
# fetch_secret 함수 정의
# ============================================================
fetch_secret() {
  local key="$1"
  local path="${2:-/}"
  INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get "$key" \
    --projectId="$INFISICAL_PROJECT_ID" \
    --env="$INFISICAL_ENV" \
    --path="$path" \
    --plain --silent 2>/dev/null | tr -d '\000\r\n '
}

fetch_secret_multiline() {
  local key="$1"
  local path="${2:-/}"
  INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get "$key" \
    --projectId="$INFISICAL_PROJECT_ID" \
    --env="$INFISICAL_ENV" \
    --path="$path" \
    --plain --silent 2>/dev/null | tr -d '\000\r'
}
# ============================================================
# 파일 시크릿 복원 (Master SSH Key & Cloud Secrets)
# ============================================================



# ============================================================
# 파일 시크릿 복원 (Master SSH Key & Cloud Secrets)
# ============================================================
mkdir -p ~/.ssh ~/.aws ~/.backblaze
chmod 700 ~/.ssh

printf "%b\n" "$(fetch_secret_multiline "main_ssh_private_key" "/")" > ~/.ssh/main_ssh_key
printf "%b\n" "$(fetch_secret_multiline "main_ssh_public_key" "/")" > ~/.ssh/main_ssh_key.pub

if [ ! -s ~/.ssh/main_ssh_key ]; then
    echo "ERROR 마스터 개인키 복원 실패 → Infisical 설정을 확인하세요."
    exit 1
fi

chmod 600 ~/.ssh/main_ssh_key
chmod 644 ~/.ssh/main_ssh_key.pub
echo "OK 마스터 SSH 키 쌍 복원 완료 (~/.ssh/main_ssh_key)"

printf "%b" "$(fetch_secret_multiline "github_private_ssh_os_srzst" "/github")" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
echo "OK GitHub SSH 키 복원 완료 (~/.ssh/id_ed25519)"

if [ -f ~/.ssh/main_ssh_key.pub ]; then
    PUB_KEY_CONTENT=$(cat ~/.ssh/main_ssh_key.pub)
    if ! grep -qF "$PUB_KEY_CONTENT" ~/.ssh/authorized_keys 2>/dev/null; then
        echo "$PUB_KEY_CONTENT" >> ~/.ssh/authorized_keys
        chmod 600 ~/.ssh/authorized_keys
        echo "OK 마스터 공개키를 authorized_keys에 등록 완료"
    fi
fi

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
fetch_secret_multiline "rclone_conf" "/rclone" > ~/.config/rclone/rclone.conf
fetch_secret_multiline "rclone_onedrive_sv_pve" "/rclone" >> ~/.config/rclone/rclone.conf
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
# root 계정 암호화 동기화
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
# SSH config 설정 및 GitHub 등록
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

ssh-keyscan -t ed25519 github.com >> ~/.ssh/known_hosts 2>/dev/null
echo "OK GitHub known_hosts 등록 완료"

echo ""
echo "GitHub SSH 연결 테스트 중..."
ssh -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "OK GitHub SSH 인증 성공" \
  || echo "WARN GitHub SSH 인증 실패 - 키 또는 GitHub 등록 확인 필요"
# ============================================================
# 저장소 clone (.dotfiles, .dotfolders)
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
if ! sudo -u x grep -q 'source ~/.bashrc_secrets' "$REPO/linux/ubuntu/Alias/.bashrc" 2>/dev/null; then
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

sudo -u x ln -sf "$REPO/.gitattributes" "$X_HOME/.gitattributes_global"
sudo -u x git config --global core.attributesFile "$X_HOME/.gitattributes_global"
echo "OK Git 글로벌 attributes 연결 완료"
# ============================================================
# Cron 등록 (3시간 주기로 변경사항 pull 동기화)
# ============================================================
(sudo -u x crontab -l 2>/dev/null | grep -v 'dotfiles.*git\|dotfolders.*git'; \
  echo "0 */3 * * * cd $X_HOME/.dotfiles && git fetch origin && git reset --hard origin/main && cd $X_HOME/.dotfolders && git fetch origin && git reset --hard origin/main") | sudo -u x crontab -
echo "OK Cron 등록 완료 (3시간마다 fetch+reset)"
# ============================================================
# pipx / gita 설치 및 자산 관리 등록
# ============================================================
sudo -u x pipx install gita
sudo -u x pipx ensurepath
sudo -u x bash -c "PATH=\"$X_HOME/.local/bin:/usr/local/bin:\$PATH\" gita add $X_HOME/.dotfiles" 2>/dev/null
sudo -u x bash -c "PATH=\"$X_HOME/.local/bin:/usr/local/bin:\$PATH\" gita add $X_HOME/.dotfolders" 2>/dev/null
echo "OK gita 설치 및 .dotfiles/.dotfolders 등록 완료"
# ============================================================
# Tailscale 설치 및 인프라 메쉬 네트워크 인증
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
# GitHub Desktop 호환 - remote HTTPS 최적화 유지
# ============================================================
sudo -u x git -C "$REPO" remote set-url origin "https://github.com/srzst/.dotfiles.git"
echo "OK remote HTTPS 변경 완료: .dotfiles"
# ============================================================
# root 계정 환경 심볼릭 동기화 
# ============================================================
echo ""
echo "root 환경 동기화 중..."
sudo mkdir -p /root/.config
sudo ln -sf "$REPO/linux/ubuntu/Alias/.bashrc" /root/.bashrc
sudo ln -sf "$X_HOME/.bashrc_secrets" /root/.bashrc_secrets
sudo ln -sf "$REPO/common/Vim/.vimrc" /root/.vimrc
echo "OK root 환경 동기화 완료"


echo ""
echo "OK Proxmox 호스트 전용 부트스트랩 완료"
echo "INFO 시스템 재시작을 권장합니다: sudo reboot"