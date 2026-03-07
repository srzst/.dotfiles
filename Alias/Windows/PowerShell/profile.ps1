# ============================================================
# Windows PowerShell 프로필
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
# 파일 및 디렉토리 관리
# ============================================================
function l { Get-ChildItem -Force }
function ll { Get-ChildItem -Force }
function la { Get-ChildItem -Force }
function lt { Get-ChildItem | Sort-Object LastWriteTime -Descending }
function c { Clear-Host }
function cc { Clear-Host }
function e { Exit }
function ee { Exit }
function .. { Set-Location .. }
function ... { Set-Location ../.. }
function h { Set-Location ~ }

# 디렉토리 생성 후 이동
function mc { New-Item -ItemType Directory -Path $args[0] -Force; Set-Location $args[0] }

# 안전한 파일 조작 및 별칭 충돌 해결
if (Test-Path "Alias:rm") { Remove-Item "Alias:rm" -Force }
function Remove-Force { Remove-Item -Path $args -Force -Recurse -Verbose }
Set-Alias -Name rm -Value Remove-Force -Option AllScope -Force

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
# Git 함수
# ============================================================
# FIX: 충돌 별칭 제거 (gs, gc, gp, gm, gcm, gl 모두)
@('gs','gc','gp','gm','gcm','gl') | ForEach-Object {
    if (Test-Path "Alias:$_") { Remove-Item "Alias:$_" -Force }
}

# 기본 상태 / 초기화
function gi  { git init -b main }
# FIX: gs 재정의 (제거 후 누락됐던 함수)
function gs  { git status }
function gss { git status -s }
function ga  { git add . }
function gaa { git add --all }
function gp  { git push }
function gpl { git pull }
function gpf { git push origin --force-with-lease }

# 로그 / 브랜치
function gl   { git log --oneline -n 10 }
function gll  { git log --oneline --graph --all }
function gd   { git diff }
function gdc  { git diff --staged }
function gb   { git branch }
function gba  { git branch -a }

# FIX: $args 미전달 문제 → param() 으로 명시적 수신
function gco  { param([string]$branch) git checkout $branch }
function gcb  { param([string]$branch) git checkout -b $branch }
function gbd  { param([string]$branch) git branch -d $branch }
function gm   { param([string]$branch) git merge $branch }

# 스태시 / 리셋
function gst   { git stash }
function gstp  { git stash pop }
function gstl  { git stash list }
function gr    { param([string]$ref) git reset --hard $ref }
function grs   { git reset --soft HEAD~1 }
function gclean { git clean -fd }

# FIX: gc 재정의 (제거 후 누락됐던 함수)
function gc  { git commit -m "$args" }
function gca { git commit -m "auto commit" }

# gac: Add + Commit
function gac {
    param([string]$msg = "auto commit")
    git add .
    git commit -m $msg
}

# gacp: Add + Commit + Push
# FIX: Mandatory=$true → 기본값 "auto commit" 으로 변경
function gacp {
    param([string]$msg = "auto commit")
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (!$branch) { $branch = "main" }
    git add .
    git commit -m $msg
    git push origin $branch
}

# gup: 즉시 푸시
function gup { git add .; git commit -m "auto commit"; git push }

# gfo: 원격 기준 강제 초기화
function gfo {
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (!$branch) { $branch = "main" }
    git fetch origin
    git reset --hard "origin/$branch"
}

# 서브모듈 함수
function gsacp {
    param([string]$msg = "auto commit")
    git submodule foreach git add .
    git submodule foreach git commit -m $msg
    git submodule foreach git push
    git add .
    git commit -m $msg
    git push
}


# ============================================================
# 시스템 유틸리티
# ============================================================
function s    { gsudo }
function sudo { gsudo }
function port { param($p) if ($p) { netstat -ano | findstr ":$p" } else { netstat -ano | findstr LISTENING } }
function myip { Invoke-RestMethod -Uri "https://ifconfig.me" }
# FIX: ff 로 통일 (fzf f 단축키 충돌 방지 - GitBash와 일관성)
# function ff   { param($name) Get-ChildItem -Recurse -Filter "*$name*" -ErrorAction SilentlyContinue }
function ff {
    param($name)
    if (!$name) { Write-Host "사용법: ff <검색어>" -ForegroundColor Yellow; return }
    Get-ChildItem -Recurse -Filter "*$name*" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\\(node_modules|\.git|go\\pkg\\mod)\\' }
}

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

# zoxide 초기화
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { zoxide init powershell | Out-String })
}

$env:PATH += ";C:\Users\x\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude\claude-code\2.1.70"
