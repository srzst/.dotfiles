# /Users/x/.dotfiles/mac/Alias/.zshrc
# 수정 직전 2026-04-13(월): https://gist.github.com/srzst/81049f5bf03a094c8e669fd225d024cb
# 정리 직전 2026-04-14(화): https://gist.github.com/srzst/dcffcf60b6ada701b64ce637e0dbfe06
# ============================================================
# macOS Zsh 설정 (.zshrc)
# ============================================================


# ============================================================
# [FIX] Conflict Aliases (사용자 정의 별칭과 충돌하는 시스템 별칭 사전 제거)
# ============================================================
unalias zz  2>/dev/null   # zoxide 또는 기타 툴이 설정한 zz 제거


# ============================================================
# 자동 완성
# ============================================================
autoload -Uz compinit && compinit -i
zstyle ':completion:*' menu select


# ============================================================
# 환경 변수 및 PATH
# ============================================================
export PATH="/opt/homebrew/bin:/opt/homebrew/opt/python@3.14/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"
export GOPATH=$HOME/go
export PATH=$PATH:$GOPATH/bin
export EDITOR=nvim
export VISUAL=nvim

export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ]                    && \. "/opt/homebrew/opt/nvm/nvm.sh"
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && \. "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

pip() { /opt/homebrew/opt/python@3.14/bin/python3.14 -m pip "$@" --break-system-packages; }
alias python="/opt/homebrew/bin/python3"
alias python3="/opt/homebrew/bin/python3"

[[ -f ~/.zshrc_secrets ]] && source ~/.zshrc_secrets


# ============================================================
# 에디터 및 설정 파일
# ============================================================
alias vi='vim'
alias v='nvim'
alias nrc='nvim ~/.config/nvim'           # nvim 설정 열기
alias zrc='nvim ~/.zshrc'                 # zshrc 편집
alias vrc='nvim ~/.vimrc'                 # vimrc 편집
alias src='source ~/.zshrc'               # zshrc 재로드
alias srcrc='source ~/.zshrc'
alias e='exit'
alias ee='exit'


# ============================================================
# 파일 및 디렉토리 관리 (eza)
# ============================================================
alias l='eza -alF --group-directories-first'
alias ll='eza -alF --group-directories-first --git'       # git 상태 포함
alias la='eza -aF --group-directories-first'              # 숨김 파일 포함
alias lt='eza -alF --sort=modified'                       # 수정 시간순

alias et='eza --tree -a -I ".git" --git-ignore'
alias et1='eza --tree --level=1 -a -I ".git" --git-ignore'
alias et2='eza --tree --level=2 -a -I ".git" --git-ignore'
alias et3='eza --tree --level=3 -a -I ".git" --git-ignore'

export CLICOLOR=1
export LSCOLORS="ExFxCxDxBxegedabagacad"


# ============================================================
# 시스템 유틸리티
# ============================================================
alias c='clear'
alias cc='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias h='cd ~'
alias w0='cd ~/W0'
alias d0='cd ~/D0'
alias util='cd ~/.dotfolders/common/python/util'
alias wp='cd ~/.dotfolders/common/python/util/wordpress'

alias port='lsof -i -P | grep LISTEN'                    # 열린 포트 확인
alias myip='curl -s ifconfig.me'                          # 외부 IP
alias localip='ipconfig getifaddr en0'                    # 로컬 IP
alias flushdns='sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder'
alias cleanup='find . -type f -name ".DS_Store" -delete && echo ".DS_Store 정리 완료"'
alias yazi='EDITOR=nvim yazi'

mc() { mkdir -p "$1" && cd "$1"; }                        # 디렉토리 생성 후 이동
fn() { find . -iname "*$1*" 2>/dev/null; }                # 파일명 검색
ds() { du -sh "${1:-.}" 2>/dev/null | sort -h; }          # 디렉토리 용량
pk() { ps aux | grep -i "$1" | grep -v grep | awk '{print $2}' | xargs kill -9; }  # 프로세스 종료

qq() { cd ~/.dotfiles; }
ww() { cd ~/.dotfolders; }

cd() {
    if [ -n "$*" ]; then builtin cd "$*" && eza -F --group-directories-first
    else                  builtin cd ~   && eza -F --group-directories-first
    fi
}


# ============================================================
# fzf 설정
# ============================================================
export FZF_DEFAULT_OPTS="--height 40% --layout=reverse --border=rounded --info=inline"

[ -f ~/.fzf.bash ] && source ~/.fzf.bash
if [ -d /usr/share/doc/fzf/examples ]; then
    [ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [ -f /usr/share/doc/fzf/examples/completion.bash ]   && source /usr/share/doc/fzf/examples/completion.bash
fi

alias ff='fzf'
alias vf='nvim $(fzf)'                                    # fzf로 파일 선택 후 nvim

# zz: zoxide 기록 기반 스마트 점프
zz() {
    local target
    target=$(zoxide query -l | head -n 50 | xargs -I {} fd . {} --max-depth 2 2>/dev/null \
        | fzf --prompt="Jump to (History) > " --exact --bind 'ctrl-k:up,ctrl-j:down')
    [[ -z "$target" ]] && return
    if   [[ -d "$target" ]]; then cd "$target"
    elif [[ -f "$target" ]]; then cd "$(dirname "$target")"
    fi
    echo -e "\033[32m→ $PWD\033[0m"
}

# cf: 현재 디렉토리 기반 fzf 탐색
cf() {
    local result query target
    result=$(fd --hidden --exclude .git -t f -t d . 2>/dev/null \
        | fzf --print-query --prompt='> ' --exact --bind 'ctrl-k:up,ctrl-j:down')
    [[ -z "$result" ]] && return
    query=$(echo "$result"  | head -1 | xargs)
    target=$(echo "$result" | sed -n '2p' | xargs)
    if [[ "$query" == ".." && -z "$target" ]]; then cd ..; cf; return; fi
    if [[ -n "$target" ]]; then
        if   [[ -d "$target" ]]; then cd "$target"
        elif [[ -f "$target" ]]; then cd "$(dirname "$target")"
        fi
    elif [[ -n "$query" ]]; then
        if   [[ -d "$query" ]]; then cd "$query"
        elif [[ -f "$query" ]]; then cd "$(dirname "$query")"
        fi
    fi
    echo -e "\033[32m→ $PWD\033[0m"
}


# ============================================================
# 패키지 관리 (Homebrew)
# ============================================================
u() {
    echo "=== System Update (Homebrew) ==="
    brew update && brew upgrade && brew upgrade --cask && brew cleanup
    echo "=== Update Completed ==="
}
alias uu='u'

alias bl='brew list'
bi()  { brew install "$1"; }
bu()  { brew uninstall "$1"; }

alias bcl='brew list --cask'
bci() { brew install --cask "$1"; }
bcu() { brew uninstall --cask "$1"; }


# ============================================================
# Infisical
# ============================================================
infs() {
    local path="${1:-/}"
    local token=$(/usr/bin/security find-generic-password -a "$USER" -s "INFISICAL_TOKEN" -w | /usr/bin/tr -d '\n')
    INFISICAL_TOKEN="$token" /opt/homebrew/bin/infisical secrets \
        --projectId=bc893247-af3f-4118-a8ec-bcb429338acb \
        --env=dev \
        --path="$path"
}


# ============================================================
# SSH 접속 자동화 (Master Key)
# ============================================================
_ssh_connect() {
    local user_name="$1" target_host="$2"
    local key_path="$HOME/.ssh/main_ssh_key"
    if [ ! -f "$key_path" ]; then
        echo -e "\033[0;31m[Error]\033[0m 마스터 키($key_path)가 없습니다."
        return 1
    fi
    echo -e "\033[0;32mConnecting to $target_host as $user_name...\033[0m"
    ssh -i "$key_path" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes "$user_name@$target_host"
}

pve()     { _ssh_connect "root" "pve"; }
xpve()     { _ssh_connect "x" "pve"; }
w1()      { _ssh_connect "x" "w1"; }
w2()      { _ssh_connect "x" "w2"; }
w3()      { _ssh_connect "x" "w3"; }
w5()      { _ssh_connect "x" "w5"; }
shorten() { _ssh_connect "x" "shorten"; }
stn()     { _ssh_connect "x" "shorten"; }
# ============================================================
# Yazi / zoxide
# ============================================================
y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    command yazi "$@" --cwd-file="$tmp"
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -f -- "$tmp"
}

if command -v zoxide > /dev/null; then
    eval "$(zoxide init zsh)"
fi


# ============================================================
# Docker
# ============================================================
alias d='docker'
alias dps='docker ps'                                     # 실행 중인 컨테이너
alias dpsa='docker ps -a'                                 # 전체 컨테이너
alias di='docker images'                                  # 이미지 목록
alias dex='docker exec -it'                               # 컨테이너 접속
alias dlog='docker logs -f'                               # 로그 스트림
dstop() { docker stop $(docker ps -q); }                  # 실행 중 전체 중지
alias dprune='docker system prune -af'                    # 미사용 리소스 정리

# ==========================================================
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
alias gbD='git branch -D'                                 # 브랜치 강제 삭제
alias gm='git merge'                                      # 브랜치 병합
alias gg='lazygit'                                        # lazygit 실행
alias gca='git commit -m "auto commit"'                   # 자동 메시지 커밋
alias gup='git add . && git commit -m "auto commit" && git push'
alias gst='git stash'                                     # 작업 임시 저장
alias gstp='git stash pop'                                # 임시 저장 복원
alias gstl='git stash list'                               # 임시 저장 목록
alias gr='git reset --hard'                               # 강제 초기화
alias grs='git reset --soft HEAD~1'                       # 최근 커밋 취소 (내용 유지)
alias gre='git restore'                                   # 파일 변경사항 복구
alias gres='git restore --staged'                         # 스테이징 취소
alias gclean='git clean -fd'                              # 미추적 파일 삭제

gc()   { git commit -m "$*"; }                            # 메시지와 함께 커밋

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
    local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    [[ -z "$branch" ]] && branch="main"
    echo -e "\033[0;33mResetting to origin/$branch...\033[0m"
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
# Git Gist
# ============================================================
# ggl              - 목록 20개
# ggd <ID>         - 삭제
# gga <file>       - 파일 직접 업로드
# gga <f1> <f2>    - 다중 파일 업로드
# ggaa             - 클립보드 업로드
# ggv <ID>         - 내용 터미널 출력
# ggv <ID> -raw    - 파일 원문만 출력
# ============================================================
alias ggl='gh gist list --limit 20'
alias ggd='gh gist delete'
alias gga='gh gist create'
alias ggaa='python3 /Users/x/.dotfolders/common/python/util/gistup/basic_srzst_gh.py'
alias ggv='gh gist view'


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

alias rcw="rclone rcd --rc-web-gui"  # rclone web gui
# ============================================================
# 프롬프트
# ============================================================
PROMPT='%n@%m %~ %# '

source $(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
# ============================================================
# Zsh ZLE: 프롬프트 전용 이동 / 단어 이동 / 삭제
# Windows Alt = macOS Option 감각 기준
# vim, nvim, less, ssh 내부에는 영향 없음
# ============================================================

# 기본 이동
bindkey '^[j' backward-char
bindkey '^[l' forward-char
bindkey '^[i' up-line-or-history
bindkey '^[k' down-line-or-history

# 단어 단위 이동
bindkey '^[u' backward-word
bindkey '^[o' forward-word

# 줄 처음 / 끝
bindkey '^[y' beginning-of-line
bindkey '^[p' end-of-line

# 글자 삭제
bindkey '^[h' backward-delete-char
bindkey '^[q' backward-delete-char
bindkey '^[w' delete-char
bindkey '^[m' delete-char

# 단어 단위 삭제
bindkey '^[^J' backward-kill-word
bindkey '^[^L' kill-word
