#!/bin/bash
REPO="$HOME/.dotfiles"
# .zshrc
rm -f ~/.zshrc
ln -sf "$REPO/Alias/macOS/.zsh.rc" ~/.zshrc
echo "OK .zshrc 연결 완료"
# .vimrc
rm -f ~/.vimrc
ln -sf "$REPO/Vim/.vim.rc" ~/.vimrc
echo "OK .vimrc 연결 완료"
# Neovim
rm -rf ~/.config/nvim
mkdir -p ~/.config
ln -sf "$REPO/neovim" ~/.config/nvim
echo "OK Neovim 연결 완료"
# VSCode keybindings
mkdir -p "$HOME/Library/Application Support/Code/User"
ln -sf "$REPO/vscode/keybindings.json" \
  "$HOME/Library/Application Support/Code/User/keybindings.json"
echo "OK VSCode keybindings 연결 완료"
# Cursor keybindings
mkdir -p "$HOME/Library/Application Support/Cursor/User"
ln -sf "$REPO/vscode/keybindings.json" \
  "$HOME/Library/Application Support/Cursor/User/keybindings.json"
echo "OK Cursor keybindings 연결 완료"
# Zed
mkdir -p ~/.config/zed
ln -sf "$REPO/zed/settings.json" ~/.config/zed/settings.json
echo "OK Zed 설정 연결 완료"
# BWS 액세스 토큰 (secrets)
if [ ! -f ~/.zshrc_secrets ]; then
  echo ""
  echo "BWS 액세스 토큰을 입력하세요 (입력 후 Enter):"
  read -r bws_token
  echo "export BWS_ACCESS_TOKEN=\"$bws_token\"" > ~/.zshrc_secrets
  chmod 600 ~/.zshrc_secrets
  echo "OK ~/.zshrc_secrets 생성 완료"
else
  echo "OK ~/.zshrc_secrets 이미 존재 (스킵)"
fi
# 글로벌 gitignore 설정
git config --global core.excludesfile ~/.gitignore_global
grep -qxF '*_secrets*' ~/.gitignore_global 2>/dev/null || echo '*_secrets*' >> ~/.gitignore_global
grep -qxF '.pwsh_secrets*' ~/.gitignore_global 2>/dev/null || echo '.pwsh_secrets*' >> ~/.gitignore_global
echo "OK 글로벌 gitignore 설정 완료"
# .zshrc_secrets 로드 구문이 없으면 .zshrc에 추가
if ! grep -q 'zshrc_secrets' ~/.zshrc 2>/dev/null; then
  echo '[[ -f ~/.zshrc_secrets ]] && source ~/.zshrc_secrets' >> ~/.zshrc
  echo "OK .zshrc에 secrets 로드 구문 추가 완료"
fi
source ~/.zshrc
# BWS secrets 복원
BWS_BIN="$HOME/bws/bws"
fetch_secret() {
  "$BWS_BIN" secret get "$1" 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['value'])"
}
# .aws
mkdir -p ~/.aws
fetch_secret "95831a03-5ddd-46de-ac7c-b40000d57326" > ~/.aws/config
fetch_secret "96f60cf0-88f7-474d-9336-b40000d54799" > ~/.aws/credentials
chmod 600 ~/.aws/credentials
echo "OK .aws 완료"
# .backblaze
mkdir -p ~/.backblaze
fetch_secret "fd5852f6-8474-4fac-9888-b40000d8ea90" > ~/.backblaze/backblazeapi
chmod 600 ~/.backblaze/backblazeapi
echo "OK .backblaze 완료"
# .git-credentials
fetch_secret "711d2b06-8271-4470-8e63-b40000d9129f" > ~/.git-credentials
chmod 600 ~/.git-credentials
echo "OK .git-credentials 완료"
echo ""
echo "OK Mac 설치 완료"
# ============================================================
# 권한수정
# chmod +x ~/.dotfiles/_install/install_mac.sh
# 실행
# bash ~/.dotfiles/_install/install_mac.sh
# ============================================================