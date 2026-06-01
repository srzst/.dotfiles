# /Users/x/.dotfiles/windows/Alias/PowerShell/profile.ps1
# 수정 직전: 2026-04-13(월) https://gist.github.com/srzst/034e5b1763331f9e5f9ab2098627a737
# 정리 직전: 2026-04-14(화) https://gist.github.com/srzst/f8eacdb3069490f838f1e84a438767ac
# ============================================================
# Windows PowerShell Profile
# ============================================================

# VS Code 터미널 코드 페이지 강제 설정
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# ============================================================
# [FIX] Conflict Aliases (사용자 정의 별칭과 충돌하는 시스템 별칭 사전 제거)
# ============================================================
$conflict_aliases = @(
    "rm",   # Remove-Item (사용자 정의로 덮어씀)
    "sl",   # Set-Location (scoop list 용도로 재정의)
    "si",   # Start-Process (scoop install 용도로 재정의)
    "su",   # 없음 (scoop uninstall 용도로 재정의)
    "zz",   # 없음 (zoxide 점프 용도로 재정의)
    "gs",   # 없음 (git status 용도로 재정의)
    "gsv",  # Get-Service
    "sc",   # Set-Content
    "gt"    # 없음 (git tag 용도로 재정의)
)
foreach ($alias in $conflict_aliases)
{
    if (Get-Alias $alias -ErrorAction SilentlyContinue)
    {
        Remove-Item "Alias:$alias" -Force
    }
}


# ============================================================
# [FIX] Scoop Shims Path Priority
# ============================================================
$scoopShims = "$env:USERPROFILE\scoop\shims"
if (Test-Path $scoopShims)
{
    $currentPaths = $env:PATH -split ';' | Where-Object { $_ -ne $scoopShims -and $_ -ne "" }
    $env:PATH = ($scoopShims, ($currentPaths -join ';')) -join ';'
}


# ============================================================
# 외부 도구 및 환경 변수
# ============================================================
$nvimPath = "$env:LOCALAPPDATA\nvim-win64\bin"
if ((Test-Path $nvimPath) -and ($env:Path -notlike "*$nvimPath*"))
{
    $env:Path += ";$nvimPath"
}
$env:PATH += ";C:\Users\x\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code\2.1.70"

$chocoProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $chocoProfile)
{ Import-Module $chocoProfile
}


# ============================================================
# 에디터 및 설정 파일
# ============================================================
function v
{ if ($args.Count -eq 0)
    { nvim .
    } else
    { nvim $args
    }
}
function vi
{ if ($args.Count -eq 0)
    { nvim .
    } else
    { vim $args
    }
}
function nrc
{ Set-Location "$env:LOCALAPPDATA\nvim"; nvim .
}  # nvim 설정 열기
function vrc
{ nvim $PROFILE
}                                   # 프로필 편집
function src
{ . $PROFILE
}                                      # 프로필 재로드
function srcrc
{ . $PROFILE
}


# ============================================================
# 파일 및 디렉토리 관리 (eza)
# ============================================================
function l
{ eza -alF --group-directories-first $args
}
function ll
{ eza -alF --group-directories-first --git $args
}    # git 상태 포함
function la
{ eza -aF --group-directories-first $args
}           # 숨김 파일 포함
function lt
{ eza -alF --sort=modified $args
}                    # 수정 시간순

function et
{ eza --tree -a -I ".git" --git-ignore $args
}
function et1
{ eza --tree --level=1 -a -I ".git" --git-ignore $args
}
function et2
{ eza --tree --level=2 -a -I ".git" --git-ignore $args
}
function et3
{ eza --tree --level=3 -a -I ".git" --git-ignore $args
}


# ============================================================
# 시스템 유틸리티
# ============================================================
function c
{ Clear-Host
}
function cl
{ claude
}
function cc
{ Clear-Host
}
function e
{ Exit
}
function ee
{ Exit
}
function ..
{ Set-Location ..
}
function ...
{ Set-Location ../..
}
function h
{ Set-Location ~
}
function s
{ gsudo
}
function sudo
{ gsudo
}

function port
{ param($p) if ($p)
    { netstat -ano | findstr ":$p"
    } else
    { netstat -ano | findstr LISTENING
    }
}  # 포트 확인
function myip
{ Invoke-RestMethod -Uri "https://ifconfig.me"
}    # 외부 IP

function mc ($path)
{
    New-Item -ItemType Directory -Path $path -Force | Out-Null
    Set-Location $path
}

function fn
{
    param($name)
    if (!$name)
    { Write-Host "사용법: fn <검색어>" -ForegroundColor Yellow; return
    }
    Get-ChildItem -Recurse -Filter "*$name*" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|go\\pkg\\mod)\\' }
}

function rm
{ Remove-Item -Path $args -Force -Recurse -Verbose
}

function qq
{ Set-Location ~/.dotfiles;   eza -F --group-directories-first
}
function ww
{ Set-Location ~/.dotfolders; eza -F --group-directories-first
}

function w0
{ Set-Location ~/W0; eza -F --group-directories-first
}

function d0
{ Set-Location ~/D0; eza -F --group-directories-first
}

function util
{ Set-Location ~/.dotfolders/common/python/util; eza -F --group-directories-first
}

function wp
{ Set-Location ~/.dotfolders/common/python/util/wordpress; eza -F --group-directories-first
}

function cd
{
    param([string]$path)
    if ($path)
    { Set-Location $path
    } else
    { Set-Location ~
    }
    eza -F --group-directories-first
}


# ============================================================
# fzf 설정
# ============================================================
$env:FZF_DEFAULT_OPTS = "--height 40% --layout=reverse --border=rounded --info=inline"

function ff
{ fzf
}
function vf
{ nvim $(fzf)
}                                        # fzf로 파일 선택 후 nvim

# zz: zoxide 기록 기반 스마트 점프
function zz
{
    $zPaths = zoxide query -l | Select-Object -First 50
    $target = $zPaths | ForEach-Object { fd . $_ --max-depth 2 2>$null } |
        fzf --prompt="Jump to (History) > " --exact --bind 'ctrl-k:up,ctrl-j:down'
    if (-not $target)
    { return
    }
    if (Test-Path $target -PathType Container)
    { Set-Location $target
    } elseif (Test-Path $target -PathType Leaf)
    { Set-Location (Split-Path $target -Parent)
    }
    Write-Host "→ $PWD" -ForegroundColor Green
}

# cf: 현재 디렉토리 기반 fzf 탐색
function cf
{
    $result = fd --hidden --exclude .git -t f -t d . 2>$null | fzf `
        '--print-query' '--layout=reverse' '--info=inline' `
        '--bind' 'ctrl-k:up,ctrl-j:down' '--prompt=> ' '--exact'
    if (-not $result)
    { return
    }
    $lines  = $result -split "`r?`n"
    $query  = $lines[0].Trim()
    $target = if ($lines.Count -gt 1)
    { $lines[1].Trim()
    } else
    { $null
    }
    if ($query -eq ".." -and -not $target)
    { Set-Location ..; cf; return
    }
    if ($target)
    {
        if (Test-Path $target -PathType Container)
        { Set-Location $target
        } elseif (Test-Path $target -PathType Leaf)
        { Set-Location (Split-Path $target -Parent)
        }
        Write-Host "→ $PWD" -ForegroundColor Green
    }
}


# ============================================================
# 패키지 관리자
# ============================================================
function u
{
    Write-Host "=== System Update ===" -ForegroundColor Green
    if (Get-Command choco  -ErrorAction SilentlyContinue)
    { Write-Host "[Chocolatey]"; gsudo choco upgrade all -y
    }
    if (Get-Command scoop  -ErrorAction SilentlyContinue)
    { Write-Host "[Scoop]";      scoop update *
    }
    if (Get-Command winget -ErrorAction SilentlyContinue)
    { Write-Host "[Winget]";     winget upgrade --all
    }
}
function uu
{ u
}

# Chocolatey
function cl
{ choco list
}
function cll
{ choco list
}
function ci
{ param($p) gsudo choco install $p -y
}
function cu
{ param($p) gsudo choco uninstall $p -y
}

# Scoop
function sl
{ scoop list
}
function sll
{ scoop list
}
function si
{ if ($args.Count -gt 0)
    { scoop install @args
    } else
    { Write-Host "설치할 앱 이름을 입력하세요." -ForegroundColor Yellow
    }
}
function su
{ if ($args.Count -gt 0)
    { scoop uninstall @args
    } else
    { Write-Host "삭제할 앱 이름을 입력하세요." -ForegroundColor Yellow
    }
}

# # Winget
# function wl
# { winget list
# }
# function wll
# { winget list
# }
# function wi
# { param($p) winget install $p
# }
# function wu
# { param($p) winget uninstall $p
# }
#
# Winget
$WingetManagedFile = "$HOME\.dotfolders\windows\winget\packages.txt"

function _winget_ensure_managed_file
{
    $dir = Split-Path $WingetManagedFile
    if (!(Test-Path $dir))
    {
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
    }

    if (!(Test-Path $WingetManagedFile))
    {
        New-Item -ItemType File -Force -Path $WingetManagedFile | Out-Null
    }
}

function _winget_get_managed_ids
{
    _winget_ensure_managed_file

    Get-Content $WingetManagedFile -ErrorAction SilentlyContinue |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ -and !$_.StartsWith("#") }
}

function _winget_add_managed
{
    param([Parameter(Mandatory=$true)][string]$Id)

    _winget_ensure_managed_file

    $existing = _winget_get_managed_ids

    if ($existing -notcontains $Id)
    {
        Add-Content $WingetManagedFile $Id
        Write-Host "✅ winget 관리 목록에 추가됨: $Id" -ForegroundColor Green
    }
    else
    {
        Write-Host "이미 winget 관리 목록에 있음: $Id" -ForegroundColor DarkGray
    }
}

function wl
{
    $ids = _winget_get_managed_ids

    if (!$ids)
    {
        Write-Host "winget 관리 목록이 비어 있습니다: $WingetManagedFile" -ForegroundColor Yellow
        Write-Host "wi <패키지ID> 로 설치하면 자동 추가됩니다." -ForegroundColor DarkGray
        return
    }

    foreach ($id in $ids)
    {
        $result = winget list --id $id --exact 2>&1

        if ($LASTEXITCODE -eq 0 -and ($result -match [regex]::Escape($id)))
        {
            $result
        }
        else
        {
            Write-Host "[missing] $id" -ForegroundColor Red
        }
    }
}
function wll
{
    winget list
}

function wle
{
    _winget_ensure_managed_file
    nvim $WingetManagedFile
}

# 기존 wi 별칭은 주석 처리
# function wi
# { param($p) winget install $p
# }

function wi
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id
    )

    winget install --id $Id --exact --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -eq 0)
    {
        _winget_add_managed $Id
    }
    else
    {
        Write-Host "❌ 설치 실패. 관리 목록에는 추가하지 않았습니다: $Id" -ForegroundColor Red
    }
}

function wu
{
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id
    )

    winget uninstall --id $Id --exact

    if ($LASTEXITCODE -eq 0 -and (Test-Path $WingetManagedFile))
    {
        $remaining = Get-Content $WingetManagedFile |
            ForEach-Object { $_.Trim() } |
            Where-Object { $_ -and $_ -ne $Id }

        Set-Content -Path $WingetManagedFile -Value $remaining
        Write-Host "✅ winget 관리 목록에서 제거됨: $Id" -ForegroundColor Green
    }
}
# ============================================================
# Infisical
# ============================================================
function infs
{
    param([string]$Path = "")
    $finalPath = if ($Path)
    { "/$Path"
    } else
    { "/"
    }
    infisical secrets `
        --projectId=bc893247-af3f-4118-a8ec-bcb429338acb `
        --env=dev `
        --path=$finalPath
}


# ============================================================
# SSH 접속 자동화 (Master Key)
# ============================================================
function _ssh_connect
{
    param([string]$user_name, [string]$target_host)
    $key_path = "$HOME\.ssh\main_ssh_key"
    if (!(Test-Path $key_path))
    {
        Write-Host "[Error] 마스터 키($key_path)가 없습니다." -ForegroundColor Red
        return
    }
    Write-Host "Connecting to $target_host as $user_name..." -ForegroundColor Green
    ssh -i "$key_path" -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes "$user_name@$target_host"
}

function pve
{ _ssh_connect "root" "pve"
}
function xpve
{ _ssh_connect "x" "pve"
}
function w1
{ _ssh_connect "x" "w1"
}
function w2
{ _ssh_connect "x" "w2"
}
function w3
{ _ssh_connect "x" "w3"
}
function w5
{ _ssh_connect "x" "w5"
}
function shorten
{ _ssh_connect "x" "shorten"
}
function stn
{ _ssh_connect "x" "shorten"
}
function wtt
{ _ssh_connect "x" "100.107.192.115"
}

# ============================================================
# Yazi / zoxide
# ============================================================
function y
{
    $tmp = [System.IO.Path]::GetTempFileName()
    yazi $args --cwd-file="$tmp"
    if (Test-Path $tmp)
    {
        $cwd = Get-Content $tmp
        if ($cwd -and $cwd -ne $pwd.Path)
        {
            if (Test-Path $cwd)
            { Set-Location $cwd
            }
        }
        Remove-Item $tmp
    }
}

if (Get-Command zoxide -ErrorAction SilentlyContinue)
{
    $zoxideInit = zoxide init powershell | Out-String
    if ($zoxideInit)
    { Invoke-Expression $zoxideInit
    }
}


# ============================================================
# 터미널 색상
# ============================================================
$env:TERM = 'xterm-256color'
$env:EZA_COLORS = "di=1;34:ln=1;36:ex=1;32:*.zip=1;31:*.ps1=1;33:*.lua=1;32:*.md=1;35:*.json=1;33"

Set-PSReadLineOption -Colors @{
    Default   = '#ffffff'
    Command   = '#98c379'
    Parameter = '#ffff00'
    String    = '#00ffff'
    Variable  = '#ff6e6e'
    Comment   = '#888888'
    Keyword   = '#ff0000'
    Error     = '#ff0000'
}

Set-PSReadLineKeyHandler -Chord Ctrl+U -Function BackwardDeleteLine


# ============================================================
# gita
# ============================================================
function gtl
{ gita ll
}                                         # 전체 저장소 상태
function gtpl
{ gita pull
}                                       # 전체 저장소 일괄 pull
function gtps
{ gita super push
}                                 # 전체 저장소 일괄 push (기존 gtp 대체 가능)
function gtp
{ gita super push
}

# gta: 특정 저장소 애드 + 커밋 + 푸시 (gita shell 직접 연동)
# 사용법: gta .dotfolders "제목" "설명"
function gta
{
    param([Parameter(Mandatory=$true)][string]$repo, [string]$title = "auto commit ", [string]$body)

    Write-Host "→ Processing repository: $repo " -ForegroundColor Cyan

    # 1. Add
    gita shell $repo git add -A

    # 2. Commit (백틱으로 따옴표 감싸기 유지)
    if ($body)
    {
        gita shell $repo git commit -m "`"$title`"" -m "`"$body`""
    } else
    {
        gita shell $repo git commit -m "`"$title`""
    }

    # 3. Push (gita shell 내에서 직접 실행)
    Write-Host "→ Pushing to remote... " -ForegroundColor Green
    gita shell $repo git push
}
# gtacp: 전체 저장소 일괄 애드 + 커밋 + 푸시
function gtacp
{
    $msg = if ($args[0])
    { $args[0]
    } else
    { "auto commit "
    }
    gita super add -A
    gita super commit -m $msg
    gita super push
}
# ============================================================
# Git 기본
# ============================================================
function gi
{ git init -b main
}                                # main 브랜치로 초기화
function gs
{ git status
}                                      # 변경 상태 확인
function gss
{ git status -s
}                                   # 상태 요약
function ga
{ git add .
}                                       # 현재 폴더 스테이징
function gaa
{ git add --all
}                                   # 전체 스테이징
function gp
{ git push
}                                        # 푸시
function gpl
{ git pull
}                                        # 풀
function gpf
{ git push origin --force-with-lease
}             # 안전한 강제 푸시
function gl
{ git log --oneline -n 10
}                        # 최근 로그 10개
function gll
{ git log --oneline --graph --all
}                 # 전체 브랜치 그래프
# function gd    { git diff }                                        # 변경사항 비교
# function gdc   { git diff --staged }                               # 스테이징된 변경사항 비교
# function gb    { git branch }                                      # 로컬 브랜치 목록
# function gba   { git branch -a }                                   # 전체 브랜치 (원격 포함)
# function gsw   { param([string]$b) git switch $b }                 # 브랜치 전환
# function gsc   { param([string]$b) git switch -c $b }             # 브랜치 생성 및 전환
# function gbd   { param([string]$b) git branch -d $b }             # 브랜치 삭제 (병합 완료)
# function gbD   { param([string]$b) git branch -D $b }             # 브랜치 강제 삭제
# function gm    { param([string]$b) git merge $b }                  # 브랜치 병합
function gg
{ lazygit $args
}                                   # lazygit 실행
function gc
{ git commit -m "$args"
}                           # 메시지와 함께 커밋
function gca
{ git commit -m "auto commit"
}                     # 자동 메시지 커밋
function gup
{ git add .; git commit -m "auto commit"; git push
}
# function gst   { git stash }                                       # 작업 임시 저장
# function gstp  { git stash pop }                                   # 임시 저장 복원
# function gstl  { git stash list }                                  # 임시 저장 목록
# function gr    { param([string]$ref) git reset --hard $ref }       # 강제 초기화
# function grs   { git reset --soft HEAD~1 }                         # 최근 커밋 취소 (내용 유지)
# function gre   { param([string]$f) git restore $f }                # 파일 변경사항 복구
# function gres  { param([string]$f) git restore --staged $f }       # 스테이징 취소
# function gclean { git clean -fd }                                  # 미추적 파일 삭제

function gac
{
    param([string]$msg = "auto commit", [string]$body)
    git add -A
    if ($body)
    { git commit -m $msg -m $body
    } else
    { git commit -m $msg
    }
}

function gacp
{
    param([string]$msg = "auto commit", [string]$body)
    gac $msg $body
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (!$branch)
    { $branch = "main"
    }
    git push origin $branch
}

function gfo
{
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (!$branch)
    { $branch = "main"
    }
    Write-Host "Resetting to origin/$branch..." -ForegroundColor Yellow
    git fetch origin
    git reset --hard "origin/$branch"
}

function mrd
{
    param([string]$name)
    New-Item -ItemType Directory -Path $name -Force | Out-Null
    New-Item -ItemType File -Path "$name\README.md" -Value "# $name" -Force | Out-Null
    Write-Host "✅ $name (README.md)" -ForegroundColor Green
}

function mrdpy
{
    param([string]$name)
    mrd $name
    New-Item -ItemType File -Path "$name\basic.py" -Force | Out-Null
    Write-Host "✅ $name (README.md + basic.py)" -ForegroundColor Green
}


# ============================================================
# Git Gist
# ============================================================
# ggl              - 목록 50개
# ggd <ID>         - 삭제
# gga <file>       - 파일 직접 업로드
# gga <f1> <f2>    - 다중 파일 업로드
# ggaa             - 클립보드 업로드
# ============================================================
function ggl
{ gh gist list --limit 20
}
function ggd
{ gh gist delete $args
}
function gga
{ gh gist create $args
}
function ggaa
{ python3 C:\Users\x\.dotfolders\common\python\util\gistup\basic_srzst_gh.py
}

# ============================================================
# Git 태그 관리
# ============================================================
function gt
{ git tag
}

function gt1
{
    param([Parameter(Mandatory=$true)][string]$m)
    $tag_name = "$(Get-Date -Format 'yyMMdd_HHmm')($($m -replace ' ','_'))"
    git commit --allow-empty -m "checkpoint: $m"
    git tag -a $tag_name -m $m
    Write-Host "✅ 태그 백업: $tag_name " -ForegroundColor Green
}

function gt2
{
    param([Parameter(Mandatory=$true)][string]$tag, [Parameter(ValueFromRemainingArguments=$true)][string[]]$files)
    $root = git rev-parse --show-toplevel
    if ($files.Count -gt 0)
    {
        foreach ($f in $files)
        {
            $rel = [System.IO.Path]::GetRelativePath($root, (Resolve-Path $f))
            git -C $root restore --source=$tag $rel
            Write-Host "✅ 복원: $f (from $tag) " -ForegroundColor Green
        }
    } else
    {
        git -C $root restore --source=$tag .
        Write-Host "✅ 전체 복원 (from $tag) " -ForegroundColor Green
    }
}

function gt3
{
    param([Parameter(Mandatory=$true)][string]$tag)
    git tag -d $tag
    Write-Host "✅ 태그 삭제: $tag " -ForegroundColor Green
}

function gt4
{
    $confirm = Read-Host "⚠️  모든 태그를 삭제합니다. 계속할까요? (y/N)"
    if ($confirm -match '^[Yy]$')
    {
        git tag | ForEach-Object { git tag -d $_ }
        Write-Host "✅ 전체 태그 삭제 완료 " -ForegroundColor Green
    } else
    { Write-Host "취소됨 "
    }
}

function gtd
{ param([string]$t) git tag -d $t
}


# ============================================================
# Git 파일 단위 백업/복원
# ============================================================
function gf1
{
    param([Parameter(Mandatory=$true)][string]$file, [string]$msg = "$(Get-Date -Format 'yyMMdd_HHmm') 수정전 ")
    if (-not (Test-Path $file))
    { Write-Host "❌ 파일 없음: $file " -ForegroundColor Red; return
    }
    $root = git rev-parse --show-toplevel
    $rel  = [System.IO.Path]::GetRelativePath($root, (Resolve-Path $file))
    Add-Content $file ""
    git -C $root add $rel
    git -C $root commit -m "backup: $rel - $msg"
    Write-Host "✅ 저장: $rel - $msg " -ForegroundColor Green
}

function gf2
{
    param([Parameter(Mandatory=$true)][string]$hash)
    $root = git rev-parse --show-toplevel
    $rel  = git -C $root show --name-only --format="" $hash | Select-Object -First 1
    if (-not $rel)
    { Write-Host "❌ 해시를 찾을 수 없습니다. " -ForegroundColor Red; return
    }
    git -C $root restore --source=$hash $rel
    Write-Host "✅ 복원: $rel " -ForegroundColor Green
}

function rcw
{ rclone rcd --rc-web-gui
} # rclone web gui
# # ============================================================
# # Git 태그 관리
# # ============================================================
# # gt               - 태그 목록
# # gt1 "msg"        - 빈 커밋 + 태그 생성      → 260412_2210(msg)
# # gt2 <tag>        - 전체 복원
# # gt2 <tag> <file> - 단일/복수 파일 복원
# # gt3 <tag>        - 태그 삭제
# # gt4              - 전체 태그 삭제
# # ============================================================
# function gt { git tag }

# function gt1 {
#     param([Parameter(Mandatory=$true)][string]$m)
#     $tag_name = "$(Get-Date -Format 'yyMMdd_HHmm')($($m -replace ' ','_'))"
#     git commit --allow-empty -m "checkpoint: $m"
#     git tag -a $tag_name -m $m
#     Write-Host "✅ 태그 백업: $tag_name" -ForegroundColor Green
# }

# function gt2 {
#     param([Parameter(Mandatory=$true)][string]$tag, [Parameter(ValueFromRemainingArguments=$true)][string[]]$files)
#     $root = git rev-parse --show-toplevel
#     if ($files.Count -gt 0) {
#         foreach ($f in $files) {
#             $rel = [System.IO.Path]::GetRelativePath($root, (Resolve-Path $f))
#             git -C $root restore --source=$tag $rel
#             Write-Host "✅ 복원: $f (from $tag)" -ForegroundColor Green
#         }
#     } else {
#         git -C $root restore --source=$tag .
#         Write-Host "✅ 전체 복원 (from $tag)" -ForegroundColor Green
#     }
# }

# function gt3 {
#     param([Parameter(Mandatory=$true)][string]$tag)
#     git tag -d $tag
#     Write-Host "✅ 태그 삭제: $tag" -ForegroundColor Green
# }

# function gt4 {
#     $confirm = Read-Host "⚠️  모든 태그를 삭제합니다. 계속할까요? (y/N)"
#     if ($confirm -match '^[Yy]$') {
#         git tag | ForEach-Object { git tag -d $_ }
#         Write-Host "✅ 전체 태그 삭제 완료" -ForegroundColor Green
#     } else { Write-Host "취소됨" }
# }

# function gtd { param([string]$t) git tag -d $t }                   # 태그 삭제 단축


# # ============================================================
# # Git 파일 단위 백업/복원
# # ============================================================
# # gf1 <file>        - 파일 백업 커밋 (기본 메시지: 260412_2210 수정전)
# # gf1 <file> "msg"  - 커스텀 메시지로 백업
# # gf2 <hash>        - 해시로 파일 자동 인식 후 복원
# # gl                - 백업 이력 확인
# # ============================================================
# function gf1 {
#     param([Parameter(Mandatory=$true)][string]$file, [string]$msg = "$(Get-Date -Format 'yyMMdd_HHmm') 수정전")
#     if (-not (Test-Path $file)) { Write-Host "❌ 파일 없음: $file" -ForegroundColor Red; return }
#     $root = git rev-parse --show-toplevel
#     $rel  = [System.IO.Path]::GetRelativePath($root, (Resolve-Path $file))
#     Add-Content $file ""
#     git -C $root add $rel
#     git -C $root commit -m "backup: $rel - $msg"
#     Write-Host "✅ 저장: $rel - $msg" -ForegroundColor Green
# }

# function gf2 {
#     param([Parameter(Mandatory=$true)][string]$hash)
#     $root = git rev-parse --show-toplevel
#     $rel  = git -C $root show --name-only --format="" $hash | Select-Object -First 1
#     if (-not $rel) { Write-Host "❌ 해시를 찾을 수 없습니다." -ForegroundColor Red; return }
#     git -C $root restore --source=$hash $rel
#     Write-Host "✅ 복원: $rel" -ForegroundColor Green
# }


# ============================================================
# PSReadLine: 프롬프트 전용 커서 이동 / 단어 이동 / 삭제
# Vim, nvim, less, ssh 내부에는 영향 없음
# ============================================================

# 기본 이동
Set-PSReadLineKeyHandler -Chord 'Alt+j' -Function BackwardChar
Set-PSReadLineKeyHandler -Chord 'Alt+l' -Function ForwardChar
Set-PSReadLineKeyHandler -Chord 'Alt+i' -Function PreviousHistory
Set-PSReadLineKeyHandler -Chord 'Alt+k' -Function NextHistory

# 단어 단위 이동
Set-PSReadLineKeyHandler -Chord 'Alt+u' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Alt+o' -Function ForwardWord

# Home / End
Set-PSReadLineKeyHandler -Chord 'Alt+y' -Function BeginningOfLine
Set-PSReadLineKeyHandler -Chord 'Alt+p' -Function EndOfLine

# 기본 삭제
Set-PSReadLineKeyHandler -Chord 'Alt+h' -Function BackwardDeleteChar
Set-PSReadLineKeyHandler -Chord 'Alt+w' -Function DeleteChar

# 단어 단위 삭제
Set-PSReadLineKeyHandler -Chord 'Alt+Ctrl+j' -Function BackwardKillWord
Set-PSReadLineKeyHandler -Chord 'Alt+Ctrl+l' -Function KillWord

# 기존 AHK 감각에 맞춘 보조 단축키
Set-PSReadLineKeyHandler -Chord 'Alt+q' -Function BackwardDeleteChar
Set-PSReadLineKeyHandler -Chord 'Alt+m' -Function DeleteChar

[Console]::InputEncoding = [System.Text.UTF8Encoding]::new()
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new()
$OutputEncoding = [System.Text.UTF8Encoding]::new()

# Import the Chocolatey Profile that contains the necessary code to enable
# tab-completions to function for `choco`.
# Be aware that if you are missing these lines from your profile, tab completion
# for `choco` will not function.
# See https://ch0.co/tab-completion for details.
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
  Import-Module "$ChocolateyProfile"
}
