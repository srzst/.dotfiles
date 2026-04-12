# ============================================================
# Ubuntu 24.04 Server 설정 bashrc
# ============================================================

# 인터랙티브 쉘 및 기본 환경 설정
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
# 프롬프트 설정 (사용자@호스트:전체경로$)
# ============================================================
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# 컬러 프롬프트 적용 (전체 경로 \w 유지)
PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

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
alias qq='cd ~/.dotfiles'
alias ww='cd ~/.dotfolders'

# [APT] 시스템 업데이트 및 패키지 관리
u() {
    echo "=== System Update Started (APT) ==="
    sudo apt update && sudo apt upgrade -y
    echo "=== Update Completed ==="
}
alias uu='u'
alias al='apt list --installed'
ai() { sudo apt install "$1" -y; }
au() { sudo apt remove "$1" -y; }

# ============================================================
# Git 관련 (최신 문법 및 본문 지원 커밋)
# ============================================================

# 기본 및 상태 확인
alias gi='git init -b main'               # 저장소 초기화
alias gs='git status'                     # 상태 확인
alias gss='git status -s'                 # 상태 요약
alias ga='git add .'                      # 스테이징
alias gaa='git add --all'                 # 전체 스테이징
alias gp='git push'                       # 푸시
alias gpl='git pull'                      # 풀
alias gpf='git push origin --force-with-lease' # 안전 강제 푸시

# 로그 및 브랜치 관리 (switch 반영)
alias gl='git log --oneline -n 10'        # 한 줄 로그 10개
alias gll='git log --oneline --graph --all' # 전체 로그 그래프
alias gd='git diff'                       # 변경사항 비교
alias gdc='git diff --staged'             # 스테이징 비교
alias gb='git branch'                     # 브랜치 목록
alias gba='git branch -a'                 # 원격 포함 모든 브랜치
alias gsw='git switch'                    # 브랜치 전환
alias gsc='git switch -c'                 # 새 브랜치 생성/전환
alias gbd='git branch -d'                 # 브랜치 삭제
alias gm='git merge'                      # 브랜치 병합
alias gg='lazygit'                        # lazygit

# 태그 관리
alias gt='git tag'                        # 태그 목록
alias gta='git tag -a'                    # 주석 태그 생성
alias gtd='git tag -d'                    # 태그 삭제

# 상태 보존 및 복구 (restore 반영)
alias gst='git stash'                     # 작업 임시 저장
alias gstp='git stash pop'                # 임시 저장 복구
alias gstl='git stash list'               # 임시 저장 목록
alias gr='git reset --hard'               # 강제 초기화
alias grs='git reset --soft HEAD~1'       # 커밋 취소
alias gre='git restore'                   # 파일 복구
alias gres='git restore --staged'         # 스테이징 취소
alias gclean='git clean -fd'              # 미추적 파일 삭제

# ------------------------------------------------------------
# Git & 유틸리티 자동화 함수
# ------------------------------------------------------------

# gac: 제목($1)과 본문($2) 구분 커밋 (복사+붙여넣기 최적화)
gac() {
    git add -A
    if [ -n "$2" ]; then
        git commit -m "$1" -m "$2"
    else
        git commit -m "${1:-auto commit}"
    fi
}

# gacp: 제목($1)과 본문($2) 커밋 후 자동 푸시
gacp() {
    gac "$1" "$2"
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git push origin "$branch"
}

# gfo: 원격 기준 강제 초기화
gfo() {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    echo -e "\033[0;33mFetching from origin and resetting to $branch...\033[0m"
    git fetch origin && git reset --hard "origin/$branch"
}

# mrd: 폴더 생성 + README.md 생성
mrd() {
    mkdir -p "$1"
    echo "# ${1##*/}" > "$1/README.md"
    echo -e "\033[0;32mFolder '$1' created with README.md\033[0m"
}

# mrdpy: 폴더 생성 + README.md + basic.py 생성
mrdpy() {
    mkdir -p "$1"
    echo "# ${1##*/}" > "$1/README.md"
    touch "$1/basic.py"
    echo -e "\033[0;32mFolder '$1' created with README.md and basic.py\033[0m"
}

# ------------------------------------------------------------
# 기타 유틸리티 (Yazi, fzf, gita, 캐시 삭제)
# ------------------------------------------------------------

# gita 관련
alias gtl='gita ll'
alias gtpl='gita pull'
alias gtp='gita super push'
gtac() { gita super add -A; gita super commit -m "${1:-auto commit}"; }
gtacp() { gtac "$1"; gita super push; }

# 유틸리티
mc() { mkdir -p "$1" && cd "$1"; }
f() { find . -iname "*$1*" 2>/dev/null; }
ds() { du -sh "${1:-.}" 2>/dev/null | sort -h; }
pk() { ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs -r sudo kill -9; }

# cd 후 자동 ls
cd() { builtin cd "$@" && ls -F --color=auto; }

# Yazi
y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}
cf() {
  local result query dir
  result=$(fd --type d --hidden --exclude .git . 2>/dev/null | fzf --print-query)
  query=$(echo "$result" | head -1)
  dir=$(echo "$result" | sed -n '2p')

  if [[ "$query" == ".." && -z "$dir" ]]; then
    cd ..
    cf
  elif [[ -n "$dir" ]]; then
    cd "$dir"
  fi
}

# zoxide / fzf 로드
[ -x "$(command -v zoxide)" ] && eval "$(zoxide init bash)"
if [ -d /usr/share/doc/fzf/examples ]; then
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/doc/fzf/examples/completion.bash ] && source /usr/share/doc/fzf/examples/completion.bash
fi
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
[ -x "$(command -v fzf)" ] && alias fe='nvim $(fzf)'

# ============================================================
# Cloudflare 캐시 삭제 로직 (기존 유지)
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

p() {
  local host=$(hostname | tr '[:upper:]' '[:lower:]')
  local zone=""
  case "$host" in
    w1) zone="81717dea734982b7daf583287346f949" ;;
    w2) zone="0e5c7d391be06e7f8e0e5c4dfa88e8fc" ;;
    w3) zone="0ebddc7bb5feb60e2e2eeac29dd14d7d" ;;
    w5) zone="97155be9a57b0f9e31b0b1cd083154a2" ;;
    *) echo "등록되지 않은 호스트($host)입니다."; return 1 ;;
  esac
  _cf_purge "$zone"
}
alias purge='p'
alias w1p='_cf_purge 81717dea734982b7daf583287346f949'
alias w2p='_cf_purge 0e5c7d391be06e7f8e0e5c4dfa88e8fc'
alias w3p='_cf_purge 0ebddc7bb5feb60e2e2eeac29dd14d7d'
alias w5p='_cf_purge 97155be9a57b0f9e31b0b1cd083154a2'
alias ap='w1p && w2p && w3p && w5p'

# 에디터 설정
export EDITOR=nvim
export VISUAL=nvim
alias vi='vim'
alias v='nvim'
alias nrc='nvim ~/.config/nvim'
alias vrc='vi ~/.bashrc'
alias src='source ~/.bashrc'

# 기타 로드
[ -f ~/.bash_aliases ] && . ~/.bash_aliases