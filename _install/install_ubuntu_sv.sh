#!/bin/bash
REPO="$HOME/.dotfiles"

# ============================================================
# install_ubuntu_server.sh
# Ubuntu 서버 전용 경량 설치 스크립트
# 사용자: x / 암호: (Bitwarden 참고)
# root 계정 활성화 동일 암호
# ============================================================

# ============================================================
# 버전 변수 (업데이트 시 여기만 수정)
# ※ 버전 확인: https://github.com/bitwarden/sdk-sm/releases
# ============================================================
BWS_VERSION="2.0.0"
BWS_URL_LINUX="https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-x86_64-unknown-linux-gnu-${BWS_VERSION}.zip"

# ============================================================
# 사전 입력 (스크립트 실행 전 모든 입력값 수집)
# ============================================================

# 1. BWS 액세스 토큰
if [ ! -f ~/.bashrc_secrets ]; then
  echo "BWS 액세스 토큰을 입력하세요 (입력 후 Enter):"
  read -r BWS_INPUT_TOKEN
  echo "export BWS_ACCESS_TOKEN=\"$BWS_INPUT_TOKEN\"" > ~/.bashrc_secrets
  chmod 600 ~/.bashrc_secrets
  echo "OK ~/.bashrc_secrets 생성 완료"
else
  echo "OK ~/.bashrc_secrets 이미 존재 (스킵)"
fi
source ~/.bashrc_secrets
echo "OK BWS 토큰 로드 완료"

# 2. 유저 암호 (sudo 인증용)
echo ""
echo "현재 사용자($USER) 암호를 입력하세요 (sudo 인증용):"
read -rs USER_PASSWORD
echo ""

# 3. root 암호
echo "설정할 root 암호를 입력하세요 (사용자 암호와 동일하게):"
read -rs ROOT_PASSWORD
echo ""
echo "root 암호 확인:"
read -rs ROOT_PASSWORD_CONFIRM
echo ""
if [ "$ROOT_PASSWORD" != "$ROOT_PASSWORD_CONFIRM" ]; then
  echo "ERROR 암호가 일치하지 않습니다. 스크립트를 종료합니다."
  exit 1
fi
echo "OK 입력값 확인 완료 - 설치를 시작합니다."
echo ""

# sudo 인증 캐시 (이후 자동 설치 중 sudo 재입력 방지)
echo "$USER_PASSWORD" | sudo -S -v 2>/dev/null
echo "OK sudo 인증 완료"

# sudo 세션 keepalive (50초마다 갱신 - 설치 완료까지 유지)
while true; do echo "$USER_PASSWORD" | sudo -S -v 2>/dev/null; sleep 50; done &
SUDO_KEEPALIVE_PID=$!
trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null" EXIT

# ============================================================
# 이하 자동 설치 (입력 없이 진행)
# ============================================================

# 시스템 업데이트 (기본 미러 사용)
echo "시스템 업데이트 중..."
sudo apt update && sudo apt upgrade -y
echo "OK 시스템 업데이트 완료"

# 기본 패키지 설치
echo "패키지 설치 중..."
sudo apt install -y \
  curl wget vim git htop net-tools sudo \
  python3 python3-pip \
  build-essential unzip zip \
  tree tmux
echo "OK 패키지 설치 완료"

# FIX: bws CLI 이미 설치된 경우 스킵
BWS_BIN="$HOME/bws/bws"
if [ ! -f "$BWS_BIN" ]; then
  echo "bws CLI 설치 중..."
  mkdir -p ~/bws
  curl -L -o ~/bws/bws.zip "$BWS_URL_LINUX"
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

# BWS secrets 복원
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

# SSH 개인키 복원 (github_private_ssh_os_srzst)
mkdir -p ~/.ssh
fetch_secret "1eb6113c-83a3-4500-8d6c-b401000f48e3" > ~/.ssh/id_ed25519
chmod 600 ~/.ssh/id_ed25519
echo "OK SSH 개인키 복원 완료"

# 시간대 설정 (Asia/Seoul 고정)
sudo timedatectl set-timezone Asia/Seoul
echo "OK 시간대 설정 완료: Asia/Seoul"

# root 계정 활성화 (사전 입력값 적용)
echo "root:$ROOT_PASSWORD" | sudo chpasswd
echo "OK root 계정 활성화 완료"

# FIX: secrets 로드 구문을 repo 파일에 먼저 추가한 후 symlink 생성
if ! grep -q 'bashrc_secrets' "$REPO/Alias/ubuntu/.bashrc" 2>/dev/null; then
  echo '' >> "$REPO/Alias/ubuntu/.bashrc"
  echo '[[ -f ~/.bashrc_secrets ]] && source ~/.bashrc_secrets' >> "$REPO/Alias/ubuntu/.bashrc"
  echo "OK .bashrc에 secrets 로드 구문 추가 완료"
fi

# .bashrc symlink
rm -f ~/.bashrc
ln -sf "$REPO/Alias/ubuntu/.bashrc" ~/.bashrc
echo "OK .bashrc 연결 완료"

rm -f ~/.vimrc
ln -sf "$REPO/Vim/.vimrc" ~/.vimrc
echo "OK .vimrc 연결 완료"

# Git 설정
git config --global user.email "x@srzst.com"
git config --global user.name "x"
git config --global pull.rebase true 
echo "OK Git 설정 완료"

# 글로벌 gitignore 설정
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
echo "OK 글로벌 gitignore 설정 완료"

# git-credentials 사용을 위한 credential helper 설정
git config --global credential.helper store
echo "OK credential.helper 설정 완료"

# SSH config 설정
if ! grep -q "Host github.com" ~/.ssh/config 2>/dev/null; then
  cat >> ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/id_ed25519
  User git
EOF
  chmod 600 ~/.ssh/config
  echo "OK SSH config 설정 완료"
fi

# FIX: 신규 설치 환경에서 known_hosts 없으면 프롬프트로 블로킹되는 문제 방지
echo ""
echo "GitHub SSH 연결 테스트 중..."
ssh -o StrictHostKeyChecking=accept-new -T git@github.com 2>&1 | grep -q "successfully authenticated" \
  && echo "OK GitHub SSH 인증 성공" \
  || echo "WARN GitHub SSH 인증 실패 - BWS 키 또는 GitHub 등록 확인 필요"

# 저장소 clone (SSH - private repo)
echo ""
echo "저장소 clone 중..."
repos=(
  "git@github.com:srzst/ubuntusv.git"
)
for repo in "${repos[@]}"; do
  repo_name=$(basename "$repo" .git)
  if [ ! -d "$HOME/$repo_name" ]; then
    git clone "$repo" "$HOME/$repo_name"
    echo "OK $repo_name clone 완료"
  else
    echo "OK $repo_name 이미 존재 (스킵)"
  fi
done

# Cron 등록 (6시간마다 pull)
(crontab -l 2>/dev/null; echo "0 */6 * * * cd $HOME/.dotfiles && git pull origin main") | crontab -
echo "OK Cron 등록 완료 (6시간마다 pull)"

# Tailscale 설치 및 인증
echo ""
echo "Tailscale 설치 중..."
curl -fsSL https://tailscale.com/install.sh | sh
echo "OK Tailscale 설치 완료"
tailscale_authkey=$(fetch_secret "9e0c6e68-1a40-4ede-8707-b401002a964f")
if [ -n "$tailscale_authkey" ]; then
  sudo tailscale up --authkey="$tailscale_authkey"
  echo "OK Tailscale 인증 완료"
else
  echo "INFO Tailscale Auth Key를 가져오지 못했습니다. 수동으로 실행하세요:"
  echo "  sudo tailscale up"
fi

# FIX: .dotfiles remote를 HTTPS로 통일 (GitHub Desktop 호환)
if [ -d "$REPO" ]; then
  git -C "$REPO" remote set-url origin "https://github.com/srzst/.dotfiles.git"
  echo "OK remote HTTPS 변경: .dotfiles"
fi
echo "OK remote URL HTTPS로 변경 완료"

# root 환경 동기화 (x 계정과 동일한 환경)
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