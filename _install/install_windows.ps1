$REPO = "$HOME\.dotfiles"

# ============================================================
# 사용자: x / 암호: (Bitwarden 참고)
# 관리자 권한 PowerShell에서 실행:
# & "$HOME\.dotfiles\_install\install_windows.ps1"
# ============================================================

# ============================================================
# 버전 변수 (업데이트 시 여기만 수정)
# ※ 버전 확인: https://github.com/bitwarden/sdk-sm/releases
# ※ 2026-03 기준 최신: 2.0.0 (2025-02-05 릴리스, 1년 이상 유지 중)
# ============================================================
$BWS_VERSION = "2.0.0"
$BWS_URL_WIN  = "https://github.com/bitwarden/sdk-sm/releases/download/bws-v${BWS_VERSION}/bws-x86_64-pc-windows-msvc-${BWS_VERSION}.zip"

# ============================================================
# 로그 설정
# 스크립트 전체 실행 내용을 파일로 기록
# 로그 위치: $HOME\install_windows_<날짜시간>.log
# ============================================================
$LOG_FILE    = "$HOME\install_windows_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$FAILED_ITEMS = [System.Collections.Generic.List[string]]::new()

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp][$Level] $Message"
    Write-Host $line
    Add-Content -Path $LOG_FILE -Value $line
}
function Write-LogOK   { param([string]$msg) Write-Log "OK   $msg" "INFO" }
function Write-LogWarn { param([string]$msg) Write-Log "WARN $msg" "WARN"; $FAILED_ITEMS.Add("WARN: $msg") }
function Write-LogErr  { param([string]$msg) Write-Log "ERR  $msg" "ERROR"; $FAILED_ITEMS.Add("ERR:  $msg") }

Write-Log "========== Windows 설치 스크립트 시작 =========="
Write-Log "로그 파일: $LOG_FILE"

# # ============================================================
# # 머신 타입 선택 (가장 먼저)
# # ============================================================
# Write-Host ""
# Write-Host "머신 타입을 선택하세요:"
# Write-Host "  1) main  - 데스크탑 / 노트북"
# Write-Host "  2) vm    - 가상머신"
# $machineTypeInput = Read-Host "선택 (1 or 2)"
# switch ($machineTypeInput) {
#   "1" { $MACHINE_TYPE = "main" }
#   "2" { $MACHINE_TYPE = "vm" }
#   default {
#     Write-LogErr "잘못된 입력 '$machineTypeInput' - 스크립트 종료"
#     exit 1
#   }
# }
# Write-LogOK "머신 타입: $MACHINE_TYPE"
# ============================================================
# 머신 타입 선택 (main으로 고정)
# ============================================================
$MACHINE_TYPE = "main"
Write-LogOK "머신 타입: $MACHINE_TYPE"
# ============================================================
# BWS 액세스 토큰 입력
# ============================================================
$existingToken = [System.Environment]::GetEnvironmentVariable("BWS_ACCESS_TOKEN", "User")
if (-Not $existingToken) {
  Write-Host ""
  $bwsToken = Read-Host "BWS 액세스 토큰을 입력하세요"
  [System.Environment]::SetEnvironmentVariable("BWS_ACCESS_TOKEN", $bwsToken, "User")
  $env:BWS_ACCESS_TOKEN = $bwsToken
  Write-LogOK "BWS_ACCESS_TOKEN 사용자 환경변수 등록 완료"
} else {
  $env:BWS_ACCESS_TOKEN = $existingToken
  Write-LogOK "BWS_ACCESS_TOKEN 이미 존재 (스킵)"
}

# Git 설정
try {
  git config --global user.email "x@srzst.com"
  git config --global user.name  "x"
  Write-LogOK "Git 설정 완료"
} catch {
  Write-LogErr "Git 설정 실패: $_  → git 설치 여부 확인"
}

# ============================================================
# bws CLI 설치
# ============================================================
$BWS_BIN = "$HOME\bws\bws.exe"
if (-Not (Test-Path $BWS_BIN)) {
  Write-Log "bws CLI 설치 중... (v$BWS_VERSION)"
  try {
    New-Item -ItemType Directory -Force -Path "$HOME\bws" | Out-Null
    Invoke-WebRequest -Uri $BWS_URL_WIN -OutFile "$HOME\bws\bws.zip"
    Expand-Archive -Path "$HOME\bws\bws.zip" -DestinationPath "$HOME\bws" -Force
    Remove-Item "$HOME\bws\bws.zip"
    Write-LogOK "bws CLI 설치 완료"
  } catch {
    Write-LogErr "bws CLI 설치 실패: $_  → 네트워크 또는 URL 확인: $BWS_URL_WIN"
    exit 1
  }
} else {
  Write-LogOK "bws CLI 이미 설치됨 (스킵)"
  $bwsVer = & $BWS_BIN --version 2>$null
  if ($bwsVer) { Write-Log "현재 bws 버전: $bwsVer" }
  else          { Write-LogWarn "bws --version 실행 실패 → 실행 파일 손상 가능성, 수동 확인 권장" }
}

# 글로벌 gitignore 설정
$gitignorePath = "$HOME\.gitignore_global"
git config --global core.excludesfile $gitignorePath
$existingContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath } else { @() }
if ($existingContent -notcontains '*_secrets*') { Add-Content -Path $gitignorePath -Value '*_secrets*' }
Write-LogOK "글로벌 gitignore 설정 완료"

# ============================================================
# BWS secrets 복원 함수
# 실패 시 $null 반환 + 로그 기록 (스크립트 중단 없음)
# 중요 secrets 실패 시 호출부에서 직접 exit 처리
# ============================================================
function Get-BwsSecret($id) {
  try {
    $raw = & $BWS_BIN secret get $id 2>&1
    if (-Not $?) {
      Write-LogErr "bws secret get 실패 (id: $id) → BWS 토큰 또는 secret ID 확인 필요"
      return $null
    }
    $json = $raw | ConvertFrom-Json
    return $json.value
  } catch {
    Write-LogErr "bws secret get 예외 발생 (id: $id): $_"
    return $null
  }
}

# ============================================================
# SSH 개인키 복원 (BWS)
# ============================================================
Write-Log "SSH 개인키 복원 중 (BWS: github_private_ssh_os_srzst)..."
New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
$sshKey = Get-BwsSecret "1eb6113c-83a3-4500-8d6c-b401000f48e3"
if (-Not $sshKey) {
  Write-LogErr "SSH 개인키 복원 실패 → BWS 토큰 및 secret ID 확인 후 재실행"
  exit 1
}
Set-Content -Path "$HOME\.ssh\id_ed25519" -Value $sshKey -NoNewline

# SSH 키 권한 강화 (사용자 전용 읽기, 상속 제거)
# → 없으면 ssh-agent 또는 git 연결 시 "bad permissions" / "Permissions ... are too open" 오류 발생
try {
  icacls "$HOME\.ssh\id_ed25519" /inheritance:r /grant:r "${env:USERNAME}:F" | Out-Null
  Write-LogOK "SSH 개인키 권한 설정 완료 (사용자 전용)"
} catch {
  Write-LogWarn "SSH 키 권한 설정 실패: $_  → 수동으로 권한 확인 필요"
}
Write-LogOK "SSH 개인키 복원 완료"

# SSH config 설정
$sshConfigPath = "$HOME\.ssh\config"
# config 파일 없으면 먼저 생성
if (-Not (Test-Path $sshConfigPath)) {
  New-Item -ItemType File -Force -Path $sshConfigPath | Out-Null
  Write-LogOK "SSH config 파일 생성 완료"
}
if (-Not (Select-String -Path $sshConfigPath -Pattern "Host github.com" -Quiet -ErrorAction SilentlyContinue)) {
  Add-Content -Path $sshConfigPath -Value "`nHost github.com`n  IdentityFile ~/.ssh/id_ed25519`n  User git`n  StrictHostKeyChecking no"
  Write-LogOK "SSH config 설정 완료"
} else {
  Write-LogOK "SSH config 이미 존재 (스킵)"
}

# GitHub known_hosts 미리 등록 (연결 테스트 시 yes/no 프롬프트 방지)
Write-Log "GitHub known_hosts 등록 중..."
try {
  $knownHostsPath = "$HOME\.ssh\known_hosts"
  $githubKey = ssh-keyscan -t ed25519 github.com 2>$null
  if ($githubKey) {
    Add-Content -Path $knownHostsPath -Value $githubKey
    Write-LogOK "GitHub known_hosts 등록 완료"
  } else {
    Write-LogWarn "GitHub known_hosts 등록 실패 → 네트워크 확인"
  }
} catch {
  Write-LogWarn "GitHub known_hosts 등록 중 오류: $_"
}

# GitHub 연결 테스트
Write-Log "GitHub SSH 연결 테스트 중..."
$sshTest = ssh -T git@github.com 2>&1
if ($sshTest -match "successfully authenticated") {
  Write-LogOK "GitHub SSH 인증 성공"
} else {
  Write-LogWarn "GitHub SSH 인증 실패 → BWS 키 또는 GitHub 등록 확인 필요 / 이후 clone 단계 실패 가능"
}

# ============================================================
# 나머지 BWS secrets 복원
# ============================================================
New-Item -ItemType Directory -Force -Path "$HOME\.aws" | Out-Null
$awsConfig      = Get-BwsSecret "95831a03-5ddd-46de-ac7c-b40000d57326"
$awsCredentials = Get-BwsSecret "96f60cf0-88f7-474d-9336-b40000d54799"
if ($awsConfig)      { Set-Content -Path "$HOME\.aws\config"      -Value $awsConfig      -NoNewline; Write-LogOK ".aws/config 복원 완료" }
else                 { Write-LogWarn ".aws/config 복원 실패 (스킵)" }
if ($awsCredentials) { Set-Content -Path "$HOME\.aws\credentials"  -Value $awsCredentials -NoNewline; Write-LogOK ".aws/credentials 복원 완료" }
else                 { Write-LogWarn ".aws/credentials 복원 실패 (스킵)" }

New-Item -ItemType Directory -Force -Path "$HOME\.backblaze" | Out-Null
$bbApi = Get-BwsSecret "fd5852f6-8474-4fac-9888-b40000d8ea90"
if ($bbApi) { Set-Content -Path "$HOME\.backblaze\backblazeapi" -Value $bbApi -NoNewline; Write-LogOK ".backblaze 복원 완료" }
else        { Write-LogWarn ".backblaze 복원 실패 (스킵)" }

$gitCreds = Get-BwsSecret "711d2b06-8271-4470-8e63-b40000d9129f"
if ($gitCreds) {
  Set-Content -Path "$HOME\.git-credentials" -Value $gitCreds -NoNewline
  # GCM 대신 .git-credentials 파일 직접 사용 (서브모듈 clone 시 팝업 방지)
  # system 레벨 먼저 설정 (GCM이 system 레벨에서 우선순위 높게 동작하므로)
  git config --system credential.helper store
  git config --global credential.helper store
  Write-LogOK ".git-credentials 복원 완료 (credential.helper store 설정)"
} else {
  Write-LogWarn ".git-credentials 복원 실패 (스킵)"
}

# ============================================================
# 서브모듈 초기화 (SSH 키 복원 후)
# .dotfiles는 스크립트 실행 전 수동 clone 전제
# 서브모듈 구조:
#   modules/common   - 운영체제 공통 (private)
#   modules/windows  - Windows 전용 (private)
#   modules/linux    - Linux 전용 (private)
#   modules/mac      - macOS 전용 (private)
# ============================================================
Write-Log "서브모듈 초기화 중..."
try {
  # --recursive 제외: 서브모듈 내 서브모듈(scriptos 등) URL 미등록 오류 방지
  git -C $REPO submodule update --init 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  # detached HEAD 복구: 서브모듈 초기화 시 git 기본 동작으로 detached HEAD가 되므로 main 브랜치로 복구
  git -C $REPO submodule foreach "git checkout main 2>/dev/null || true" 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "서브모듈 초기화 완료"
} catch {
  Write-LogErr "서브모듈 초기화 실패: $_  → SSH 인증 또는 .gitmodules 확인"
}

# 서브모듈 remote URL → HTTPS로 변환 (GitHub Desktop 호환)
# ※ SSH로 초기화 후 HTTPS로 변환하여 .git-credentials 인증 방식과 통일
Write-Log "서브모듈 remote URL HTTPS 변환 중..."
try {
  $submodulePaths = git -C $REPO submodule foreach --quiet 'echo $displaypath' 2>&1
  foreach ($sub in $submodulePaths) {
    $sub = $sub.Trim()
    if (-Not $sub) { continue }
    $subFullPath = "$REPO\$sub"
    $currentUrl  = git -C $subFullPath remote get-url origin 2>&1
    if ($currentUrl -match "git@github\.com:(.+)\.git") {
      $httpsUrl = "https://github.com/$($Matches[1]).git"
      git -C $subFullPath remote set-url origin $httpsUrl 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
      Write-LogOK "서브모듈 HTTPS 변환: $sub → $httpsUrl"
    } elseif ($currentUrl -match "git@github\.com:(.+)$") {
      $httpsUrl = "https://github.com/$($Matches[1]).git"
      git -C $subFullPath remote set-url origin $httpsUrl 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
      Write-LogOK "서브모듈 HTTPS 변환: $sub → $httpsUrl"
    } else {
      Write-LogOK "서브모듈 이미 HTTPS (스킵): $sub"
    }
  }
} catch {
  Write-LogErr "서브모듈 HTTPS 변환 실패: $_"
}

# ============================================================
# 심볼릭 링크
# ============================================================
function New-Symlink {
  param([string]$LinkPath, [string]$TargetPath)
  try {
    Remove-Item $LinkPath -Force -Recurse -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Force -Path $LinkPath -Target $TargetPath | Out-Null
    Write-LogOK "심볼릭 링크: $LinkPath → $TargetPath"
  } catch {
    Write-LogErr "심볼릭 링크 실패: $LinkPath → $TargetPath : $_"
  }
}

New-Symlink "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" "$REPO\Alias\Windows\PowerShell\profile.ps1"
New-Symlink "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1"        "$REPO\Alias\Windows\PowerShell\profile.ps1"

$nvimTarget = "$HOME\AppData\Local\nvim"
if (Test-Path $nvimTarget) { Remove-Item $nvimTarget -Recurse -Force }
New-Symlink $nvimTarget "$REPO\neovim"

$yaziTarget = "$env:APPDATA\yazi\config"
if (Test-Path $yaziTarget) { Remove-Item $yaziTarget -Recurse -Force }
New-Item -ItemType Directory -Force -Path "$env:APPDATA\yazi" | Out-Null
New-Symlink $yaziTarget "$REPO\yazi"

New-Symlink "$HOME\AppData\Roaming\Zed\settings.json" "$REPO\zed\settings.json"

New-Symlink "$HOME\.gitattributes_global" "$REPO\.gitattributes"
git config --global core.attributesFile "$HOME\.gitattributes_global"
Write-LogOK "Git 글로벌 attributes 연결 완료"

# ============================================================
# Scoop 설치 및 패키지
# (CLI / 개발 도구 – portable + .dotfiles 연동 최적)
# ============================================================
# 설치 목록:
#   git
#   gsudo
#   vim
#   curl
#   python
#   nodejs
#   neovim
#   neovide
#   lazygit
#   tree-sitter
#   yazi
#   ffmpeg
#   7zip
#   jq
#   poppler
#   fd
#   ripgrep
#   fzf
#   zoxide
#   imagemagick
#   tabby
#   tectonic
#   autohotkey1.1 ← AHK v1.1 전용 패키지 (versions bucket, upgrade 시 v2 설치 방지)
# ------------------------------------------------------------
# ※ msys2 제외 이유:
#   scoop으로 설치 시 mingw64 환경이 함께 설치되어
#   gcc / make 등 PATH 충돌 발생 가능.
#   C 컴파일러 등 mingw 환경이 실제 필요한 경우에만 수동 설치 권장.
#   → 필요 시: scoop install msys2  또는  https://msys2.org 직접 설치
# ------------------------------------------------------------
if (-Not (Get-Command scoop -ErrorAction SilentlyContinue)) {
  Write-Log "Scoop 설치 중..."
  try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    # 관리자 권한 실행 허용 (-RunAsAdmin)
    $env:SCOOP = "$HOME\scoop"
    [System.Environment]::SetEnvironmentVariable("SCOOP", "$HOME\scoop", "User")
    iex "& {$(irm get.scoop.sh)} -RunAsAdmin"
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-LogOK "Scoop 설치 완료"
  } catch {
    Write-LogErr "Scoop 설치 실패: $_  → https://scoop.sh 수동 설치 후 재실행"
    exit 1
  }
} else {
  Write-LogOK "Scoop 이미 설치됨 (스킵)"
}

try {
  scoop install git gsudo vim curl
  scoop bucket add extras
  scoop bucket add nerd-fonts
  scoop bucket add versions
  scoop update
  scoop install Hack-NF
  scoop install autohotkey1.1
  scoop install python  
  scoop install nodejs 
  scoop install neovim neovide lazygit tree-sitter yazi ffmpeg 5zip jq poppler fd ripgrep fzf zoxide imagemagick tabby tectonic pipx
  # C compiler (nvim-treesitter 요구사항)
  winget install --id=BrechtSanders.WinLibs.POSIX.UCRT -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
  Write-LogOK "Scoop 패키지 설치 완료"
} catch {
  Write-LogErr "Scoop 패키지 설치 중 오류: $_  → 개별 패키지 수동 설치 필요 여부 확인"
}

# ============================================================
# Chocolatey 설치 (패키지 없이 - 비상용 보조 패키지 매니저)
# 평소 Scoop/winget 사용. Chocolatey는 두 곳 모두 미지원 패키지 대비용.
# ============================================================
if (-Not (Get-Command choco -ErrorAction SilentlyContinue)) {
  Write-Log "Chocolatey 설치 중..."
  try {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    # $result 변수 충돌 방지: 스크립트를 임시 파일로 저장 후 실행
    $chocoScript = "$env:TEMP\install_choco.ps1"
    (New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1') | Set-Content $chocoScript
    & $chocoScript
    Remove-Item $chocoScript -ErrorAction SilentlyContinue
    Write-LogOK "Chocolatey 설치 완료"
  } catch {
    Write-LogErr "Chocolatey 설치 실패: $_  → https://chocolatey.org/install 수동 설치"
  }
} else {
  Write-LogOK "Chocolatey 이미 설치됨 (스킵)"
}

# ============================================================
# Python UTF-8 모드 설정 (한글 인코딩 오류 방지)
# ============================================================
Write-Log "Python UTF-8 모드 설정 중..."
$utf8Status = [System.Environment]::GetEnvironmentVariable("PYTHONUTF8", "User")
if ($utf8Status -ne "1") {
  [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
  $env:PYTHONUTF8 = "1"
  Write-LogOK "PYTHONUTF8 사용자 환경변수 등록 완료"
} else {
  Write-LogOK "PYTHONUTF8 이미 설정됨 (스킵)"
}

# ============================================================
# Winget 패키지 설치
# (GUI 앱 + 일반 앱 – choco 완전 대체)
# ============================================================
# 설치 목록:
#   Microsoft.VisualStudioCode    ← 에디터
#   ZedIndustries.Zed             ← 에디터 (공식 winget 지원)
#   Anysphere.Cursor              ← AI 코딩 에디터
#                                    ※ 2026-03 기준 ID 유효, 실패 시 winget search Cursor 재확인
#   Google.Chrome                 ← 브라우저
#   Brave.Brave                   ← 브라우저
#   Vivaldi.Vivaldi               ← 브라우저
#   NAVER.Whale                   ← 브라우저 (해외 IP 사용 시 실패 가능, 로그 확인)
#   Bitwarden.Bitwarden           ← 비밀번호 관리자
#   GitHub.GitHubDesktop          ← Git GUI
#   Microsoft.PowerToys           ← 시스템 유틸리티
#   Microsoft.PowerShell          ← PowerShell Core
#   Bandisoft.Bandizip            ← 압축 관리자
#   Bandisoft.Honeyview           ← 이미지 뷰어
#   Obsidian.Obsidian             ← 문서 관리
#   Logseq.Logseq                 ← 문서 관리
#   CopyQ.CopyQ                   ← 클립보드 관리자
#   LocalSend.LocalSend           ← 로컬 파일 전송
#   Kakao.KakaoTalk               ← 메신저
# ------------------------------------------------------------
# ※ --silent 미사용 이유:
#   일부 앱 설치 실패를 숨기는 경우가 있어 제거.
#   --accept-package-agreements --accept-source-agreements --scope user 만 사용.
#   강제 재설치 필요 시: --force 추가
# ※ cloudinary/urllib3 고정 관련:
#   cloudinary 1.26.x → urllib3 1.x 전용. 장기적으로 cloudinary 2.x 업그레이드 시
#   urllib3<2.0.0 고정 제거 및 cloudinary==1.26.0 고정 제거 필요.
# ------------------------------------------------------------

# winget PATH 누락 방지 (WindowsApps 경로가 PATH에 없는 경우 강제 주입)
$wingetPath = "$env:LOCALAPPDATA\Microsoft\WindowsApps"
if ($env:PATH -notlike "*WindowsApps*") {
  $env:PATH += ";$wingetPath"
  Write-Log "winget PATH 강제 주입 완료: $wingetPath"
}

# winget 소스 업데이트 및 기존 앱 업그레이드
Write-Log "winget 소스 업데이트 및 기존 앱 업그레이드 시도..."
try {
  winget upgrade --all --accept-package-agreements --accept-source-agreements 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "winget 업그레이드 완료"
} catch {
  Write-LogWarn "winget 업그레이드 중 오류 (무시하고 계속): $_"
}

Write-Log "Winget 신규 패키지 설치 중..."
$wingetApps = @(
    "Microsoft.VisualStudioCode",
    # "Anysphere.Cursor",
    # "Brave.Brave",
    # "Vivaldi.Vivaldi",
    # "Bitwarden.Bitwarden",
    # "GitHub.GitHubDesktop",
    # "Microsoft.PowerToys",
    # "Microsoft.PowerShell",
    # "Obsidian.Obsidian",
    # "Logseq.Logseq",
    "LocalSend.LocalSend"
)
foreach ($app in $wingetApps) {
  try {
    $result = winget install --id $app --exact `
      --accept-package-agreements --accept-source-agreements --scope user 2>&1
    Add-Content -Path $LOG_FILE -Value ($result | Out-String)
    if ($LASTEXITCODE -eq 0) {
      Write-LogOK "winget 설치 완료: $app"
    } elseif ($LASTEXITCODE -eq -1978335189) {
      # 0x8A150011 = 이미 설치됨
      Write-LogOK "winget 이미 설치됨 (스킵): $app"
    } else {
      Write-LogWarn "winget 설치 실패 (exit $LASTEXITCODE): $app  → 수동 설치 또는 ID 재확인"
    }
  } catch {
    Write-LogErr "winget 예외 발생: $app : $_"
  }
}

# --scope user 제외 목록 (설치 실패 이력 있는 앱)
$wingetAppsNoScope = @(
    # "ZedIndustries.Zed",
    # "NAVER.Whale",
    # "Bandisoft.Bandizip",
    # "Bandisoft.Honeyview",
    # "CopyQ.CopyQ",
    # "Kakao.KakaoTalk",
    "Google.Chrome"
)
foreach ($app in $wingetAppsNoScope) {
  try {
    $result = winget install -e --id $app `
      --accept-package-agreements --accept-source-agreements 2>&1
    Add-Content -Path $LOG_FILE -Value ($result | Out-String)
    if ($LASTEXITCODE -eq 0) {
      Write-LogOK "winget 설치 완료: $app"
    } elseif ($LASTEXITCODE -eq -1978335189) {
      Write-LogOK "winget 이미 설치됨 (스킵): $app"
    } else {
      Write-LogWarn "winget 설치 실패 (exit $LASTEXITCODE): $app  → 수동 설치 또는 ID 재확인"
    }
  } catch {
    Write-LogErr "winget 예외 발생: $app : $_"
  }
}
Write-LogOK "Winget 패키지 설치 완료"

# ============================================================
# pip / pipx / npm 패키지 설치
# ============================================================
Write-Log "pip 패키지 설치 중..."
try {
  # Scoop python은 scoop update python으로 업데이트하므로 pip upgrade 불필요
  # urllib3<2.0.0: cloudinary 1.26.x 호환성 고정
  # → cloudinary 2.x 업그레이드 시 이 고정 제거 필요
  python -m pip install "urllib3<2.0.0" 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  python -m pip install `
    pyperclip regex requests mistune boto3 clipboard pillow win10toast pywin32 plyer `
    b2sdk pynput watchdog send2trash PyQt5 pygments pandas tabulate oauth2client gspread `
    google-api-python-client langdetect pyautogui dropbox pyinstaller cloudinary==1.26.0 pyimgur `
    2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "pip 패키지 설치 완료"
} catch {
  Write-LogErr "pip 패키지 설치 실패: $_  → python 설치 여부 및 PATH 확인"
}

# 기존 사용자 Python Scripts 경로 제거 (PATH 충돌 및 "Unable to create process" 오류 방지)
$userPath  = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$cleanPath = ($userPath -split ';' | Where-Object { $_.ToLower() -notlike "*\roaming\python\*" }) -join ';'
[System.Environment]::SetEnvironmentVariable("PATH", $cleanPath, "User")
$env:PATH  = ($env:PATH   -split ';' | Where-Object { $_.ToLower() -notlike "*\roaming\python\*" }) -join ';'

# Scoop PATH 즉시 반영 (pipx 인식 안됨 방지)
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

try {
  pipx install gita 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  pipx ensurepath
  # FIX: pipx 기본 경로 직접 추가 (ensurepath 후 환경변수 즉시 미반영 문제 방지)
  $env:PATH = "$HOME\.local\bin;" + $env:PATH
  gita add $REPO 2>$null
  Write-LogOK "pipx/gita 설치 및 .dotfiles 등록 완료"
} catch {
  Write-LogErr "pipx/gita 설치 실패: $_"
}

try {
  npm install -g electron 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "npm 패키지 설치 완료"
} catch {
  Write-LogErr "npm 패키지 설치 실패: $_  → nodejs 설치 여부 확인"
}

# ============================================================
# WinSnap 자동 설치
# 인증 완료 버전 zip 다운로드 → 압축 해제 → 설치
# ※ silent 옵션 미확인 → 설치 창이 뜰 수 있음
# ============================================================
$winSnapUrl    = "https://dl.srzst.com/WinSnap_v6.2.2.zip"
$winSnapZip    = "$env:TEMP\WinSnap_v6.2.2.zip"
$winSnapExtDir = "$env:TEMP\WinSnap_v6.2.2"
$winSnapExe    = "$winSnapExtDir\WinSnap_v6.2.2_x64_KO_단일.exe"
$winSnapTarget = "C:\Program Files\WinSnap\WinSnap.exe"

if (Test-Path $winSnapTarget) {
  Write-LogOK "WinSnap 이미 설치됨 (스킵)"
} else {
  try {
    Write-Log "WinSnap 다운로드 중..."
    Invoke-WebRequest -Uri $winSnapUrl -OutFile $winSnapZip -UseBasicParsing
    Expand-Archive -Path $winSnapZip -DestinationPath $winSnapExtDir -Force
    # 파일명 한글 인코딩 문제 방지: 실제 exe 파일 탐색
    $winSnapExeFound = Get-ChildItem -Path $winSnapExtDir -Filter "*x64*단일*.exe" -Recurse | Select-Object -First 1
    if (-Not $winSnapExeFound) {
      $winSnapExeFound = Get-ChildItem -Path $winSnapExtDir -Filter "*.exe" -Recurse | Select-Object -First 1
    }
    if (-Not $winSnapExeFound) { throw "WinSnap 설치 파일을 찾을 수 없습니다" }
    Write-Log "WinSnap 설치 중... (설치 창이 뜰 수 있음): $($winSnapExeFound.FullName)"
    Start-Process -FilePath $winSnapExeFound.FullName -Wait
    Write-LogOK "WinSnap 설치 완료"
  } catch {
    Write-LogErr "WinSnap 설치 실패: $_  → https://dl.srzst.com/WinSnap_v6.2.2.zip 수동 설치"
  } finally {
    Remove-Item $winSnapZip    -ErrorAction SilentlyContinue
    Remove-Item $winSnapExtDir -Recurse -ErrorAction SilentlyContinue
  }
}

# ============================================================
# 스케줄 작업 등록 (xwin)
# ※ xwin은 서브모듈로 이동 예정 → 경로 확정 후 별도 추가
# ============================================================

# ============================================================
# GitHub Desktop 호환 - remote URL HTTPS로 변경
# ※ .git-credentials 복원이 완료되어 있어야 push/pull 가능
# ※ 서브모듈 remote HTTPS 변환은 위 서브모듈 초기화 블록에서 처리됨
# ============================================================
try {
  git -C $REPO remote set-url origin "https://github.com/srzst/.dotfiles.git" 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK ".dotfiles remote HTTPS 변경 완료 (GitHub Desktop 호환)"
} catch {
  Write-LogErr ".dotfiles remote 변경 실패: $_"
}

# LazyVim 초기화 (Neovim 플러그인 동기화)
# 1차: 플러그인 동기화
# 2차: mason 패키지 설치 완료 대기 (1차 실행 시 nvim 종료로 설치 중단되는 경우 방지)
try {
  nvim --headless "+Lazy! sync" +qa 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Start-Sleep -Seconds 3
  nvim --headless "+Lazy! sync" +qa 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "LazyVim 초기화 완료"
} catch {
  Write-LogErr "LazyVim 초기화 실패: $_  → neovim 설치 및 $REPO\neovim 심볼릭 링크 확인"
}

# ============================================================
# 시작 프로그램 및 스케줄 작업 등록 (startup_register.ps1)
# ============================================================
$startupScript = "$REPO\modules\windows\ps1\startup_register.ps1"
if (Test-Path $startupScript) {
  try {
    & $startupScript -MACHINE_TYPE $MACHINE_TYPE 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
    Write-LogOK "시작 프로그램 및 스케줄 작업 등록 완료"
  } catch {
    Write-LogErr "startup_register.ps1 실행 실패: $_"
  }
} else {
  Write-LogWarn "startup_register.ps1 없음 (스킵): $startupScript"
}

# ============================================================
# GitBash .bashrc 안내
# ============================================================
Write-Host ""
Write-Log "INFO GitBash .bashrc 는 GitBash 터미널에서 아래 명령 실행:"
Write-Host "    REPO=""/c/Users/$env:USERNAME/.dotfiles"""
Write-Host "    rm ~/.bashrc"
Write-Host "    ln -sf ""`$REPO/Alias/Windows/GitBash/.bashrc"" ~/.bashrc"

# ============================================================
# 수동 설치 필요 항목 안내
# (패키지 매니저 미지원 / 유료 / MS Store 전용)
# ============================================================
# Figma             - https://figma.com/downloads
# Typora            - https://typora.io
# UpNote            - https://download.getupnote.com/app/UpNote%20Setup.exe
# FastStone Capture - https://faststone.org
# Jump Desktop      - MS Store
# Mountain Duck     - https://mountainduck.io
# PhotoScape X Pro  - MS Store
# Snipdo            - https://snipdo-app.com
# Spark Desktop     - https://sparkmailapp.com
# Zoho Mail Desktop - https://zoho.com/mail/desktop-app.html
# Blip              - https://www.blip.com
# ------------------------------------------------------------
Write-Host ""
Write-Log "INFO 수동 설치 필요 항목:"
Write-Host "    UpNote            - https://download.getupnote.com/app/UpNote%20Setup.exe"
Write-Host "    FastStone Capture - https://faststone.org"
Write-Host "    Jump Desktop      - https://jumpdesktop.com/download.html"
Write-Host "    PhotoScape X Pro  - MS Store"
Write-Host "    Snipdo            - https://snipdo-app.com"
Write-Host "    Zoho Mail Desktop - https://zoho.com/mail/desktop-app.html"
Write-Host "    Blip              - https://www.blip.com"

# ============================================================
# 최종 요약: WARN / ERR 발생 항목 출력
# ============================================================
Write-Host ""
Write-Log "========== 설치 중 WARN/ERR 발생 항목 요약 =========="
if ($FAILED_ITEMS.Count -eq 0) {
  Write-LogOK "모든 항목 정상 완료 (WARN/ERR 없음)"
} else {
  foreach ($item in $FAILED_ITEMS) {
    Write-Host "  $item"
    Add-Content -Path $LOG_FILE -Value "  $item"
  }
  Write-Host ""
  Write-Log "위 항목들을 확인 후 수동 처리 또는 스크립트 재실행하세요."
}

Write-Host ""
Write-Log "========== Windows 설치 완료 [$MACHINE_TYPE] =========="
Write-Log "로그 파일 위치: $LOG_FILE"
Write-Host "INFO 재시작 후 모든 설정이 적용됩니다."