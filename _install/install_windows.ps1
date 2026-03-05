$REPO = "$HOME\.dotfiles"

# ============================================================
# 사용자: x / 암호: (Bitwarden 참고)
# 관리자 권한 PowerShell에서 실행:
# & "$HOME\.dotfiles\_install\install_windows.ps1"
# ============================================================

# ============================================================
# 버전 변수 (업데이트 시 여기만 수정)
# ※ 버전 확인: https://github.com/bitwarden/sdk-sm/releases
# ============================================================
$BWS_VERSION = "2.0.0"
$BWS_URL_WIN = "https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-x86_64-pc-windows-msvc-${BWS_VERSION}.zip"

# ============================================================
# 머신 타입 선택 (가장 먼저)
# ============================================================
Write-Host ""
Write-Host "머신 타입을 선택하세요:"
Write-Host "  1) main  - 데스크탑 / 노트북"
Write-Host "  2) vm    - 가상머신"
$machineTypeInput = Read-Host "선택 (1 or 2)"
switch ($machineTypeInput) {
  "1" { $MACHINE_TYPE = "main" }
  "2" { $MACHINE_TYPE = "vm" }
  default {
    Write-Host "잘못된 입력입니다. 스크립트를 종료합니다."
    exit 1
  }
}
Write-Host "OK 머신 타입: $MACHINE_TYPE"

# ============================================================
# BWS 액세스 토큰 입력
# ============================================================
$existingToken = [System.Environment]::GetEnvironmentVariable("BWS_ACCESS_TOKEN", "User")
if (-Not $existingToken) {
  Write-Host ""
  $bwsToken = Read-Host "BWS 액세스 토큰을 입력하세요"
  [System.Environment]::SetEnvironmentVariable("BWS_ACCESS_TOKEN", $bwsToken, "User")
  $env:BWS_ACCESS_TOKEN = $bwsToken
  Write-Host "OK BWS_ACCESS_TOKEN 사용자 환경변수 등록 완료"
} else {
  $env:BWS_ACCESS_TOKEN = $existingToken
  Write-Host "OK BWS_ACCESS_TOKEN 이미 존재 (스킵)"
}

# Git 설정
git config --global user.email "x@srzst.com"
git config --global user.name "x"
Write-Host "OK Git 설정 완료"

# ============================================================
# bws CLI 설치
# ============================================================
$BWS_BIN = "$HOME\bws\bws.exe"
if (-Not (Test-Path $BWS_BIN)) {
  Write-Host "bws CLI 설치 중..."
  New-Item -ItemType Directory -Force -Path "$HOME\bws" | Out-Null
  Invoke-WebRequest -Uri $BWS_URL_WIN -OutFile "$HOME\bws\bws.zip"
  Expand-Archive -Path "$HOME\bws\bws.zip" -DestinationPath "$HOME\bws" -Force
  Remove-Item "$HOME\bws\bws.zip"
  Write-Host "OK bws CLI 설치 완료"
} else {
  Write-Host "OK bws CLI 이미 설치됨 (스킵)"
}

# 글로벌 gitignore 설정
$gitignorePath = "$HOME\.gitignore_global"
git config --global core.excludesfile $gitignorePath
$existingContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath } else { @() }
if ($existingContent -notcontains '*_secrets*') { Add-Content -Path $gitignorePath -Value '*_secrets*' }
Write-Host "OK 글로벌 gitignore 설정 완료"

# BWS secrets 복원 함수
function Get-BwsSecret($id) {
  $raw = & $BWS_BIN secret get $id 2>$null
  $json = $raw | ConvertFrom-Json
  return $json.value
}

# ============================================================
# SSH 개인키 복원 (BWS)
# ============================================================
Write-Host ""
Write-Host "SSH 개인키 복원 중 (BWS: github_private_ssh_os_srzst)..."
New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
Get-BwsSecret "1eb6113c-83a3-4500-8d6c-b401000f48e3" | Set-Content -Path "$HOME\.ssh\id_ed25519" -NoNewline
Write-Host "OK SSH 개인키 복원 완료"

# SSH config 설정
$sshConfigPath = "$HOME\.ssh\config"
if (-Not (Select-String -Path $sshConfigPath -Pattern "Host github.com" -Quiet -ErrorAction SilentlyContinue)) {
  Add-Content -Path $sshConfigPath -Value "`nHost github.com`n  IdentityFile ~/.ssh/id_ed25519`n  User git"
  Write-Host "OK SSH config 설정 완료"
} else {
  Write-Host "OK SSH config 이미 존재 (스킵)"
}

# GitHub 연결 테스트
Write-Host ""
Write-Host "GitHub SSH 연결 테스트 중..."
$sshTest = ssh -T git@github.com 2>&1
if ($sshTest -match "successfully authenticated") {
  Write-Host "OK GitHub SSH 인증 성공"
} else {
  Write-Host "WARN GitHub SSH 인증 실패 - BWS 키 또는 GitHub 등록 확인 필요"
}

# ============================================================
# 나머지 BWS secrets 복원
# ============================================================
New-Item -ItemType Directory -Force -Path "$HOME\.aws" | Out-Null
Get-BwsSecret "95831a03-5ddd-46de-ac7c-b40000d57326" | Set-Content -Path "$HOME\.aws\config" -NoNewline
Get-BwsSecret "96f60cf0-88f7-474d-9336-b40000d54799" | Set-Content -Path "$HOME\.aws\credentials" -NoNewline
Write-Host "OK .aws 완료"
New-Item -ItemType Directory -Force -Path "$HOME\.backblaze" | Out-Null
Get-BwsSecret "fd5852f6-8474-4fac-9888-b40000d8ea90" | Set-Content -Path "$HOME\.backblaze\backblazeapi" -NoNewline
Write-Host "OK .backblaze 완료"
Get-BwsSecret "711d2b06-8271-4470-8e63-b40000d9129f" | Set-Content -Path "$HOME\.git-credentials" -NoNewline
Write-Host "OK .git-credentials 완료"

# ============================================================
# Private 저장소 clone (SSH 키 복원 후)
# ============================================================
Write-Host ""
Write-Host "Private 저장소 clone 중..."
$repos = @(
  "git@github.com:srzst/.myConfig",
  "git@github.com:srzst/xwin",
  "git@github.com:srzst/script",
  "git@github.com:srzst/scriptos"
)
foreach ($repo in $repos) {
  $repoName = Split-Path $repo -Leaf
  $repoPath = "$HOME\$repoName"
  if (-Not (Test-Path $repoPath)) {
    git clone $repo $repoPath
    Write-Host "OK $repoName clone 완료"
  } else {
    Write-Host "OK $repoName 이미 존재 (스킵)"
  }
}

# ============================================================
# 심볼릭 링크
# ============================================================
Remove-Item "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Force `
  -Path "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" `
  -Target "$REPO\Alias\Windows\PowerShell\profile.ps1"
Write-Host "OK Windows PowerShell 프로필 연결 완료"
Remove-Item "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Force `
  -Path "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" `
  -Target "$REPO\Alias\Windows\PowerShell\profile.ps1"
Write-Host "OK PowerShell Core 프로필 연결 완료"
$nvimTarget = "$HOME\AppData\Local\nvim"
if (Test-Path $nvimTarget) { Remove-Item $nvimTarget -Recurse -Force }
New-Item -ItemType SymbolicLink -Force `
  -Path $nvimTarget `
  -Target "$REPO\neovim"
Write-Host "OK Neovim 연결 완료"
$yaziTarget = "$env:APPDATA\yazi\config"
if (Test-Path $yaziTarget) { Remove-Item $yaziTarget -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$env:APPDATA\yazi" | Out-Null
New-Item -ItemType SymbolicLink -Force `
  -Path $yaziTarget `
  -Target "$REPO\yazi"
Write-Host "OK Yazi 설정 연결 완료"
Remove-Item "$HOME\AppData\Roaming\Zed\settings.json" -Force -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Force `
  -Path "$HOME\AppData\Roaming\Zed\settings.json" `
  -Target "$REPO\zed\settings.json"
Write-Host "OK Zed 설정 연결 완료"

# ============================================================
# Scoop 설치 및 패키지
# ============================================================
if (-Not (Get-Command scoop -ErrorAction SilentlyContinue)) {
  Write-Host ""
  Write-Host "Scoop 설치 중..."
  Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
  Invoke-WebRequest -useb get.scoop.sh | Invoke-Expression
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
  Write-Host "OK Scoop 설치 완료"
} else {
  Write-Host "OK Scoop 이미 설치됨 (스킵)"
}
scoop install git gsudo vim curl
scoop bucket add extras
scoop install python nodejs neovim neovide vscode lazygit tree-sitter yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide imagemagick tabby tectonic msys2
Write-Host "OK Scoop 패키지 설치 완료"

# ============================================================
# Python UTF-8 모드 설정 (한글 인코딩 오류 방지)
# ============================================================
Write-Host ""
Write-Host "Python UTF-8 모드 설정 중..."
$utf8Status = [System.Environment]::GetEnvironmentVariable("PYTHONUTF8", "User")
if ($utf8Status -ne "1") {
    [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
    $env:PYTHONUTF8 = "1"
    Write-Host "OK PYTHONUTF8 사용자 환경변수 등록 완료"
} else {
    Write-Host "OK PYTHONUTF8 이미 설정됨 (스킵)"
}

# ============================================================
# Chocolatey 설치 및 패키지
# ============================================================
if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Host ""
  Write-Host "Chocolatey 설치 중..."
  Set-ExecutionPolicy Bypass -Scope Process -Force
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
  Write-Host "OK Chocolatey 설치 완료"
} else {
  Write-Host "OK Chocolatey 이미 설치됨 (스킵)"
}
choco install bitwarden honeyview bandizip -y
choco install vlc logseq obsidian -y
choco install copyq github-desktop -y
choco install autohotkey.portable -y
choco install kdeconnect-kde localsend powershell-core -y
Write-Host "OK Chocolatey 패키지 설치 완료"
# ============================================================
# pip / pipx / npm 패키지 설치
# ============================================================
Write-Host ""
Write-Host "pip 패키지 설치 중..."
python -m pip install --upgrade pip
python -m pip install "urllib3<2.0.0"  # Cloudinary 호환성을 위한 고정
python -m pip install pyperclip regex requests mistune boto3 clipboard pillow win10toast pywin32 plyer b2sdk pynput watchdog send2trash PyQt5 pygments pandas tabulate oauth2client gspread google-api-python-client langdetect pyautogui dropbox pyinstaller cloudinary==1.26.0 pyimgur
Write-Host "OK pip 패키지 설치 완료"

# 기존 사용자 Python Scripts 경로 제거 (PATH 충돌 및 "Unable to create process" 오류 방지)
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$cleanPath = ($userPath -split ';' | Where-Object { $_.ToLower() -notlike "*\roaming\python\*" }) -join ';'
[System.Environment]::SetEnvironmentVariable("PATH", $cleanPath, "User")
$env:PATH = ($env:PATH -split ';' | Where-Object { $_.ToLower() -notlike "*\roaming\python\*" }) -join ';'

pipx install gita
pipx ensurepath
# FIX: pipx 기본 경로 직접 추가 (ensurepath 후 환경변수 즉시 미반영 문제 방지)
$env:PATH = "$HOME\.local\bin;" + $env:PATH
gita add $REPO 2>$null
Write-Host "OK pipx/gita 설치 및 .dotfiles 등록 완료"

npm install -g electron
Write-Host "OK npm 패키지 설치 완료"

# ============================================================
# 스케줄 작업 등록 (xwin)
# main: xwin_admin, xwin_normal, xwin_cron_5m, xwin_cron_2h
# vm  : xwin_admin, xwin_normal, xwin_cron_5m  (xwin_cron_2h 제외)
# ============================================================
Write-Host ""
Write-Host "스케줄 작업 등록 중... (머신 타입: $MACHINE_TYPE)"
$xwinPath = "$env:USERPROFILE\xwin"
if (Test-Path $xwinPath) {
  schtasks /Create /SC ONLOGON /TN "xwin_admin"  /TR "$xwinPath\xwin_admin.exe"  /RL HIGHEST /F
  Write-Host "OK xwin_admin 등록 완료"
  schtasks /Create /SC ONLOGON /TN "xwin_normal" /TR "$xwinPath\xwin_normal.exe" /RL LIMITED  /F
  Write-Host "OK xwin_normal 등록 완료"
  schtasks /create /sc DAILY /tn "xwin_cron_5m" /tr "$xwinPath\xwin_cron_5m.exe" /st 00:00 /ri 5 /du 24:00 /rl HIGHEST /F
  Write-Host "OK xwin_cron_5m 등록 완료"
  if ($MACHINE_TYPE -eq "main") {
    schtasks /create /sc HOURLY /mo 2 /tn "xwin_cron_2h" /tr "$xwinPath\xwin_cron_2h.exe" /st 00:00 /rl HIGHEST /F
    Write-Host "OK xwin_cron_2h 등록 완료 (main 전용)"
  } else {
    Write-Host "INFO xwin_cron_2h 스킵 (vm)"
  }
} else {
  Write-Host "INFO xwin 폴더 없음, 스케줄 작업 스킵"
}

# ============================================================
# GitHub Desktop 호환 - remote URL HTTPS로 변경
# ============================================================
$httpsRepos = @(
  @{ path = $REPO;               url = "https://github.com/srzst/.dotfiles.git" },
  @{ path = "$HOME\.myConfig";   url = "https://github.com/srzst/.myConfig.git" },
  @{ path = "$HOME\xwin";        url = "https://github.com/srzst/xwin.git" },
  @{ path = "$HOME\script";      url = "https://github.com/srzst/script.git" },
  @{ path = "$HOME\scriptos";    url = "https://github.com/srzst/scriptos.git" }
)
foreach ($r in $httpsRepos) {
  if (Test-Path $r.path) {
    git -C $r.path remote set-url origin $r.url
    Write-Host "OK remote HTTPS 변경: $($r.url)"
  }
}
Write-Host "OK 전체 remote URL HTTPS로 변경 완료 (GitHub Desktop 호환)"

# LazyVim 초기화 (Neovim 플러그인 동기화)
nvim --headless "+Lazy! sync" +qa 2>$null
Write-Host "OK LazyVim 초기화 완료"

# ============================================================
# GitBash .bashrc 안내
# ============================================================
Write-Host ""
Write-Host "INFO GitBash .bashrc 는 GitBash 터미널에서 아래 명령 실행:"
Write-Host "    REPO=""/c/Users/$env:USERNAME/.dotfiles"""
Write-Host "    rm ~/.bashrc"
Write-Host "    ln -sf ""`$REPO/Alias/Windows/GitBash/.bashrc"" ~/.bashrc"

Write-Host ""
Write-Host "OK Windows 설치 완료 [$MACHINE_TYPE]"
Write-Host "INFO 재시작 후 모든 설정이 적용됩니다."
