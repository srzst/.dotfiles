# ============================================================
# macOS Zsh 설정 zshrc
# ============================================================

# ============================================================
# 자동 완성 (상단 배치로 초기화 성능 개선)
# ============================================================
autoload -Uz compinit && compinit -i
zstyle ':completion:*' menu select

# ============================================================
# 환경 변수 및 기본 설정
# ============================================================
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# PATH 설정
# FIX: 하드코딩 /Users/x → $HOME 으로 변경
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/python@3.12/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"

# Python 관련 별칭 및 Pip 함수 (시스템 패키지 보호 우회)
alias python="/opt/homebrew/bin/python3"
alias python3="/opt/homebrew/bin/python3"
pip() { /opt/homebrew/opt/python@3.12/bin/python3.12 -m pip "$@" --break-system-packages; }

# ============================================================
# 에디터 및 설정 파일 관리
# ============================================================
alias vi='vim'
alias v='nvim'
alias nrc='nvim ~/.config/nvim'
alias zrc='nvim ~/.zshrc'
alias vrc='nvim ~/.vimrc'
alias src='source ~/.zshrc'
alias srcrc='source ~/.zshrc'
alias e='exit'
alias ee='exit'

# ============================================================
# 파일 및 디렉토리 관리
# ============================================================
alias l='ls -lah'
alias ll='ls -lah'
alias la='ls -lAh'
alias lt='ls -laht'
alias c='clear'
alias cc='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias h='cd ~'

# 디렉토리 생성 후 이동
mc() { mkdir -p "$1" && cd "$1"; }

# cd 실행 후 자동 ls
cd() {
    if [ -n "$*" ]; then
        builtin cd "$*" && ls -F
    else
        builtin cd ~ && ls -F
    fi
}

# ============================================================
# 패키지 관리
# ============================================================
u() {
    echo "=== System Update Started (Homebrew) ==="
    brew update && brew upgrade && brew upgrade --cask && brew cleanup
    echo "=== Update Completed ==="
}
alias uu='u'

# [Homebrew]
alias bl='brew list'
function bi() { brew install "$1"; }
function bu() { brew uninstall "$1"; }

# [Cask]
alias bcl='brew list --cask'
function bci() { brew install --cask "$1"; }
function bcu() { brew uninstall --cask "$1"; }

# ============================================================
# gita 관련 별칭 및 함수
# ============================================================
alias gtl='gita ll'
alias gtpl='gita pull'
alias gtp='gita super push'

gtac() {
    local msg="${1:-auto commit}"
    gita super add -A
    gita super commit -m "$msg"
}

gtacp() {
    local msg="${1:-auto commit}"
    gita super add -A
    gita super commit -m "$msg"
    gita super push
}

# ============================================================
# Git 관련
# ============================================================

# 기본 별칭
alias gi='git init -b main'
alias gs='git status'
alias gss='git status -s'
alias ga='git add .'
alias gaa='git add --all'
alias gp='git push'
alias gpl='git pull'
alias gpf='git push origin --force-with-lease'

# 로그 및 브랜치 관리
alias gl='git log --oneline -n 10'
alias gll='git log --oneline --graph --all'
alias gd='git diff'
alias gdc='git diff --staged'
alias gb='git branch'
alias gba='git branch -a'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gbd='git branch -d'
alias gm='git merge'

# 상태 보존 및 초기화
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gr='git reset --hard'
alias grs='git reset --soft HEAD~1'
alias gclean='git clean -fd'

# gc: 커밋 메시지와 함께 커밋
gc() { git commit -m "$*"; }

# gca: 자동 메시지로 커밋
alias gca='git commit -m "auto commit"'

# gac: Add all + Commit
gac() {
    git add -A
    git commit -m "${1:-auto commit}"
}

# gacp: Add all + Commit + Push
gacp() {
    git add -A
    git commit -m "${1:-auto commit}"
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git push origin "$branch"
}

# gup: 고정 메시지로 즉시 푸시
alias gup='git add . && git commit -m "auto commit" && git push'

# gfo: 원격 기준 강제 초기화
gfo() {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$branch" ]; then branch="main"; fi
    echo -e "\033[0;33mFetching from origin and resetting to $branch...\033[0m"
    git fetch origin && git reset --hard "origin/$branch"
}
# 서브 모듈 일괄 커밋 및 푸시
gsacp() {
    local msg="${1:-auto commit}"
    git submodule foreach "git add ."
    git submodule foreach "git commit -m '$msg'"
    git submodule foreach "git push"
    git add .
    git commit -m "$msg"
    git push
}
# ============================================================
# Docker 관련
# ============================================================
alias d='docker'
alias dps='docker ps'
alias dpsa='docker ps -a'
alias di='docker images'
alias dex='docker exec -it'
alias dlog='docker logs -f'
# FIX: alias → 함수로 변경 (alias는 정의 시점에 즉시 평가되어 빈 값 고정)
dstop() { docker stop $(docker ps -q); }
alias dprune='docker system prune -af'

# ============================================================
# 시스템 / 네트워크
# ============================================================
alias port='lsof -i -P | grep LISTEN'
alias myip='curl -s ifconfig.me'
alias localip='ipconfig getifaddr en0'
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
alias cleanup='find . -type f -name ".DS_Store" -delete && echo ".DS_Store 정리 완료"'

# ============================================================
# 유틸리티 함수
# ============================================================
# FIX: f() → ff() (fzf f 단축키 충돌 방지, 전 플랫폼 통일)
ff() { find . -iname "*$1*" 2>/dev/null; }
ds() { du -sh "${1:-.}" 2>/dev/null | sort -h; }
pk() { ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs kill -9; }

# Yazi: 종료 후 경로 유지
y() {
  local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
  command yazi "$@" --cwd-file="$tmp"
  if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
    builtin cd -- "$cwd"
  fi
  rm -f -- "$tmp"
}

export EDITOR=nvim
export VISUAL=nvim
alias yazi='EDITOR=nvim yazi'

# zoxide 초기화
if command -v zoxide > /dev/null; then
  eval "$(zoxide init zsh)"
fi


# fzf
if [ -d /usr/share/doc/fzf/examples ]; then
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash
fi

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

if command -v fzf > /dev/null; then
    alias fe='nvim $(fzf)'
fi

# secrets 로드
[[ -f ~/.zshrc_secrets ]] && source ~/.zshrc_secrets
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
