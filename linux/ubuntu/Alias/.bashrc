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
# Infisical secrets 함수
infs() {
    local path="${1:-/}"
    INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets \
        --projectId=bc893247-af3f-4118-a8ec-bcb429338acb \
        --env=dev \
        --path="$path"
}
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
# 사용자 지정 경로 이동
alias qq='cd ~/.dotfiles'
alias ww='cd ~/.dotfolders'
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

function gfo {
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
# Cloudflare 캐시 삭제 별칭
# ============================================================
_cf_purge() {
  local zone=$1
  sudo find /var/cache/nginx/wp -type f -delete 2>/dev/null && echo "Nginx 캐시 삭제 완료"
  local redis_pass=$(sudo bash -c 'source /root/.bashrc_secrets && INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get main_password --projectId=bc893247-af3f-4118-a8ec-bcb429338acb --env=dev --path=/ --plain --silent 2>/dev/null')
  redis-cli -a "$redis_pass" --no-auth-warning FLUSHALL > /dev/null && echo "Redis 캐시 삭제 완료"
  local token=$(sudo bash -c 'source /root/.bashrc_secrets && INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get cf_cache_purge_token --projectId=bc893247-af3f-4118-a8ec-bcb429338acb --env=dev --path=/cloudflare --plain --silent 2>/dev/null')
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone/purge_cache" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    --data '{"purge_everything":true}'
  echo ""
}

# ============================================================
# Cloudflare 캐시 삭제 별칭 (확장형)
# ============================================================
# 기본 purge 별칭
alias w1purge='_cf_purge 81717dea734982b7daf583287346f949'
alias w2purge='_cf_purge 0e5c7d391be06e7f8e0e5c4dfa88e8fc'
alias w3purge='_cf_purge 0ebddc7bb5feb60e2e2eeac29dd14d7d'
alias w5purge='_cf_purge 97155be9a57b0f9e31b0b1cd083154a2'

# 단축형 별칭 추가 (w1p, w2p 등)
alias w1p='w1purge'
alias w2p='w2purge'
alias w3p='w3purge'
alias w5p='w5purge'

# 전체 삭제 단축어
alias ap='allpurge'
alias allpurge='w1p && w2p && w3p && w5p'

# ============================================================
# 서버 자동 인식형 통합 캐시 삭제 (p)
# ============================================================
p() {
  # 1. 현재 서버의 호스트네임(W1, W2...) 감지 (소문자로 변환)
  local host=$(hostname | tr '[:upper:]' '[:lower:]')
  local zone=""
  local domain=""

  # 2. 호스트네임별 도메인 및 Zone ID 매핑
  case "$host" in
    w1) 
      zone="81717dea734982b7daf583287346f949"
      domain="comeinsidebox.com"
      ;;
    w2) 
      zone="0e5c7d391be06e7f8e0e5c4dfa88e8fc"
      domain="iboxcomein.com"
      ;;
    w3) 
      zone="0ebddc7bb5feb60e2e2eeac29dd14d7d"
      domain="eazymanual.com"
      ;;
    w5) 
      zone="97155be9a57b0f9e31b0b1cd083154a2"
      domain="ezis.org"
      ;;
    *) 
      echo "등록되지 않은 호스트($host)입니다."
      return 1 
      ;;
  esac

  echo -e "\033[0;32m==> [$host] $domain 캐시 삭제 시작...\033[0m"

  # 3. Nginx 캐시 삭제
  sudo find /var/cache/nginx/wp -type f -delete 2>/dev/null && echo "✔ Nginx 캐시 삭제 완료"

  # 4. Redis 캐시 삭제 (Infisical에서 암호 로드)
  local redis_pass=$(sudo bash -c 'source /root/.bashrc_secrets && INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get main_password --projectId=bc893247-af3f-4118-a8ec-bcb429338acb --env=dev --path=/ --plain --silent 2>/dev/null')
  redis-cli -a "$redis_pass" --no-auth-warning FLUSHALL > /dev/null && echo "✔ Redis 캐시 삭제 완료"

  # 5. Cloudflare API 호출 (Infisical에서 토큰 로드)
  local token=$(sudo bash -c 'source /root/.bashrc_secrets && INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets get cf_cache_purge_token --projectId=bc893247-af3f-4118-a8ec-bcb429338acb --env=dev --path=/cloudflare --plain --silent 2>/dev/null')
  
  local response=$(curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zone/purge_cache" \
    -H "Authorization: Bearer $token" \
    -H "Content-Type: application/json" \
    --data '{"purge_everything":true}')

  if [[ $response == *"\"success\":true"* ]]; then
    echo -e "\033[0;34m✔ Cloudflare 캐시 삭제 완료 ($domain)\033[0m"
  else
    echo -e "\033[0;31m✘ Cloudflare 캐시 삭제 실패\033[0m"
  fi
}

# 단축어 등록
alias purge='p'



# ============================================================
# 기타 별도 설정 로드
# ============================================================
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

