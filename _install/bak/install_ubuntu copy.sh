#!/bin/bash
REPO="$HOME/.dotfiles"
# .bashrc
rm -f ~/.bashrc
ln -sf "$REPO/Alias/ubuntu/.bashrc" ~/.bashrc
echo "OK .bashrc 연결 완료"
# .vimrc
rm -f ~/.vimrc
ln -sf "$REPO/Vim/.vim.rc" ~/.vimrc
echo "OK .vimrc 연결 완료"
# Neovim
rm -rf ~/.config/nvim
mkdir -p ~/.config
ln -sf "$REPO/neovim" ~/.config/nvim
echo "OK Neovim 연결 완료"
# Git 설정
echo ""
echo "Git 사용자 정보를 입력하세요:"
read -p "이메일: " git_email
read -p "이름: " git_name
git config --global user.email "$git_email"
git config --global user.name "$git_name"
echo "OK Git 설정 완료"
# SSH 키 생성
echo ""
echo "GitHub SSH 키를 생성합니다:"
ssh-keygen -t ed25519 -C "ubuntu-server" -f ~/.ssh/github_ed25519 -N ""
cat >> ~/.ssh/config << 'EOF'
Host github.com
  IdentityFile ~/.ssh/github_ed25519
  User git
EOF
echo "OK SSH 키 생성 완료"
echo ""
echo "아래 공개키를 GitHub Settings > SSH keys 에 등록하세요:"
echo "------------------------------------------------------------"
cat ~/.ssh/github_ed25519.pub
echo "------------------------------------------------------------"
echo ""
read -p "GitHub에 등록 완료 후 Enter 키를 누르세요..."
# remote URL을 SSH로 변경
cd "$REPO"
git remote set-url origin git@github.com:srzst/.dotfiles.git
echo "OK remote URL SSH로 변경 완료"
# Cron 등록
(crontab -l 2>/dev/null; echo "0 */6 * * * cd $HOME/.dotfiles && git pull origin main") | crontab -
echo "OK Cron 등록 완료 (6시간마다 pull)"
# BWS 액세스 토큰 (secrets)
if [ ! -f ~/.bashrc_secrets ]; then
  echo ""
  echo "BWS 액세스 토큰을 입력하세요 (입력 후 Enter):"
  read -r bws_token
  echo "export BWS_ACCESS_TOKEN=\"$bws_token\"" > ~/.bashrc_secrets
  chmod 600 ~/.bashrc_secrets
  echo "OK ~/.bashrc_secrets 생성 완료"
else
  echo "OK ~/.bashrc_secrets 이미 존재 (스킵)"
fi
# 글로벌 gitignore 설정
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
grep -qxF '.pwsh_secrets*' ~/.gitignore_global 2>/dev/null || echo '.pwsh_secrets*' >> ~/.gitignore_global
echo "OK 글로벌 gitignore 설정 완료"
# .bashrc_secrets 로드 구문이 없으면 .bashrc에 추가
if ! grep -q 'bashrc_secrets' ~/.bashrc 2>/dev/null; then
  echo '[[ -f ~/.bashrc_secrets ]] && source ~/.bashrc_secrets' >> ~/.bashrc
  echo "OK .bashrc에 secrets 로드 구문 추가 완료"
fi
source ~/.bashrc
echo ""
echo "OK Ubuntu 설치 완료"