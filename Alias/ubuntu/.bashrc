# ============================================================
# Ubuntu 24.04 Server 설정 bashrc 
# ============================================================
# ============================================================
# ============================================================
# 인터랙티브 쉘 및 기본 환경 설정
# ============================================================
[ -z "$PS1" ] && return

HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ============================================================
# 프롬프트 설정
# ============================================================
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color|*-256color) color_prompt=yes ;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# ============================================================
# 기본 별칭 및 파일 조작
# ============================================================
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
fi

alias l='ls -lah'
alias ll='ls -lah'
alias la='ls -lAh'
alias lt='ls -laht'
alias c='clear'
alias cc='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias h='cd ~'
alias e='exit'
alias ee='exit'

alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'

# ============================================================
# 시스템 및 웹 서버 관리
# ============================================================
alias www='cd /var/www'
alias cdw='cd /var/www'
alias cdwp='cd /var/www/wordpress'
alias cdnginx='cd /etc/nginx'
alias cdn='cd /etc/nginx'
alias nt='sudo nginx -t'
alias nr='sudo systemctl restart nginx'
alias nconf='nvim /etc/nginx/nginx.conf'
alias s='sudo systemctl'
alias cron='crontab -e'
alias port='sudo lsof -i -P | grep LISTEN'
alias myip='curl -s ifconfig.me'

# ============================================================
# 패키지 업데이트 (u / uu)
# ============================================================
function u {
    echo "=== System Update Started (APT) ==="
    sudo apt update && sudo apt upgrade -y
    echo "=== Update Completed ==="
}
alias uu='u'

# [APT] - 기본 패키지 관리
alias al='apt list --installed'                # List
function ai() { sudo apt install "$1" -y; }    # Install
function au() { sudo apt remove "$1" -y; }     # Uninstall


# ============================================================
# 에디터 및 설정 파일 관리
# ============================================================
alias vi='vim'
alias v='nvim'
alias nrc='nvim ~/.config/nvim'
alias vrc='vi ~/.bashrc'
alias src='source ~/.bashrc'
alias srcrc='source ~/.bashrc'

# ============================================================
# gita 관련 별칭 및 함수
# ============================================================
alias gtl='gita ll'
alias gtpl='gita pull'
alias gtp='gita super push'

function gtac {
    local msg="${1:-auto commit}"
    gita super add -A
    gita super commit -m "$msg"
}

function gtacp {
    local msg="${1:-auto commit}"
    gita super add -A
    gita super commit -m "$msg"
    gita super push
}

# ============================================================
# Git 관련 (타 플랫폼 통합 로직 이식)
# ============================================================
alias gi='git init -b main'
alias gs='git status'
alias gss='git status -s'
alias ga='git add .'
alias gaa='git add --all'
alias gc='git commit -m'
alias gca='git commit -m "auto commit"'
alias gp='git push'
alias gpl='git pull'
alias gup='git add . && git commit -m "auto commit" && git push'
alias gpf='git push origin --force-with-lease'

function gac {
    git add . && git commit -m "${*:-auto commit}"
}

function gacp {
    git add . && git commit -m "${*:-auto commit}" && git push
}

function go {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git fetch origin && git reset --hard "origin/$branch"
}

alias gl='git log --oneline -10'
alias gll='git log --oneline --graph --all'
alias gd='git diff'
alias gdc='git diff --cached'
alias gb='git branch'
alias gba='git branch -a'
alias gco='git checkout'
alias gcb='git checkout -b'
alias gbd='git branch -d'
alias gm='git merge'
alias gst='git stash'
alias gstp='git stash pop'
alias gstl='git stash list'
alias gr='git reset --hard'
alias grs='git reset --soft HEAD~1'
alias gclean='git clean -fd'
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
# 유틸리티 함수
# ============================================================
function mc { mkdir -p "$1" && cd "$1"; }
function f { find . -iname "*$1*" 2>/dev/null; }
function ds { du -sh "${1:-.}" 2>/dev/null | sort -h; }
function pk { ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs -r sudo kill -9; }

# cd 실행 후 자동 ls
function cd {
    builtin cd "$@" && ls -F --color=auto
}

# ============================================================
# 외부 도구 초기화 (Yazi, zoxide, fzf)
# ============================================================
# Yazi
function y {
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

# zoxide
if command -v zoxide > /dev/null; then
    eval "$(zoxide init bash)"
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

# ============================================================
# 기타 별도 설정 로드
# ============================================================
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi