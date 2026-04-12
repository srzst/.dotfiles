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
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/python@3.14/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"
# pip 함수 수정 (3.14 경로로 업데이트)
pip() { /opt/homebrew/opt/python@3.14/bin/python3.14 -m pip "$@" --break-system-packages; }
# Python 관련 별칭 및 Pip 함수 (시스템 패키지 보호 우회)
alias python="/opt/homebrew/bin/python3"
alias python3="/opt/homebrew/bin/python3"
# Infisical secrets 함수

infs() {
    local path="${1:-/}"
    local token=$(/usr/bin/security find-generic-password -a "$USER" -s "INFISICAL_TOKEN" -w | /usr/bin/tr -d '\n')
    INFISICAL_TOKEN="$token" /opt/homebrew/bin/infisical secrets \
        --projectId=bc893247-af3f-4118-a8ec-bcb429338acb \
        --env=dev \
        --path="$path"
}

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
# 파일 및 디렉토리 관리 (eza 기반 최적화)
# ============================================================
# 기본 리스트 (아이콘 제외, 폴더 우선 정렬)
alias l='eza -alF --group-directories-first'
alias ll='eza -alF --group-directories-first --git'
alias la='eza -aF --group-directories-first'
alias lt='eza -alF --sort=modified' # 수정 시간순 정렬

# 트리 구조 (아이콘 제외, 숨김 파일 포함, .git 및 ignore 반영)
alias et='eza --tree -a -I ".git" --git-ignore'
alias et1='eza --tree --level=1 -a -I ".git" --git-ignore'
alias et2='eza --tree --level=2 -a -I ".git" --git-ignore'
alias et3='eza --tree --level=3 -a -I ".git" --git-ignore'

# 시스템 유틸리티
alias c='clear'
alias cc='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias h='cd ~'
# fzf 
alias ff='fzf'
alias vf='nvim $(fzf)'
# alias cf='cd $(fd --type d | fzf)'

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

# 디렉토리 생성 후 이동
mc() { mkdir -p "$1" && cd "$1"; }

# cd 실행 후 자동 eza (한 줄로 간결하게 표시)
cd() {
    if [ -n "$*" ]; then
        builtin cd "$*" && eza -F --group-directories-first
    else
        builtin cd ~ && eza -F --group-directories-first
    fi
}

# 사용자 지정 경로 이동
alias qq='cd ~/.dotfiles'
alias ww='cd ~/.dotfolders'

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
# Git 관련 (최신 문법, 태그 관리, 자동화 함수 포함)
# ============================================================

# 기본 및 상태 확인
alias gi='git init -b main'               # 메인 브랜치명 지정하여 저장소 초기화
alias gs='git status'                     # 현재 변경 상태 확인
alias gss='git status -s'                 # 상태 요약 확인 확인
alias ga='git add .'                      # 현재 폴더 변경사항 스테이징
alias gaa='git add --all'                 # 모든 변경사항 스테이징
alias gp='git push'                       # 원격 저장소에 푸시
alias gpl='git pull'                      # 원격 저장소에서 풀
alias gpf='git push origin --force-with-lease' # 안전한 강제 푸시

# 로그 및 브랜치 관리 (최신 switch 반영)
alias gl='git log --oneline -n 10'        # 한 줄 로그 10개 확인
alias gll='git log --oneline --graph --all' # 전체 브랜치 로그 그래프 확인
alias gd='git diff'                       # 작업 디렉토리 변경사항 비교
alias gdc='git diff --staged'             # 스테이징된 변경사항 비교
alias gb='git branch'                     # 로컬 브랜치 목록 확인
alias gba='git branch -a'                 # 모든 브랜치(원격 포함) 확인
alias gsw='git switch'                    # 브랜치 전환 (checkout 대체)
alias gsc='git switch -c'                 # 새 브랜치 생성 및 전환
alias gbd='git branch -d'                 # 브랜치 삭제 (병합 완료 시)
alias gbD='git branch -D'                 # 브랜치 강제 삭제
alias gm='git merge'                      # 브랜치 병합
alias gg='lazygit'                        # lazygit 실행

# 태그 관리
alias gt='git tag'                        # 태그 목록 확인
alias gtd='git tag -d'                    # 태그 삭제
# gta: 날짜_시간_메시지 형식으로 태그명 자동 생성
# gta: 날짜_시간(메시지) 형식으로 태그명 자동 생성
gta() {
    if [ -z "$1" ]; then
        echo "❌ 에러: 태그 메시지를 입력해주세요."
        return 1
    fi

    # 태그명: YYMMDD_HHMM(입력메시지)
    # 메시지 내부의 공백은 보기 좋게 언더바(_)로 치환합니다.
    local msg_clean="${1// /_}"
    local tag_name="$(date +'%y%m%d_%H%M')(${msg_clean})"
    
    git tag -a "$tag_name" -m "$1"
    
    echo "✅ 태그 생성 완료: $tag_name"
}


# 상태 보존 및 복구 (최신 restore 반영)
alias gst='git stash'                     # 작업 임시 저장
alias gstp='git stash pop'                # 임시 저장 불러오기 및 삭제
alias gstl='git stash list'               # 임시 저장 목록 확인
alias gr='git reset --hard'               # 특정 시점으로 강제 초기화
alias grs='git reset --soft HEAD~1'       # 최근 커밋 취소 (내용은 유지)
alias gre='git restore'                   # 파일 변경사항 복구 (checkout -- 대체)
alias gres='git restore --staged'         # 스테이징 취소
alias gclean='git clean -fd'              # 추적되지 않는 파일 강제 삭제

# ------------------------------------------------------------
# Git 자동화 함수 (커밋 제목/본문 구분 및 폴더 자동 생성)
# ------------------------------------------------------------

# gc: 커밋 메시지와 함께 커밋
gc() { git commit -m "$*"; }

# gca: 자동 메시지로 커밋
alias gca='git commit -m "auto commit"'


# gac: 제목($1)과 본문($2)을 구분하여 커밋 (복사+붙여넣기 최적화)
gac() {
    git add -A
    if [ -n "$2" ]; then
        # $2에 들어온 줄바꿈이 포함된 텍스트를 그대로 커밋 본문에 반영
        git commit -m "$1" -m "$2"
    else
        git commit -m "${1:-auto commit}"
    fi
}

# gacp: 제목($1)과 본문($2) 커밋 후 푸시 (gac의 구조를 그대로 계승)
gacp() {
    # 첫 번째와 두 번째 인자를 gac 함수로 전달
    gac "$1" "$2"
    # 현재 브랜치 이름을 확인하여 푸시 (없으면 main)
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
# ============================================================


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
# eza 트리 구조 별칭 (아이콘 제외, .git 및 git-ignore 반영)
# ============================================================
# 전체 깊이 트리 (주의: 매우 큰 폴더에서는 지양)
alias et='eza --tree -a -I ".git" --git-ignore'

# 1단계 트리
alias et1='eza --tree --level=1 -a -I ".git" --git-ignore'

# 2단계 트리
alias et2='eza --tree --level=2 -a -I ".git" --git-ignore'

# 3단계 트리
alias et3='eza --tree --level=3 -a -I ".git" --git-ignore'
# ============================================================
# ============================================================
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
fn() { find . -iname "*$1*" 2>/dev/null; }
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


# ============================================================
# SSH 접속 자동화 (Master SSH Key 방식)
# ============================================================
_ssh_connect() {
    local user_name="$1"
    local target_host="$2"
    local key_path="$HOME/.ssh/main_ssh_key"

    # 마스터 키 존재 확인
    if [ ! -f "$key_path" ]; then
        echo -e "\033[0;31m[Error]\033[0m 마스터 키($key_path)가 없습니다."
        echo "Infisical에서 키를 먼저 복구하세요."
        return 1
    fi

    echo -e "\033[0;32mConnecting to $target_host as $user_name (via Master Key)...\033[0m"
    
    # -i 옵션으로 마스터 키를 명시하여 접속
    ssh -i "$key_path" \
        -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null \
        -o IdentitiesOnly=yes \
        "$user_name@$target_host"
}

# 별칭 등록
pve() { _ssh_connect "root" "pve"; }
w1()  { _ssh_connect "x" "w1"; }
w2()  { _ssh_connect "x" "w2"; }
w3()  { _ssh_connect "x" "w3"; }
w5()  { _ssh_connect "x" "w5"; }
shorten() { _ssh_connect "x" "shorten"; }
stn() { _ssh_connect "x" "shorten"; }

# zsh-syntax-highlighting
source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# LS_COLORS for colorful ls
export CLICOLOR=1
export LSCOLORS="ExFxCxDxBxegedabagacad"   # 기본 예쁜 색상 (Catppuccin 느낌에 가까움)
# ============================================================
# 프롬프트 설정 (전체 경로 표시)
# ============================================================
# %n: 사용자명 / %m: 호스트명 / %~: 전체 경로(홈은 ~) / %#: 권한 표시
PROMPT='%n@%m %~ %# '