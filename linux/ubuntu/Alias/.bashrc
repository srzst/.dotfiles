# C:\Users\x\.dotfiles\linux\ubuntu\Alias\.bashrc
# 수정전: 26-04-14(화) 11:28 https://gist.github.com/srzst/822e02ed21a307c5a10820076b832af6
# ============================================================
# Ubuntu 24.04 Server 설정 (.bashrc)
# ============================================================


# ============================================================
# [FIX] Conflict Aliases (사용자 정의 별칭과 충돌하는 시스템 별칭 사전 제거)
# ============================================================
unalias zz 2>/dev/null   # zoxide 또는 기타 툴이 설정한 zz 제거


# ============================================================
# 기본 환경 설정
# ============================================================
[ -z "$PS1" ] && return

HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
HISTSIZE=1000
HISTFILESIZE=2000
shopt -s checkwinsize
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"


# ============================================================
# 프롬프트 설정 (사용자@호스트:전체경로$)
# ============================================================
if [ -z "$debian_chroot" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '


# ============================================================
# 에디터 및 설정 파일
# ============================================================
export EDITOR=nvim
export VISUAL=nvim

alias vi='vim'
alias v='nvim'
alias nrc='nvim ~/.config/nvim'           # nvim 설정 열기
alias vrc='vi ~/.bashrc'                  # bashrc 편집
alias src='source ~/.bashrc'              # bashrc 재로드


# ============================================================
# 파일 및 디렉토리 관리
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

alias cp='cp -iv'
alias mv='mv -iv'
alias rm='rm -iv'

cd() { builtin cd "$@" && ls -F --color=auto; }

mc() { mkdir -p "$1" && cd "$1"; }        # 디렉토리 생성 후 이동
f()  { find . -iname "*$1*" 2>/dev/null; } # 파일명 검색
ds() { du -sh "${1:-.}" 2>/dev/null | sort -h; }  # 디렉토리 용량
pk() { ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs -r sudo kill -9; }  # 프로세스 종료


# ============================================================
# 시스템 유틸리티
# ============================================================
alias c='clear'
alias cc='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias h='cd ~'
alias e='exit'
alias ee='exit'

alias port='sudo lsof -i -P | grep LISTEN'   # 열린 포트 확인
alias myip='curl -s ifconfig.me'              # 외부 IP
alias cron='crontab -e'                       # 크론탭 편집

alias qq='cd ~/.dotfiles'
alias ww='cd ~/.dotfolders'


# ============================================================
# 웹 서버 관리 (Nginx)
# ============================================================
alias www='cd /var/www'
alias cdw='cd /var/www'
alias wp='cd /var/www/wp'
alias cdnginx='cd /etc/nginx'
alias cdn='cd /etc/nginx'
alias nt='sudo nginx -t'                      # nginx 설정 테스트
alias nr='sudo systemctl restart nginx'       # nginx 재시작
alias nconf='nvim /etc/nginx/nginx.conf'      # nginx 설정 편집
alias s='sudo systemctl'                      # systemctl 단축
alias w0='cd ~/wo'

# ============================================================
# 패키지 관리 (APT)
# ============================================================
u() {
    echo "=== System Update Started (APT) ==="
    sudo apt update && sudo apt upgrade -y
    echo "=== Update Completed ==="
}
alias uu='u'

alias al='apt list --installed'               # 설치된 패키지 목록
ai() { sudo apt install "$1" -y; }            # 패키지 설치
au() { sudo apt remove "$1" -y; }             # 패키지 제거


# ============================================================
# Infisical
# ============================================================
infs() {
    local path="${1:-/}"
    INFISICAL_TOKEN="$INFISICAL_TOKEN" infisical secrets \
        --projectId=bc893247-af3f-4118-a8ec-bcb429338acb \
        --env=dev \
        --path="$path"
}


# ============================================================
# Yazi / zoxide / fzf
# ============================================================
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
    if [[ "$query" == ".." && -z "$dir" ]]; then cd ..; cf
    elif [[ -n "$dir" ]]; then cd "$dir"
    fi
}

[ -x "$(command -v zoxide)" ] && eval "$(zoxide init bash)"

if [ -d /usr/share/doc/fzf/examples ]; then
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/doc/fzf/examples/completion.bash ]   && source /usr/share/doc/fzf/examples/completion.bash
fi
[ -f ~/.fzf.bash ] && source ~/.fzf.bash
[ -x "$(command -v fzf)" ] && alias fe='nvim $(fzf)'     # fzf로 파일 선택 후 nvim


# ============================================================
# gita
# ============================================================
alias gtl='gita ll'                                        # 전체 저장소 상태
alias gtpl='gita pull'                                     # 전체 저장소 일괄 pull
alias gtps='gita super push'                               # 전체 저장소 일괄 push
alias gtp='gita super push'

# gta: 특정 저장소 애드 + 커밋 + 푸시
# 사용법: gta .dotfolders "제목" "설명"
gta() {
    local repo="$1"
    local title="${2:-auto commit }"
    local body="$3"

    if [ -z "$repo" ]; then
        echo "Usage: gta <repo_name> [title] [body]"
        return 1
    fi

    echo -e "\033[0;36m→ Processing repository: $repo \033[0m"

    # 1. Add
    gita shell "$repo" git add -A

    # 2. Commit (따옴표 중첩으로 공백 및 한글 이슈 방지)
    if [ -n "$body" ]; then
        gita shell "$repo" git commit -m "$title" -m "$body"
    else
        gita shell "$repo" git commit -m "$title"
    fi

    # 3. Push
    echo -e "\033[0;32m→ Pushing to remote... \033[0m"
    gita shell "$repo" git push
}

# gtacp: 전체 저장소 일괄 애드 + 커밋 + 푸시
gtacp() {
    local msg="${1:-auto commit }"
    gita super add -A
    gita super commit -m "$msg"
    gita super push
}
# ============================================================
# Git 기본
# ============================================================
alias gi='git init -b main'                               # main 브랜치로 초기화
alias gs='git status'                                     # 변경 상태 확인
alias gss='git status -s'                                 # 상태 요약
alias ga='git add .'                                      # 현재 폴더 스테이징
alias gaa='git add --all'                                 # 전체 스테이징
alias gp='git push'                                       # 푸시
alias gpl='git pull'                                      # 풀
alias gpf='git push origin --force-with-lease'            # 안전한 강제 푸시
alias gl='git log --oneline -n 10'                        # 최근 로그 10개
alias gll='git log --oneline --graph --all'               # 전체 브랜치 그래프
alias gd='git diff'                                       # 변경사항 비교
alias gdc='git diff --staged'                             # 스테이징된 변경사항 비교
alias gb='git branch'                                     # 로컬 브랜치 목록
alias gba='git branch -a'                                 # 전체 브랜치 (원격 포함)
alias gsw='git switch'                                    # 브랜치 전환
alias gsc='git switch -c'                                 # 브랜치 생성 및 전환
alias gbd='git branch -d'                                 # 브랜치 삭제 (병합 완료)
alias gm='git merge'                                      # 브랜치 병합
alias gg='lazygit'                                        # lazygit 실행
alias gst='git stash'                                     # 작업 임시 저장
alias gstp='git stash pop'                                # 임시 저장 복원
alias gstl='git stash list'                               # 임시 저장 목록
alias gr='git reset --hard'                               # 강제 초기화
alias grs='git reset --soft HEAD~1'                       # 최근 커밋 취소 (내용 유지)
alias gre='git restore'                                   # 파일 변경사항 복구
alias gres='git restore --staged'                         # 스테이징 취소
alias gclean='git clean -fd'                              # 미추적 파일 삭제

gac() {
    git add -A
    if [ -n "$2" ]; then git commit -m "$1" -m "$2"
    else                 git commit -m "${1:-auto commit}"
    fi
}

gacp() {
    gac "$1" "$2"
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    git push origin "$branch"
}

gfo() {
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    echo -e "\033[0;33mFetching from origin and resetting to $branch...\033[0m"
    git fetch origin && git reset --hard "origin/$branch"
}

mrd() {
    mkdir -p "$1"
    echo "# ${1##*/}" > "$1/README.md"
    echo -e "\033[0;32m✅ $1 (README.md)\033[0m"
}

mrdpy() {
    mkdir -p "$1"
    echo "# ${1##*/}" > "$1/README.md"
    touch "$1/basic.py"
    echo -e "\033[0;32m✅ $1 (README.md + basic.py)\033[0m"
}


# ============================================================
# Git 태그 관리
# ============================================================
# gt               - 태그 목록
# gta "msg"        - 현재 커밋에 태그 생성    → 260412_2210(msg)
# gt1 "msg"        - 빈 커밋 + 태그 생성      → 260412_2210(msg)
# gt2 <tag>        - 전체 복원
# gt2 <tag> <file> - 단일/복수 파일 복원
# gt3 <tag>        - 태그 삭제
# gt4              - 전체 태그 삭제
# ============================================================
alias gt='git tag'
alias gtd='git tag -d'                                    # 태그 삭제 단축

gta() {
    [ -z "$1" ] && echo "❌ 메시지를 입력하세요." && return 1
    local tag_name="$(date +'%y%m%d_%H%M')(${1// /_})"
    git tag -a "$tag_name" -m "$1"
    echo "✅ 태그 생성: $tag_name"
}

gt1() {
    [ -z "$1" ] && echo "❌ 메시지를 입력하세요." && return 1
    local tag_name="$(date +'%y%m%d_%H%M')(${1// /_})"
    git commit --allow-empty -m "checkpoint: $1"
    git tag -a "$tag_name" -m "$1"
    echo "✅ 태그 백업: $tag_name"
}

gt2() {
    [ -z "$1" ] && echo "❌ 태그명을 입력하세요." && return 1
    local tag="$1"; shift
    if [ $# -gt 0 ]; then
        for f in "$@"; do git restore --source="$tag" "$f" && echo "✅ 복원: $f (from $tag)"; done
    else
        git restore --source="$tag" . && echo "✅ 전체 복원 (from $tag)"
    fi
}

gt3() {
    [ -z "$1" ] && echo "❌ 태그명을 입력하세요." && return 1
    git tag -d "$1" && echo "✅ 태그 삭제: $1"
}

gt4() {
    echo -n "⚠️  모든 태그를 삭제합니다. 계속할까요? (y/N): "
    read confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        git tag | xargs git tag -d && echo "✅ 전체 태그 삭제 완료"
    else echo "취소됨"
    fi
}


# ============================================================
# Git 파일 단위 백업/복원
# ============================================================
# gf1 <file>        - 파일 백업 커밋 (기본 메시지: 260412_2210 수정전)
# gf1 <file> "msg"  - 커스텀 메시지로 백업
# gf2 <hash>        - 해시로 파일 자동 인식 후 복원
# gl                - 백업 이력 확인
# ============================================================
gf1() {
    [ -z "$1" ] && echo "❌ 사용법: gf1 파일명 [메시지]" && return 1
    local file="$1"
    local msg="${2:-$(date +'%y%m%d_%H%M') 수정전}"
    local root=$(git rev-parse --show-toplevel)
    local abs=$(builtin cd "$(dirname "$file")" && pwd)/$(basename "$file")
    local rel="${abs#$root/}"
    echo "" >> "$abs"
    git -C "$root" add "$rel"
    git -C "$root" commit -m "backup: $rel - $msg"
    echo "✅ 저장: $rel - $msg"
}

gf2() {
    [ -z "$1" ] && echo "❌ 사용법: gf2 <hash>" && return 1
    local root=$(git rev-parse --show-toplevel)
    local rel=$(git -C "$root" show --name-only --format="" "$1" | head -1)
    git -C "$root" restore --source="$1" "$rel"
    echo "✅ 복원: $rel"
}


# ============================================================
# Cloudflare 캐시 삭제
# ============================================================
# p          - 현재 호스트 기준 자동 퍼지
# w1p~w5p    - 사이트별 퍼지
# ap         - 전체 퍼지
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
        *)  echo "등록되지 않은 호스트($host)입니다."; return 1 ;;
    esac
    _cf_purge "$zone"
}

alias purge='p'
alias w1p='_cf_purge 81717dea734982b7daf583287346f949'
alias w2p='_cf_purge 0e5c7d391be06e7f8e0e5c4dfa88e8fc'
alias w3p='_cf_purge 0ebddc7bb5feb60e2e2eeac29dd14d7d'
alias w5p='_cf_purge 97155be9a57b0f9e31b0b1cd083154a2'
alias ap='w1p && w2p && w3p && w5p'

alias rcw="rclone rcd --rc-web-gui"  # rclone web gui
# ============================================================
# 기타 로드
# ============================================================
[ -f ~/.bash_aliases ] && . ~/.bash_aliases
[[ -f ~/.bashrc_secrets ]] && source ~/.bashrc_secrets
# ============================================================
# Bash Readline: 프롬프트 전용 이동 / 단어 이동 / 삭제
# Windows Alt = macOS Option 감각 기준
# vim, nvim, less, ssh 내부에는 영향 없음
# ============================================================

# 기본 이동
bind '"\ej": backward-char'
bind '"\el": forward-char'
bind '"\ei": previous-history'
bind '"\ek": next-history'

# 단어 단위 이동
bind '"\eu": backward-word'
bind '"\eo": forward-word'

# 줄 처음 / 끝
bind '"\ey": beginning-of-line'
bind '"\ep": end-of-line'

# 글자 삭제
bind '"\eh": backward-delete-char'
bind '"\eq": backward-delete-char'
bind '"\ew": delete-char'
bind '"\em": delete-char'

# 단어 단위 삭제
bind '"\e\C-j": backward-kill-word'
bind '"\e\C-l": kill-word'