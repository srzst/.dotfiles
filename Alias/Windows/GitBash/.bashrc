# ============================================================
# Windows Git Bash 설정 
# ============================================================

# ============================================================
# 기본 설정 및 환경 변수
# ============================================================
export EDITOR=vim

# ============================================================
# 편집기 및 설정 파일 관리
# ============================================================
alias vi='vim'
alias v='vim'
alias nrc='cd ~/.config/nvim && vim .'
alias vrc='vim ~/.bashrc'
alias zrc='vim ~/.bashrc'
alias src='source ~/.bashrc'
alias srcrc='source ~/.bashrc'
alias saverc='source ~/.bashrc'

# ============================================================
# 파일 및 디렉토리 관리
# ============================================================
alias l='ls -la'
alias ll='ls -la'
alias la='ls -la'
alias lt='ls -lt'
alias c='clear'
alias cc='clear'
alias e='exit'
alias ee='exit'

alias ..='cd ..'
alias ...='cd ../..'
alias h='cd ~'
alias cdx='cd /c/Users/$USER'
alias cdxx='cd /c/Users/$USER'
alias cddoc='cd /c/Users/$USER/Documents'
alias cddt='cd /c/Users/$USER/Desktop'

# 디렉토리 생성 후 이동
mc() { mkdir -p "$1" && cd "$1"; }

# ============================================================
# 패키지 업데이트 (u / uu)
# FIX: Windows GitBash에서 apt-get 없음 → 제거
# ============================================================
u() {
    echo "=== 시스템 업데이트 시작 ==="
    if command -v scoop > /dev/null; then
        echo "[Scoop]"
        scoop update '*'
    fi
    if command -v choco > /dev/null; then
        echo "[Chocolatey]"
        choco upgrade all -y
    fi
    echo "=== 업데이트 완료 ==="
}
alias uu='u'

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
# Git 별칭 및 함수
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
gc() {
    git commit -m "$*"
}

# gca: 자동 메시지로 커밋
alias gca='git commit -m "auto commit"'

# gac: Add all + Commit (메시지 없으면 "auto commit")
gac() {
    git add .
    git commit -m "${1:-auto commit}"
}

# gacp: Add all + Commit + Push (현재 브랜치 자동 대응)
gacp() {
    git add .
    git commit -m "${1:-auto commit}"
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -n "$branch" ]; then
        git push origin "$branch"
    else
        git push
    fi
}

# gup: 고정 메시지로 즉시 푸시
alias gup='git add . && git commit -m "auto commit" && git push'

# gfo: 현재 브랜치 원격지 기준 강제 초기화
gfo() {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    echo -e "\033[0;33mResetting to origin/$branch...\033[0m"
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
alias di='docker images'
alias dps='docker ps'
alias dpa='docker ps -a'
de() { docker exec -it "$@"; }
alias dlog='docker logs -f'
alias dstart='docker start'
alias dstop='docker stop'
alias dsprune='docker system prune -f'

# ============================================================
# 시스템 / 네트워크 / 기타
# ============================================================
alias s='sudo '
alias sudo='sudo '
alias cron='crontab -e'
alias myip='curl -s https://ifconfig.me'

# FIX: Git Bash에서 netstat은 Windows 경로로 직접 호출
port() {
    if [ -n "$1" ]; then
        /c/Windows/System32/netstat.exe -ano | grep ":$1"
    else
        /c/Windows/System32/netstat.exe -ano | grep LISTENING
    fi
}

# FIX: f() → ff() 로 변경 (fzf 전역검색 단축키 f와 충돌 방지)
ff() { find . -name "*$1*" 2>/dev/null; }
alias cleanup='find . -name ".DS_Store" -delete && echo ".DS_Store 정리 완료"'

# ============================================================
# 외부 도구 초기화 (Yazi, zoxide)
# ============================================================
# Yazi: 종료 후 경로 유지
y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    if [ -f "$tmp" ]; then
        cwd=$(cat "$tmp")
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && cd "$cwd"
        rm -f "$tmp"
    fi
}

# zoxide 초기화
if command -v zoxide > /dev/null; then
    eval "$(zoxide init bash)"
fi
