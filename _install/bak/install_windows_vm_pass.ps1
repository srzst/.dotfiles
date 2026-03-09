
# ============================================================
# bws CLI 설치 및 설정
# ============================================================
$BWS_BIN = "$HOME\bws\bws.exe"
if (-Not (Test-Path $BWS_BIN)) {
    Write-Log "bws CLI 설치 시작 (v$BWS_VERSION)"
    try {
        New-Item -ItemType Directory -Force -Path "$HOME\bws" | Out-Null
        Invoke-WebRequest -Uri $BWS_URL_WIN -OutFile "$HOME\bws\bws.zip"
        Expand-Archive -Path "$HOME\bws\bws.zip" -DestinationPath "$HOME\bws" -Force
        Remove-Item "$HOME\bws\bws.zip"
        Write-LogOK "bws CLI 설치 완료"
    } catch {
        Write-LogErr "bws CLI 설치 실패: $_"
        exit 1
    }
} else {
    Write-LogOK "bws CLI가 이미 존재합니다."
}

# 글로벌 gitignore 설정
$gitignorePath = "$HOME\.gitignore_global"
git config --global core.excludesfile $gitignorePath
$existingContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath } else { @() }
if ($existingContent -notcontains '*_secrets*') { Add-Content -Path $gitignorePath -Value '*_secrets*' }
Write-LogOK "글로벌 gitignore 설정 완료 (*_secrets* 제외)"


# ============================================================
# BWS secrets 복원 함수
# ============================================================
function Get-BwsSecret($id) {
    try {
        $raw = & $BWS_BIN secret get $id 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-LogErr "BWS Secret 추출 실패 (ID: $id)"
            return $null
        }
        $json = $raw | ConvertFrom-Json
        return $json.value
    } catch {
        Write-LogErr "BWS Secret 예외 발생 (ID: $id): $_"
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
  git -C $REPO submodule update --init 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  git -C $REPO submodule foreach "git checkout main 2>/dev/null || true" 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "서브모듈 초기화 완료"
} catch {
  Write-LogErr "서브모듈 초기화 실패: $_  → SSH 인증 또는 .gitmodules 확인"
}

# 서브모듈 remote URL → HTTPS로 변환 (GitHub Desktop 호환)
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
#   git, gsudo, vim, curl
#   python, nodejs
#   neovim, neovide, lazygit, tree-sitter
#   yazi, ffmpeg, 7zip, jq, poppler
#   fd, ripgrep, fzf, zoxide, imagemagick
#   tabby, tectonic, typora, pipx
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
  scoop install python nodejs neovim neovide lazygit tree-sitter yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide imagemagick tabby tectonic pipx typora
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
# Chocolatey 패키지 설치
# ============================================================
Write-Log "Chocolatey 패키지 설치 중..."
try {
  choco install sparkmail -y 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "choco sparkmail 설치 완료"
} catch {
  Write-LogErr "choco sparkmail 설치 실패: $_"
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
# (GUI 앱 + 일반 앱)
# ============================================================
# 설치 목록:
#   9PFXXSHC64H3                  ← Raycast (MS Store, 2026-03 기준)
#   Figma.Figma                   ← 디자인 툴
#   Microsoft.VisualStudioCode    ← 에디터
#   ZedIndustries.Zed             ← 에디터
#   Anysphere.Cursor              ← AI 코딩 에디터
#   Google.Chrome                 ← 브라우저
#   Brave.Brave                   ← 브라우저
#   Vivaldi.Vivaldi               ← 브라우저
#   NAVER.Whale                   ← 브라우저 (해외 IP 사용 시 실패 가능)
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
#   Iterate.MountainDuck          ← 클라우드 마운트
# ------------------------------------------------------------

# winget PATH 누락 방지
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

# MS Store 전용 ID 목록 (--exact 없이 설치)
# 9PFXXSHC64H3 = Raycast 공식 MS Store ID (2026-03 기준), 실패 시 winget search Raycast 재확인
$wingetStoreApps = @(
    "9PFXXSHC64H3"   # Raycast
)
foreach ($app in $wingetStoreApps) {
  try {
    $result = winget install --id $app `
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

Write-Log "Winget 신규 패키지 설치 중..."
$wingetApps = @(
    # "Figma.Figma",
    # "Microsoft.VisualStudioCode",
    # "Anysphere.Cursor",
    # "Brave.Brave",
    # "Vivaldi.Vivaldi",
    # "Bitwarden.Bitwarden",
    # "GitHub.GitHubDesktop",
    # "Microsoft.PowerToys",
    "Microsoft.PowerShell",
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
    # "Iterate.MountainDuck",
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
$winSnapTarget = "C:\Program Files\WinSnap\WinSnap.exe"

if (Test-Path $winSnapTarget) {
  Write-LogOK "WinSnap 이미 설치됨 (스킵)"
} else {
  try {
    Write-Log "WinSnap 다운로드 중..."
    Invoke-WebRequest -Uri $winSnapUrl -OutFile $winSnapZip -UseBasicParsing
    Expand-Archive -Path $winSnapZip -DestinationPath $winSnapExtDir -Force
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
# ============================================================
try {
  git -C $REPO remote set-url origin "https://github.com/srzst/.dotfiles.git" 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK ".dotfiles remote HTTPS 변경 완료 (GitHub Desktop 호환)"
} catch {
  Write-LogErr ".dotfiles remote 변경 실패: $_"
}

# ============================================================
# LazyVim 초기화 (Neovim 플러그인 동기화)
# 1차: 플러그인 동기화
# 2차: mason 패키지 설치 완료 대기
# ============================================================
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
    & $startupScript 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
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
# winget Git 제거 (Scoop Git으로 대체)
# ============================================================
Write-Log "winget Git 제거 중 (Scoop Git으로 대체됨)..."
try {
  winget uninstall --id Git.Git --silent --accept-source-agreements 2>$null
  Write-LogOK "winget Git 제거 완료"
} catch {
  Write-LogWarn "winget Git 제거 실패 (이미 없거나 수동 제거 필요)"
}

# ============================================================
# 수동 설치 필요 항목 안내
# (패키지 매니저 미지원 / 유료 / MS Store 전용)
# ============================================================
# UpNote            - MS Store
# FastStone Capture - https://faststone.org
# Jump Desktop      - MS Store
# PhotoScape X Pro  - MS Store
# Snipdo            - https://snipdo-app.com
# WinSnap           - 자동 설치 처리됨 (install_windows.ps1)
# Zoho Mail Desktop - https://zoho.com/mail/desktop-app.html
# Blip              - 공식 사이트 확인 필요
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
Write-Log "========== Windows 설치 완료 =========="
Write-Log "로그 파일 위치: $LOG_FILE"
Write-Host "INFO 재시작 후 모든 설정이 적용됩니다."