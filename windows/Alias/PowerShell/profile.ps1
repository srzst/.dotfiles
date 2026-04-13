# ============================================================
# Windows PowerShell 프로필
# ============================================================
# ============================================================
# [FIX] Scoop Shims & Path Priority Sync (Warp & WT)
# ============================================================
$scoopShims = "$env:USERPROFILE\scoop\shims"
if (Test-Path $scoopShims) {
    $currentPaths = $env:PATH -split ';' | Where-Object { $_ -ne $scoopShims -and $_ -ne "" }
    $env:PATH = ($scoopShims, ($currentPaths -join ';')) -join ';'
}
# ============================================================
# ============================================================
# 외부 도구 및 환경 변수 설정
# ============================================================
$nvimPath = "$env:LOCALAPPDATA\nvim-win64\bin"
if ((Test-Path $nvimPath) -and ($env:Path -notlike "*$nvimPath*")) {
    $env:Path += ";$nvimPath"
}

# Chocolatey 도우미 로드
$chocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $chocoProfile) { Import-Module $chocoProfile }

# Infisical secrets 함수
function infs {
    param(
        [string]$Path = ""  # 기본: 루트
    )

    # 경로가 비어있으면 루트(/)로, 아니면 /$Path
    $finalPath = if ($Path) { "/$Path" } else { "/" }

    infisical secrets `
        --projectId=bc893247-af3f-4118-a8ec-bcb429338acb `
        --env=dev `
        --path=$finalPath
}

# ============================================================
# 에디터 및 설정 파일 관리
# ============================================================
function v { if ($args.Count -eq 0) { nvim . } else { nvim $args } }
# FIX: vi도 nvim으로 통일
function vi { if ($args.Count -eq 0) { nvim . } else { vim $args } }
function nrc { Set-Location "$env:LOCALAPPDATA\nvim"; nvim . }
function vrc { nvim $PROFILE }
function src { . $PROFILE }
function srcrc { . $PROFILE }
# ============================================================
# [파일 및 디렉토리 관리] eza 기반 최적화 (Windows)
# ============================================================
# 기본 리스트 (아이콘 제외, 폴더 우선 정렬)
function l { eza -alF --group-directories-first $args }
function ll { eza -alF --group-directories-first --git $args }
function la { eza -aF --group-directories-first $args }
function lt { eza -alF --sort=modified $args }

# 트리 구조 (아이콘 제외, 숨김 파일 포함, .git 및 ignore 반영)
function et { eza --tree -a -I ".git" --git-ignore $args }
function et1 { eza --tree --level=1 -a -I ".git" --git-ignore $args }
function et2 { eza --tree --level=2 -a -I ".git" --git-ignore $args }
function et3 { eza --tree --level=3 -a -I ".git" --git-ignore $args }

# fzf
function ff { fzf }
function vf { nvim $(fzf) }
# function cf { cd $(fd --type d | fzf) }
# # cf: fzf 내에서 Alt+Up으로 상위 폴더 이동 기능 추가 (PowerShell용)



# function cf {
#     $query = fd --type d | fzf --print-query
#     $lines = $query -split "`n"
#     $input = $lines[0].Trim()
#     $dir = if ($lines.Count -gt 1) { $lines[1].Trim() } else { "" }

#     if ($input -eq ".." -and $dir -eq "") {
#         Set-Location ..
#         cf
#     } elseif ($dir -ne "") {
#         Set-Location $dir
#     }
# }


# function cf {
#     $result = fd --hidden --exclude .git -t f -t d . 2>$null `
#         | fzf --print-query `
#               --layout=reverse `
#               --info=inline `
#               --bind 'ctrl-k:up,ctrl-j:down' `
#               --prompt='> ' `
#               --exact   # ← 이 옵션 추가 (정확한 매칭 강화)

#     if (-not $result) { return }

#     $lines = $result -split "`r?`n"
#     $query = $lines[0].Trim()
#     $target = if ($lines.Count -gt 1) { $lines[1].Trim() } else { $null }

#     if ($query -eq ".." -and -not $target) {
#         Set-Location ..
#         cf
#         return
#     }

#     if ($target) {
#         $target = $target.Trim()
#         if (Test-Path $target -PathType Container) {
#             Set-Location $target
#             Write-Host "→ $PWD" -ForegroundColor Green
#         }
#         elseif (Test-Path $target -PathType Leaf) {
#             $parent = Split-Path $target -Parent
#             if ($parent) {
#                 Set-Location $parent
#                 Write-Host "→ $PWD (파일 선택)" -ForegroundColor Green
#             }
#         }
#     }
# }


function cf {
    $fzfArgs = @(
        '--print-query'
        '--layout=reverse-list'   # ← 검색 입력창을 하단으로 배치
        '--info=inline'
        '--bind', 'ctrl-k:up,ctrl-j:down'
        '--prompt=> '
        '--exact'
    )

    $result = fd --hidden --exclude .git -t f -t d . 2>$null | fzf @fzfArgs

    if (-not $result) { return }

    $lines = $result -split "`r?`n"
    $query = $lines[0].Trim()
    $target = if ($lines.Count -gt 1) { $lines[1].Trim() } else { $null }

    if ($query -eq ".." -and -not $target) {
        Set-Location ..
        cf
        return
    }

    if ($target) {
        $target = $target.Trim()
        if (Test-Path $target -PathType Container) {
            Set-Location $target
            Write-Host "→ $PWD" -ForegroundColor Green
        }
        elseif (Test-Path $target -PathType Leaf) {
            $parent = Split-Path $target -Parent
            if ($parent) {
                Set-Location $parent
                Write-Host "→ $PWD (파일 선택)" -ForegroundColor Green
            }
        }
    }
}


# 시스템 유틸리티/ff
function c { Clear-Host }
function cc { Clear-Host }
function e { Exit }
function ee { Exit }
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function h { Set-Location ~ }

# 디렉토리 생성 후 이동
function mc ($path) { 
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path 
}

# 안전한 파일 조작 (rm 별칭 재정의)
if (Test-Path "Alias:rm") { Remove-Item "Alias:rm" -Force }
function rm { Remove-Item -Path $args -Force -Recurse -Verbose }

# 사용자 지정 경로 이동 (이동 후 eza 자동 실행)
function qq { Set-Location ~/.dotfiles; eza -F --group-directories-first }
function ww { Set-Location ~/.dotfolders; eza -F --group-directories-first }

# [추가 기능] cd 실행 후 자동 eza
function cd {
    param([string]$path)
    if ($path) { Set-Location $path } else { Set-Location ~ }
    eza -F --group-directories-first
}
# ============================================================

# ============================================================
# 패키지 관리자 별칭 및 함수
# ============================================================
function u {
    Write-Host "=== System Update Started ===" -ForegroundColor Green
    if (Get-Command choco -ErrorAction SilentlyContinue) { Write-Host "[Chocolatey]"; gsudo choco upgrade all -y }
    if (Get-Command scoop -ErrorAction SilentlyContinue) { Write-Host "[Scoop]"; scoop update * }
    if (Get-Command winget -ErrorAction SilentlyContinue) { Write-Host "[Winget]"; winget upgrade --all }
}
function uu { u }

# [Chocolatey] - 관리자 권한(gsudo) 필수
function cl { choco list }
function cll { choco list }
function ci { param($p) gsudo choco install $p -y }
function cu { param($p) gsudo choco uninstall $p -y }

# Scoop - 기존 충돌 별칭 제거 후 재정의
if (Get-Alias si -ErrorAction SilentlyContinue) { Remove-Item Alias:si -Force }
if (Get-Alias su -ErrorAction SilentlyContinue) { Remove-Item Alias:su -Force }
if (Get-Alias sl -ErrorAction SilentlyContinue) { Remove-Item Alias:sl -Force }
function sl { scoop list }
function sll { scoop list }
function si { if ($args.Count -gt 0) { scoop install @args } else { Write-Host "설치할 앱 이름을 입력하세요." -ForegroundColor Yellow } }
function su { if ($args.Count -gt 0) { scoop uninstall @args } else { Write-Host "삭제할 앱 이름을 입력하세요." -ForegroundColor Yellow } }

# [Winget]
function wl { winget list }
function wll { winget list }
function wi { param($p) winget install $p }
function wu { param($p) winget uninstall $p }

# ============================================================
# gita 관련 함수
# ============================================================
function gtl { gita ll }
function gtpl { gita pull }
function gtp { gita super push }
function gtac { $msg = if ($args[0]) { $args[0] } else { "auto commit" }; gita super add -A; gita super commit -m $msg }
function gtacp { $msg = if ($args[0]) { $args[0] } else { "auto commit" }; gita super add -A; gita super commit -m $msg; gita super push }

# ============================================================
# Git 함수 (최신 문법, 태그 관리, 자동화 함수 포함 - PowerShell용)
# ============================================================

# 기본 별칭 및 상태 확인
function gi    { git init -b main }                        # 메인 브랜치명 지정하여 저장소 초기화
function gs    { git status }                              # 현재 변경 상태 확인
function gss   { git status -s }                           # 상태 요약 확인
function ga    { git add . }                               # 현재 폴더 변경사항 스테이징
function gaa   { git add --all }                           # 모든 변경사항 스테이징
function gp    { git push }                                # 원격 저장소에 푸시
function gpl   { git pull }                                # 원격 저장소에서 풀
function gpf   { git push origin --force-with-lease }      # 안전한 강제 푸시

# 로그 및 브랜치 관리 (최신 switch 반영)
function gl    { git log --oneline -n 10 }                 # 한 줄 로그 10개 확인
function gll   { git log --oneline --graph --all }         # 전체 브랜치 로그 그래프 확인
function gd    { git diff }                                # 작업 디렉토리 변경사항 비교
function gdc   { git diff --staged }                       # 스테이징된 변경사항 비교
function gb    { git branch }                              # 로컬 브랜치 목록 확인
function gba   { git branch -a }                           # 모든 브랜치(원격 포함) 확인
function gsw   { param([string]$b) git switch $b }         # 브랜치 전환 (checkout 대체)
function gsc   { param([string]$b) git switch -c $b }      # 새 브랜치 생성 및 전환
function gbd   { param([string]$b) git branch -d $b }      # 브랜치 삭제
function gbD   { param([string]$b) git branch -D $b }      # 브랜치 강제 삭제
function gm    { param([string]$b) git merge $b }          # 브랜치 병합
function gg    { lazygit $args }                           # lazygit 실행

# ============================================================
# 태그 관리
# ============================================================

# gt: 태그 목록 확인
function gt { git tag }

# gtd: 특정 태그 삭제
function gtd { param([string]$t) git tag -d $t }

# gta: 현재 커밋에 태그만 붙이기 (날짜_시간(메시지) 형식)
function gta {
    param([Parameter(Mandatory=$true)][string]$m)
    $msg_clean = $m -replace ' ', '_'
    $timestamp = Get-Date -Format "yyMMdd_HHmm"
    $tag_name = "${timestamp}($msg_clean)"
    git tag -a $tag_name -m $m
    Write-Host "✅ 태그 생성 완료: $tag_name" -ForegroundColor Green
}

# gt1: 빈 커밋 생성 후 태그 백업 (변경사항 없어도 스냅샷 가능)
function gt1 {
    param([Parameter(Mandatory=$true)][string]$m)
    $msg_clean = $m -replace ' ', '_'
    $timestamp = Get-Date -Format "yyMMdd_HHmm"
    $tag_name = "${timestamp}($msg_clean)"
    git commit --allow-empty -m "checkpoint: $m"
    git tag -a $tag_name -m $m
    Write-Host "✅ 태그 백업 완료: $tag_name" -ForegroundColor Green
}

# gt2: 특정 태그에서 복원
# 사용: gt2 태그명                                    → 전체 복원
# 사용: gt2 태그명 파일명                             → 단일 파일 복원
# 사용: gt2 태그명 파일명1 파일명2 파일명3            → 복수 파일 복원
function gt2 {
    param(
        [Parameter(Mandatory=$true)][string]$tag,
        [Parameter(ValueFromRemainingArguments=$true)][string[]]$files
    )
    $root = git rev-parse --show-toplevel
    if ($files.Count -gt 0) {
        foreach ($f in $files) {
            $rel = [System.IO.Path]::GetRelativePath($root, (Resolve-Path $f))
            git -C $root restore --source=$tag $rel
            Write-Host "✅ 복원 완료: $f (from $tag)" -ForegroundColor Green
        }
    } else {
        git -C $root restore --source=$tag .
        Write-Host "✅ 전체 복원 완료 (from $tag)" -ForegroundColor Green
    }
}

# gt3: 특정 태그 삭제
function gt3 {
    param([Parameter(Mandatory=$true)][string]$tag)
    git tag -d $tag
    Write-Host "✅ 태그 삭제 완료: $tag" -ForegroundColor Green
}

# gt4: 등록된 태그 모두 삭제
function gt4 {
    $confirm = Read-Host "⚠️  모든 태그를 삭제합니다. 계속할까요? (y/N)"
    if ($confirm -match '^[Yy]$') {
        git tag | ForEach-Object { git tag -d $_ }
        Write-Host "✅ 모든 태그 삭제 완료" -ForegroundColor Green
    } else {
        Write-Host "취소됨"
    }
}

# ============================================================
# Git 파일 단위 백업/복원 함수 (단일 파일 전용)
# ============================================================

# g1: 특정 파일 백업 커밋
# 사용: g1 파일명            → 기본 메시지: 260412_2210 수정전
# 사용: g1 파일명 "메시지"   → 커스텀 메시지
function g1 {
    param(
        [Parameter(Mandatory=$true)][string]$file,
        [string]$msg = "$(Get-Date -Format 'yyMMdd_HHmm') 수정전"
    )
    if (-not (Test-Path $file)) {
        Write-Host "❌ 파일을 찾을 수 없습니다: $file" -ForegroundColor Red
        return
    }
    $root = git rev-parse --show-toplevel
    $rel = [System.IO.Path]::GetRelativePath($root, (Resolve-Path $file))
    Add-Content $file ""
    git -C $root add $rel
    git -C $root commit -m "backup: $rel - $msg"
    Write-Host "✅ 저장: $rel - $msg" -ForegroundColor Green
}

# g2: 해시만으로 파일 자동 인식 후 복원
# 사용: g2 커밋해시
function g2 {
    param([Parameter(Mandatory=$true)][string]$hash)
    $root = git rev-parse --show-toplevel
    $rel = git -C $root show --name-only --format="" $hash | Select-Object -First 1
    if (-not $rel) {
        Write-Host "❌ 해시를 찾을 수 없습니다." -ForegroundColor Red
        return
    }
    git -C $root restore --source=$hash $rel
    Write-Host "✅ 복원: $rel" -ForegroundColor Green
}

# ============================================================
# Git 태그 백업/복원 함수 사용법
# ============================================================
#
# [gt] 태그 목록 확인
#   gt
#
# [gta] 현재 커밋에 태그만 붙이기
#   gta "메시지"
#   gta "functions.php 수정 완료"
#   → 260412_2210(functions.php_수정_완료)
#
# [gt1] 빈 커밋 생성 후 태그 백업 (변경사항 없어도 스냅샷 가능)
#   gt1 "메시지"
#   gt1 "functions.php 수정 전"
#   → 260412_2210(functions.php_수정_전)
#
# [gt2] 특정 태그에서 복원
#   gt2 태그명                                      # 전체 복원
#   gt2 태그명 functions.php                        # 단일 파일 복원
#   gt2 태그명 functions.php header.php style.css   # 복수 파일 복원
#
# [gt3] 특정 태그 삭제
#   gt3 태그명
#   gt3 260412_2210(functions.php_수정_전)
#
# [gt4] 등록된 태그 모두 삭제
#   gt4
#
# ============================================================
# Git 파일 단위 백업/복원 함수 사용법 (단일 파일 전용)
# ============================================================
#
# [g1] 특정 파일 백업 커밋
#   g1 파일명              # 기본 메시지: 260412_2210 수정전
#   g1 파일명 "메시지"     # 커스텀 메시지
#   g1 ytb_dl.py
#   g1 ytb_dl.py "기능1 추가 전"
#
# [g2] 해시로 파일 복원 (파일명 자동 인식)
#   g2 커밋해시
#   g2 9c24313
#
# [gl] 백업 이력 확인
#   gl
#   → 9c24313 backup: common/python/util/ytb_dl/ytb_dl.py - 260412_2210 수정전
# ============================================================

# 상태 보존 및 복구 (최신 restore 반영)
function gst   { git stash }                               # 작업 임시 저장
function gstp  { git stash pop }                           # 임시 저장 불러오기 및 삭제
function gstl  { git stash list }                          # 임시 저장 목록 확인
function gr    { param([string]$ref) git reset --hard $ref } # 특정 시점으로 강제 초기화
function grs   { git reset --soft HEAD~1 }                 # 최근 커밋 취소 (내용 유지)
function gre   { param([string]$f) git restore $f }        # 파일 변경사항 복구 (checkout -- 대체)
function gres  { param([string]$f) git restore --staged $f } # 스테이징 취소
function gclean { git clean -fd }                          # 추적되지 않는 파일 삭제





# ------------------------------------------------------------
# Git 자동화 함수 (복사+붙여넣기 본문 지원 및 폴더 생성)
# ------------------------------------------------------------

# gc: 커밋 메시지와 함께 커밋
function gc    { git commit -m "$args" }

# gca: 자동 메시지로 커밋
function gca   { git commit -m "auto commit" }

# gac: 제목($msg)과 본문($body)을 구분하여 커밋 (복사+붙여넣기 최적화)
function gac {
    param([string]$msg = "auto commit", [string]$body)
    git add -A
    if ($body) {
        git commit -m $msg -m $body
    } else {
        git commit -m $msg
    }
}

# gacp: 제목($msg)과 본문($body) 커밋 후 푸시
function gacp {
    param([string]$msg = "auto commit", [string]$body)
    gac $msg $body
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (!$branch) { $branch = "main" }
    git push origin $branch
}

# gup: 고정 메시지로 즉시 푸시
function gup { git add .; git commit -m "auto commit"; git push }

# gfo: 원격 기준 강제 초기화
function gfo {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (!$branch) { $branch = "main" }
    Write-Host "Fetching from origin and resetting to $branch..." -ForegroundColor Yellow
    git fetch origin
    git reset --hard "origin/$branch"
}

# mrd: 폴더 생성 + README.md 생성
function mrd {
    param([string]$name)
    New-Item -ItemType Directory -Path $name -Force | Out-Null
    New-Item -ItemType File -Path "$name\README.md" -Value "# $name" -Force | Out-Null
    Write-Host "Folder '$name' created with README.md" -ForegroundColor Green
}

# mrdpy: 폴더 생성 + README.md + basic.py 생성
function mrdpy {
    param([string]$name)
    mrd $name
    New-Item -ItemType File -Path "$name\basic.py" -Force | Out-Null
    Write-Host "Folder '$name' created with README.md and basic.py" -ForegroundColor Green
}
# ============================================================


# ============================================================
# 시스템 유틸리티
# ============================================================
function s    { gsudo }
function sudo { gsudo }
function port { param($p) if ($p) { netstat -ano | findstr ":$p" } else { netstat -ano | findstr LISTENING } }
function myip { Invoke-RestMethod -Uri "https://ifconfig.me" }
# FIX: ff 로 통일 (fzf f 단축키 충돌 방지 - GitBash와 일관성)
# function ff   { param($name) Get-ChildItem -Recurse -Filter "*$name*" -ErrorAction SilentlyContinue }
function fn {
    param($name)
    if (!$name) { Write-Host "how to use: ff <search term>" -ForegroundColor Yellow; return }
    Get-ChildItem -Recurse -Filter "*$name*" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|go\\pkg\\mod)\\' }
}
# ============================================================
# SSH 접속 자동화 (Master SSH Key 방식)
# ============================================================
function _ssh_connect {
    param (
        [string]$user_name,
        [string]$target_host
    )
    
    $key_path = "$HOME\.ssh\main_ssh_key"

    # 마스터 키 존재 확인
    if (!(Test-Path $key_path)) {
        Write-Host "[Error] 마스터 키($key_path)가 없습니다." -ForegroundColor Red
        return
    }

    Write-Host "Connecting to $target_host as $user_name (via Master Key)..." -ForegroundColor Green
    
    ssh -i "$key_path" `
        -o StrictHostKeyChecking=no `
        -o UserKnownHostsFile=/dev/null `
        -o IdentitiesOnly=yes `
        "$user_name@$target_host"
}

# 서버별 함수 등록
function pve { _ssh_connect "root" "pve" }
function w1  { _ssh_connect "x" "w1" }
function w2  { _ssh_connect "x" "w2" }
function w3  { _ssh_connect "x" "w3" }
function w5  { _ssh_connect "x" "w5" }
function shorten { _ssh_connect "x" "shorten" }
function stn { _ssh_connect "x" "shorten" }
function wtt  { _ssh_connect "x" "100.107.192.115" }
# ============================================================
# 외부 도구 초기화 (Yazi, zoxide)
# ============================================================

# Yazi: 종료 후 경로 유지
function y {
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    if (Test-Path $tmp) {
        $cwd = Get-Content $tmp
        if ($cwd -and $cwd -ne $pwd.Path) {
            if (Test-Path $cwd) { Set-Location $cwd }
        }
        Remove-Item $tmp
    }
}
# zoxide 초기화 (에러 방지 처리)
# ============================================================
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    $zoxideInit = zoxide init powershell | Out-String
    if ($zoxideInit) { Invoke-Expression $zoxideInit }
}
# ============================================================

$env:PATH += ";C:\Users\x\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code\2.1.70"

# ============================================================
# WezTerm + PowerShell 컬러 활성화 (LS_COLORS 대체)
# ============================================================
# $PSStyle.FileInfo.Directory = "`e[34m"     # 디렉토리 - 파랑
# $PSStyle.FileInfo.Executable = "`e[32m"    # 실행파일 - 녹색
# $PSStyle.FileInfo.Symlink = "`e[36m"       # 심볼릭링크 - 청록
$env:TERM = 'xterm-256color'
# ============================================================

Set-PSReadLineOption -Colors @{
    Default   = '#ffffff'
    Command = '#98c379'
    # Command   = '#00ff00'
    Parameter = '#ffff00'
    String    = '#00ffff'
    Variable  = '#ff6e6e'
    Comment   = '#888888'
    Keyword   = '#ff0000'
    Error     = '#ff0000'
}
$env:EZA_COLORS = "di=1;34:ln=1;36:ex=1;32:*.zip=1;31:*.ps1=1;33:*.lua=1;32:*.md=1;35:*.json=1;33"

Set-PSReadLineKeyHandler -Chord Ctrl+U -Function BackwardDeleteLine
