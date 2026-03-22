$REPO    = "$HOME\.dotfiles"
$FOLDERS = "$HOME\.dotfolders"

# ============================================================
# 사용자: x / 암호: (Bitwarden 참고)
# 관리자 권한 PowerShell에서 실행:
# & "$HOME\.dotfiles\_install\install_windows.ps1"
# ============================================================

# ============================================================
# 로그 설정
# ============================================================
$LOG_FILE     = "$HOME\install_windows_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
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

# ============================================================
# 머신 타입 (main 고정)
# ============================================================
$MACHINE_TYPE = "main"
Write-LogOK "머신 타입: $MACHINE_TYPE"

# ============================================================
# Infisical 설정
# ============================================================
$INFISICAL_PROJECT_ID = "bc893247-af3f-4118-a8ec-bcb429338acb"
$INFISICAL_ENV        = "dev"
$existingToken = [System.Environment]::GetEnvironmentVariable("INFISICAL_TOKEN", "User")
if (-Not $existingToken) {
  Write-Host ""
  # $tokenUrl = Read-Host "토큰 URL을 입력하세요"
  # $inputToken = (Invoke-WebRequest -Uri $tokenUrl -UseBasicParsing).Content.Trim()
  #----
  $inputToken = Read-Host "Infisical 서비스 토큰을 입력하세요"
  [System.Environment]::SetEnvironmentVariable("INFISICAL_TOKEN", $inputToken, "User")
  $env:INFISICAL_TOKEN = $inputToken
  Write-LogOK "INFISICAL_TOKEN 등록 완료"
} else {
  $env:INFISICAL_TOKEN = $existingToken
  Write-LogOK "INFISICAL_TOKEN 이미 존재 (스킵)"
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
# Infisical CLI 설치
# ============================================================
if (-Not (Get-Command infisical -ErrorAction SilentlyContinue)) {
  Write-Log "Infisical CLI 설치 중..."
  try {
    winget install --id Infisical.infisical -e --accept-package-agreements --accept-source-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-LogOK "Infisical CLI 설치 완료"
  } catch {
    Write-LogErr "Infisical CLI 설치 실패: $_  → https://infisical.com/docs/cli/overview 수동 설치"
    exit 1
  }
} else {
  Write-LogOK "Infisical CLI 이미 설치됨 (스킵)"
  $infisicalVer = infisical --version 2>$null
  if ($infisicalVer) { Write-Log "현재 Infisical 버전: $infisicalVer" }
}

# 글로벌 gitignore 설정
$gitignorePath = "$HOME\.gitignore_global"
git config --global core.excludesfile $gitignorePath
$existingContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath } else { @() }
if ($existingContent -notcontains '*_secrets*') { Add-Content -Path $gitignorePath -Value '*_secrets*' }
Write-LogOK "글로벌 gitignore 설정 완료"
# ============================================================
# Infisical Secrets 복원
# ============================================================

# ------------------------------------------------------------
# 환경변수 주입 (단일 값)
# 추가 시 @{ Key="키이름"; Path="/폴더" } 형식으로 추가
# ------------------------------------------------------------
$envSecrets = @(
    @{ Key = "tailscale_authkey";       Path = "/"       },
    @{ Key = "gistup_md_manual_srzst";  Path = "/github" },
    @{ Key = "personal_access_tokens_classic_sndzin";       Path = "/github" },
    @{ Key = "personal_access_tokens_classic_srzst";        Path = "/github" }
)

foreach ($s in $envSecrets) {
    $val = Get-InfisicalSecret $s.Key $s.Path
    if ($val) {
        [System.Environment]::SetEnvironmentVariable($s.Key, $val, "User")
        Write-LogOK "환경변수 주입 완료: $($s.Key)"
    } else {
        Write-LogWarn "환경변수 주입 실패: $($s.Key)"
    }
}

# ------------------------------------------------------------
# 파일 복원 (멀티라인)
# 추가 시 @{ Key="키이름"; Path="/폴더"; Dest="저장경로"; Critical=$false } 형식으로 추가
# Critical=$true 시 실패하면 스크립트 중단
# ------------------------------------------------------------
$fileSecrets = @(
    @{ Key = "github_private_ssh_os_srzst"; Path = "/github";    Dest = "$HOME\.ssh\id_ed25519";          Critical = $true  },
    @{ Key = "config";                      Path = "/aws";        Dest = "$HOME\.aws\config";              Critical = $false },
    @{ Key = "credentials";                 Path = "/aws";        Dest = "$HOME\.aws\credentials";         Critical = $false },
    @{ Key = "backblazeapi";                Path = "/backblaze";  Dest = "$HOME\.backblaze\backblazeapi";  Critical = $false },
    @{ Key = "git_credentials";             Path = "/github";     Dest = "$HOME\.git-credentials";         Critical = $false },
    @{ Key = "rclone_onedrive_sv"; Path = "/rclone"; Dest = "$HOME\.config\rclone\rclone.conf"; Critical = $false }
)

foreach ($s in $fileSecrets) {
    New-Item -ItemType Directory -Force -Path (Split-Path $s.Dest) | Out-Null
    $val = Get-InfisicalSecret $s.Key $s.Path
    if ($val) {
        Set-Content -Path $s.Dest -Value $valnue
        Write-LogOK "파일 복원 완료: $($s.Key) → $($s.Dest)"
    } else {
        if ($s.Critical) {
            Write-LogErr "파일 복원 실패 (Critical): $($s.Key) → 토큰 및 키 이름 확인 후 재실행"
            exit 1
        } else {
            Write-LogWarn "파일 복원 실패 (스킵): $($s.Key)"
        }
    }
}

# SSH 개인키 권한 설정
try {
    icacls "$HOME\.ssh\id_ed25519" /inheritance:r /grant:r "${env:USERNAME}:F" | Out-Null
    Write-LogOK "SSH 개인키 권한 설정 완료"
} catch {
    Write-LogWarn "SSH 키 권한 설정 실패: $_  → 수동 확인 필요"
}

# .git-credentials credential helper 설정
if (Test-Path "$HOME\.git-credentials") {
    git config --system credential.helper store
    git config --global credential.helper store
    Write-LogOK "credential.helper store 설정 완료"
}

# SSH config 설정
$sshConfigPath = "$HOME\.ssh\config"
if (-Not (Test-Path $sshConfigPath)) { New-Item -ItemType File -Force -Path $sshConfigPath | Out-Null }
if (-Not (Select-String -Path $sshConfigPath -Pattern "Host github.com" -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content -Path $sshConfigPath -Value "`nHost github.com`n  IdentityFile ~/.ssh/id_ed25519`n  User git`n  StrictHostKeyChecking no"
    Write-LogOK "SSH config 설정 완료"
} else {
    Write-LogOK "SSH config 이미 존재 (스킵)"
}

# GitHub known_hosts 등록
try {
    $githubKey = ssh-keyscan -t ed25519 github.com 2>$null
    if ($githubKey) {
        Add-Content -Path "$HOME\.ssh\known_hosts" -Value $githubKey
        Write-LogOK "GitHub known_hosts 등록 완료"
    } else {
        Write-LogWarn "GitHub known_hosts 등록 실패 → 네트워크 확인"
    }
} catch {
    Write-LogWarn "GitHub known_hosts 등록 중 오류: $_"
}

# GitHub SSH 연결 테스트
$sshTest = ssh -T git@github.com 2>&1
if ($sshTest -match "successfully authenticated") {
    Write-LogOK "GitHub SSH 인증 성공"
} else {
    Write-LogWarn "GitHub SSH 인증 실패 → Infisical 키 또는 GitHub 등록 확인 필요"
}

# ============================================================
# SSH 개인키 복원
# ============================================================
Write-Log "SSH 개인키 복원 중..."
New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
$sshKey = Get-InfisicalSecret "github_private_ssh_os_srzst" "/github"
if (-Not $sshKey) {
  Write-LogErr "SSH 개인키 복원 실패 → 토큰 및 키 이름 확인 후 재실행"
  exit 1
}
Set-Content -Path "$HOME\.ssh\id_ed25519" -Value $sshKey -NoNewline

try {
  icacls "$HOME\.ssh\id_ed25519" /inheritance:r /grant:r "${env:USERNAME}:F" | Out-Null
  Write-LogOK "SSH 개인키 권한 설정 완료"
} catch {
  Write-LogWarn "SSH 키 권한 설정 실패: $_  → 수동 확인 필요"
}
Write-LogOK "SSH 개인키 복원 완료"

# SSH config 설정
$sshConfigPath = "$HOME\.ssh\config"
if (-Not (Test-Path $sshConfigPath)) {
  New-Item -ItemType File -Force -Path $sshConfigPath | Out-Null
}
if (-Not (Select-String -Path $sshConfigPath -Pattern "Host github.com" -Quiet -ErrorAction SilentlyContinue)) {
  Add-Content -Path $sshConfigPath -Value "`nHost github.com`n  IdentityFile ~/.ssh/id_ed25519`n  User git`n  StrictHostKeyChecking no"
  Write-LogOK "SSH config 설정 완료"
} else {
  Write-LogOK "SSH config 이미 존재 (스킵)"
}

# GitHub known_hosts 등록
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

# GitHub SSH 연결 테스트
Write-Log "GitHub SSH 연결 테스트 중..."
$sshTest = ssh -T git@github.com 2>&1
if ($sshTest -match "successfully authenticated") {
  Write-LogOK "GitHub SSH 인증 성공"
} else {
  Write-LogWarn "GitHub SSH 인증 실패 → Infisical 키 또는 GitHub 등록 확인 필요"
}

# ============================================================
# 나머지 secrets 복원
# ============================================================
New-Item -ItemType Directory -Force -Path "$HOME\.aws" | Out-Null
$awsConfig      = Get-InfisicalSecret "config" "/aws"
$awsCredentials = Get-InfisicalSecret "credentials" "/aws"
if ($awsConfig)      { Set-Content -Path "$HOME\.aws\config"      -Value $awsConfig      -NoNewline; Write-LogOK ".aws/config 복원 완료" }
else                 { Write-LogWarn ".aws/config 복원 실패 (스킵)" }
if ($awsCredentials) { Set-Content -Path "$HOME\.aws\credentials"  -Value $awsCredentials -NoNewline; Write-LogOK ".aws/credentials 복원 완료" }
else                 { Write-LogWarn ".aws/credentials 복원 실패 (스킵)" }

New-Item -ItemType Directory -Force -Path "$HOME\.backblaze" | Out-Null
$bbApi = Get-InfisicalSecret "backblazeapi" "/backblaze"
if ($bbApi) { Set-Content -Path "$HOME\.backblaze\backblazeapi" -Value $bbApi -NoNewline; Write-LogOK ".backblaze 복원 완료" }
else        { Write-LogWarn ".backblaze 복원 실패 (스킵)" }

$gitCreds = Get-InfisicalSecret "git_credentials" "/github"
if ($gitCreds) {
  Set-Content -Path "$HOME\.git-credentials" -Value $gitCreds -NoNewline
  git config --system credential.helper store
  git config --global credential.helper store
  Write-LogOK ".git-credentials 복원 완료"
} else {
  Write-LogWarn ".git-credentials 복원 실패 (스킵)"
}

# ============================================================
# .dotfolders clone
# ============================================================
Write-Log ".dotfolders clone 중..."
if (-Not (Test-Path $FOLDERS)) {
  try {
    git clone "https://github.com/srzst/.dotfolders.git" $FOLDERS 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
    Write-LogOK ".dotfolders clone 완료"
  } catch {
    Write-LogErr ".dotfolders clone 실패: $_  → 인증 또는 repo 확인"
  }
} else {
  Write-LogOK ".dotfolders 이미 존재 (스킵)"
  git -C $FOLDERS pull 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
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
New-Symlink $PROFILE "$REPO\Alias\Windows\PowerShell\profile.ps1"
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
# ============================================================
if (-Not (Get-Command scoop -ErrorAction SilentlyContinue)) {
  Write-Log "Scoop 설치 중..."
  try {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    $env:SCOOP = "$HOME\scoop"
    [System.Environment]::SetEnvironmentVariable("SCOOP", "$HOME\scoop", "User")
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $scoopScript = Invoke-RestMethod -Uri "https://get.scoop.sh"
    Invoke-Expression "& {$scoopScript} -RunAsAdmin"
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
  scoop install gsudo vim curl rclone
  scoop bucket add extras
  scoop bucket add nerd-fonts
  scoop bucket add versions
  scoop update
  scoop install Hack-NF Hack-NF-Mono
  scoop install autohotkey1.1
  $ahkExe = "$HOME\scoop\apps\autohotkey1.1\current\AutoHotkeyU64.exe"
  cmd /c "assoc .ahk=AutoHotkeyScript" 2>&1 | Out-Null
  cmd /c "ftype AutoHotkeyScript=`"$ahkExe`" `"%1`" %*" 2>&1 | Out-Null
  Write-LogOK ".ahk 파일 연결 등록 완료"
  scoop install python nodejs
  scoop install neovim neovide lazygit tree-sitter yazi ffmpeg 7zip jq poppler fd ripgrep fzf zoxide imagemagick tabby tectonic pipx
  winget install --id=BrechtSanders.WinLibs.POSIX.UCRT -e --accept-package-agreements --accept-source-agreements 2>&1 | Out-Null
  Write-LogOK "Scoop 패키지 설치 완료"
} catch {
  Write-LogErr "Scoop 패키지 설치 중 오류: $_"
}

# ============================================================
# Chocolatey 설치
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
# Python UTF-8 모드 설정
# ============================================================
$utf8Status = [System.Environment]::GetEnvironmentVariable("PYTHONUTF8", "User")
if ($utf8Status -ne "1") {
  [System.Environment]::SetEnvironmentVariable("PYTHONUTF8", "1", "User")
  $env:PYTHONUTF8 = "1"
  Write-LogOK "PYTHONUTF8 등록 완료"
} else {
  Write-LogOK "PYTHONUTF8 이미 설정됨 (스킵)"
}

# ============================================================
# Winget 패키지 설치
# ============================================================
$wingetPath = "$env:LOCAlappdata\microsoft\WindowsApps"
if ($env:PATH -notlike "*windowsapps*") {
  $env:PATH += ";$wingetPath"
  Write-Log "winget PATH 강제 주입 완료"
}

Write-Log "winget 소스 업데이트 및 기존 앱 업그레이드..."
try {
  winget upgrade --all --accept-package-agreements --accept-source-agreements 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "winget 업그레이드 완료"
} catch {
  Write-LogWarn "winget 업그레이드 중 오류 (무시하고 계속): $_"
}

Write-Log "Winget 신규 패키지 설치 중..."
$wingetApps = @(
    "Microsoft.VisualStudiocode",
    "Anysphere.Cursor",
    "Brave.Brave",
    "Vivaldi.Vivaldi",
    "Bitwarden.Bitwarden",
    "GitHub.GitHubDesktop",
    "Microsoft.PowerToys",
    "Microsoft.PowerShell",
    "Obsidian.Obsidian",
    "Logseq.Logseq",
    "appmakes.Typora",
    "Iterate.MountainDuck",
    "Figma.Figma",
    "LocalSend.LocalSend"
)
foreach ($app in $wingetApps) {
  try {
    $result = winget install --id $app --exact `
      --accept-package-agreements --accept-source-agreements --scope user 2>&1
    Add-Content -Path $LOG_FILE -Value ($result | Out-String)
    if ($LASTEXITCODE -eq 0)            { Write-LogOK "winget 설치 완료: $app" }
    elseif ($LASTEXITCODE -eq -1978335189) { Write-LogOK "winget 이미 설치됨 (스킵): $app" }
    else                                { Write-LogWarn "winget 설치 실패 (exit $LASTEXITCODE): $app" }
  } catch {
    Write-LogErr "winget 예외 발생: $app : $_"
  }
}

$wingetAppsNoScope = @(
    "ZedIndustries.Zed",
    "NAVER.Whale",
    "Bandisoft.Bandizip",
    "Bandisoft.Honeyview",
    "CopyQ.CopyQ",
    "Kakao.KakaoTalk",
    "Google.Chrome"
)
foreach ($app in $wingetAppsNoScope) {
  try {
    $result = winget install -e --id $app `
      --accept-package-agreements --accept-source-agreements 2>&1
    Add-Content -Path $LOG_FILE -Value ($result | Out-String)
    if ($LASTEXITCODE -eq 0)            { Write-LogOK "winget 설치 완료: $app" }
    elseif ($LASTEXITCODE -eq -1978335189) { Write-LogOK "winget 이미 설치됨 (스킵): $app" }
    else                                { Write-LogWarn "winget 설치 실패 (exit $LASTEXITCODE): $app" }
  } catch {
    Write-LogErr "winget 예외 발생: $app : $_"
  }
}

# Raycast 설치
$raycastExe = "$FOLDERS\windows\Raycast\Raycast Installer.exe"
if (Get-AppxPackage -Name "*Raycast*" -ErrorAction SilentlyContinue) {
  Write-LogOK "Raycast 이미 설치됨 (스킵)"
} elseif (Test-Path $raycastExe) {
  Write-Log "Raycast 설치 중..."
  Start-Process $raycastExe -Wait
  Write-LogOK "Raycast 설치 완료"
} else {
  Write-LogWarn "Raycast 설치 파일 없음 → $raycastExe 확인 또는 https://raycast.com/windows 수동 설치"
}
Write-LogOK "Winget 패키지 설치 완료"

# ============================================================
# pip / pipx / npm 패키지 설치
# ============================================================
Write-Log "pip 패키지 설치 중..."
try {
  python -m pip install "urllib3<2.0.0" | Tee-Object -Append -FilePath $LOG_FILE
  python -m pip install `
    pyperclip regex requests mistune boto3 clipboard pillow win10toast pywin32 plyer `
    b2sdk pynput watchdog send2trash PyQt5 pygments pandas tabulate oauth2client gspread `
    google-api-python-client langdetect pyautogui dropbox pyinstaller cloudinary==1.26.0 pyimgur `
    | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "pip 패키지 설치 완료"
} catch {
  Write-LogErr "pip 패키지 설치 실패: $_"
}

$userPath  = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$cleanPath = ($userPath -split ';' | Where-Object { $_.ToLower() -notlike "*\roaming\python\*" }) -join ';'
[System.Environment]::SetEnvironmentVariable("PATH", $cleanPath, "User")
$env:PATH  = ($env:PATH -split ';' | Where-Object { $_.ToLower() -notlike "*\roaming\python\*" }) -join ';'
$env:PATH  = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")

try {
  pipx install gita | Tee-Object -Append -FilePath $LOG_FILE
  pipx ensurepath
  $env:PATH = "$HOME\.local\bin;" + $env:PATH
  gita add $REPO 2>$null
  Write-LogOK "pipx/gita 설치 및 .dotfiles 등록 완료"
} catch {
  Write-LogErr "pipx/gita 설치 실패: $_"
}

try {
  npm install -g electron | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK "npm 패키지 설치 완료"
} catch {
  Write-LogErr "npm 패키지 설치 실패: $_"
}

# ============================================================
# UpNote 설치
# ============================================================
$upNoteTarget = "C:\Program Files\UpNote\UpNote.exe"
if (Test-Path $upNoteTarget) {
  Write-LogOK "UpNote 이미 설치됨 (스킵)"
} else {
  try {
    $upNoteInstaller = "$env:TEMP\UpNoteSetup.exe"
    Invoke-WebRequest -Uri "https://download.getupnote.com/app/UpNote%20Setup.exe" -OutFile $upNoteInstaller -UseBasicParsing
    Start-Process -FilePath $upNoteInstaller -ArgumentList "/S" -Wait
    Write-LogOK "UpNote 설치 완료"
  } catch {
    Write-LogErr "UpNote 설치 실패: $_  → https://getupnote.com 수동 설치"
  } finally {
    Remove-Item $upNoteInstaller -ErrorAction SilentlyContinue
  }
}

# ============================================================
# Snipdo 설치
# ============================================================
$snipDoPackage = "JohannesTscholl.Pantherbar"
if (Get-AppxPackage -Name $snipDoPackage -ErrorAction SilentlyContinue) {
  Write-LogOK "Snipdo 이미 설치됨 (스킵)"
} else {
  try {
    $appInstallerUrl = "https://snipdo-app.com/wp-content/uploads/bins/SnipDo.appinstaller"
    $xmlContent = Invoke-RestMethod -Uri $appInstallerUrl -UseBasicParsing
    $msixUrl = ([xml]$xmlContent).AppInstaller.MainBundle.Uri
    if (-Not $msixUrl) { throw ".appinstaller에서 msixbundle URL 파싱 실패" }
    $snipDoBundle = "$env:TEMP\SnipDo.msixbundle"
    Invoke-WebRequest -Uri $msixUrl -OutFile $snipDoBundle -UseBasicParsing
    Add-AppxPackage -Path $snipDoBundle
    Write-LogOK "Snipdo 설치 완료"
  } catch {
    Write-LogErr "Snipdo 설치 실패: $_  → https://snipdo-app.com 수동 설치"
  } finally {
    Remove-Item "$env:TEMP\SnipDo.msixbundle" -ErrorAction SilentlyContinue
  }
}

# ============================================================
# WinSnap 설치 및 레지스트리 복원
# ============================================================
$winSnapInstaller = "$FOLDERS\windows\winsnap\v6.2.2_main\6.2.2-setup.exe"
$winSnapReg       = "$FOLDERS\windows\winsnap\v6.2.2_main\registry_backup.reg"
$winSnapTarget    = "C:\Program Files\WinSnap\WinSnap.exe"
$winSnapStartup   = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"

if (Test-Path $winSnapTarget) {
  Write-LogOK "WinSnap 이미 설치됨 (스킵)"
} elseif (Test-Path $winSnapInstaller) {
  Start-Process -FilePath $winSnapInstaller -ArgumentList "/S" -Wait
  Start-Sleep -Seconds 2
  Write-LogOK "WinSnap 설치 완료"
} else {
  Write-LogWarn "WinSnap 설치 파일 없음 (스킵): $winSnapInstaller"
}

if (Test-Path $winSnapReg) {
  $regContent = Get-Content $winSnapReg -Raw
  $regContent = $regContent -replace "C:\\\\Users\\\\x\\\\", "C:\\\\Users\\\\${env:USERNAME}\\\\"
  $tempReg = "$env:TEMP\winsnap_temp.reg"
  Set-Content -Path $tempReg -Value $regContent -Encoding Unicode
  reg import $tempReg
  Remove-Item $tempReg -ErrorAction SilentlyContinue
  Write-LogOK "WinSnap 레지스트리 복원 완료"
} else {
  Write-LogWarn "WinSnap 레지스트리 파일 없음 (스킵): $winSnapReg"
}

# ============================================================
# FastStone Capture 설치
# ============================================================
$fscInstaller = "$FOLDERS\windows\FastStone\FSCaptureSetup112.exe"
$fscTarget    = "C:\Program Files (x86)\FastStone Capture\FSCapture.exe"
if (Test-Path $fscTarget) {
  Write-LogOK "FastStone Capture 이미 설치됨 (스킵)"
} elseif (Test-Path $fscInstaller) {
  Start-Process -FilePath $fscInstaller -ArgumentList "/S" -Wait
  Write-LogOK "FastStone Capture 설치 완료"
} else {
  Write-LogWarn "FastStone Capture 설치 파일 없음 (스킵): $fscInstaller"
}

# ============================================================
# GitHub Desktop 호환 - remote HTTPS 변경
# ============================================================
try {
  git -C $REPO remote set-url origin "https://github.com/srzst/.dotfiles.git" 2>&1 | Tee-Object -Append -FilePath $LOG_FILE
  Write-LogOK ".dotfiles remote HTTPS 변경 완료"
} catch {
  Write-LogErr ".dotfiles remote 변경 실패: $_"
}

# ============================================================
# 시작 프로그램 및 스케줄 작업 등록
# ============================================================
$startupScript = "$FOLDERS\windows\ps1\startup_register.ps1"
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
# 레지스트리 설정 복원
# ============================================================
Set-ItemProperty -Path "HKCU:\Software\Microsoft\InputMethod\Settings\KOR" -Name "EnableCompatibilityMode" -Value 1 -Type DWord
Write-LogOK "Microsoft IME 이전 버전 호환 모드 설정 완료"

# ============================================================
# 마우스 커서 설치
# ============================================================
$cursorZip    = "$FOLDERS\windows\etc\windows_11_cursors_concept_v2_by_jepricreations_densjkc.zip"
$cursorExtDir = "$env:TEMP\cursors_install"
$cursorInf    = "$cursorExtDir\light\cursor\Install.inf"

if (Test-Path $cursorZip) {
  try {
    Expand-Archive -Path $cursorZip -DestinationPath $cursorExtDir -Force
    rundll32 setupapi.dll,InstallHinfSection DefaultInstall 128 $cursorInf
    $CursorReload = Add-Type -MemberDefinition @"
      [DllImport("user32.dll")]
      public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
"@ -Name "CursorReload" -Namespace "Win32" -PassThru
    $CursorReload::SystemParametersInfo(0x0057, 0, $null, 3)
    Write-LogOK "마우스 커서 설치 완료"
  } catch {
    Write-LogErr "마우스 커서 설치 실패: $_"
  } finally {
    Remove-Item $cursorExtDir -Recurse -ErrorAction SilentlyContinue
  }
} else {
  Write-LogWarn "커서 파일 없음 (스킵): $cursorZip"
}

# ============================================================
# 앱 설정 복원
# ============================================================

# FastStone Capture
$fscSrc = "$HOME\.dotfolders\windows\FastStone\FSC"
$fscDst = "$env:APPDATA\FastStone\FSC"
if (Test-Path $fscSrc) {
  Remove-Item $fscDst -Recurse -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Split-Path $fscDst) | Out-Null
  New-Item -ItemType SymbolicLink -Path $fscDst -Target $fscSrc | Out-Null
  Write-LogOK "FastStone 설정 연결 완료"
} else {
  Write-LogWarn "FastStone 설정 파일 없음 (스킵): $fscSrc"
}

# Raycast
$raycastSrc = "$HOME\.dotfolders\windows\Raycast"
$raycastDst = "$env:LOCALAPPDATA\Raycast"
@("settings.db", "settings_v2.db") | ForEach-Object {
  $src = "$raycastSrc\$_"
  if (-Not (Test-Path $src)) { Write-LogWarn "Raycast 설정 파일 없음 (스킵): $src"; return }
  if (-Not (Test-Path $raycastDst)) { Write-LogWarn "Raycast 미설치 — 설정 복원 건너뜀: $_ (설치 후 재실행 필요)"; return }
  Copy-Item $src $raycastDst -Force
  Write-LogOK "Raycast 설정 복원 완료: $_"
}

# Mountain Duck
$mdSrc = "$HOME\.dotfolders\windows\MountainDuck"
$mdDst = "$env:APPDATA\Cyberduck"
if (Test-Path $mdSrc) {
  New-Item -ItemType Directory -Force -Path $mdDst | Out-Null
  Copy-Item "$mdSrc\*.mountainducklicense" $mdDst -Force
  Copy-Item "$mdSrc\Mountain Duck.user.config" $mdDst -Force
  if (Test-Path "$mdSrc\Bookmarks") {
    Remove-Item "$mdDst\Bookmarks" -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path "$mdDst\Bookmarks" | Out-Null
    Copy-Item "$mdSrc\Bookmarks\*" "$mdDst\Bookmarks\" -Recurse -Force
  }
  Write-LogOK "Mountain Duck 설정 복원 완료"
} else {
  Write-LogWarn "Mountain Duck 설정 파일 없음 (스킵): $mdSrc"
}

# Windows Terminal
$wtSrc = "$HOME\.dotfolders\windows\terminal\settings.json"
$wtDst = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (Test-Path $wtSrc) {
  Remove-Item $wtDst -Force -ErrorAction SilentlyContinue
  New-Item -ItemType SymbolicLink -Path $wtDst -Target $wtSrc | Out-Null
  Write-LogOK "Windows Terminal 설정 연결 완료"
} else {
  Write-LogWarn "Windows Terminal 설정 파일 없음 (스킵): $wtSrc"
}

# Tabby
$tabbySrc = "$HOME\.dotfolders\windows\Tabby\config.yaml"
$tabbyDst = "$env:APPDATA\tabby\config.yaml"
if (Test-Path $tabbySrc) {
  Remove-Item $tabbyDst -Force -ErrorAction SilentlyContinue
  New-Item -ItemType Directory -Force -Path (Split-Path $tabbyDst) | Out-Null
  New-Item -ItemType SymbolicLink -Path $tabbyDst -Target $tabbySrc | Out-Null
  Write-LogOK "Tabby 설정 연결 완료"
} else {
  Write-LogWarn "Tabby 설정 파일 없음 (스킵): $tabbySrc"
}

# Snipdo
$snipSrc = "$HOME\.dotfolders\windows\snipdo"
$snipDst = "$env:LOCALAPPDATA\Packages\JohannesTscholl.Pantherbar_3hp4skfxf5x2g\LocalState"
if (-Not (Test-Path $snipSrc)) {
  Write-LogWarn "Snipdo 설정 파일 없음 (스킵): $snipSrc"
} elseif (-Not (Test-Path $snipDst)) {
  Write-LogWarn "Snipdo 미설치 — 설정 복원 건너뜀 (설치 후 재실행 필요)"
} else {
  Copy-Item "$snipSrc\*" $snipDst -Force -Recurse -Exclude "*.appinstaller"
  Write-LogOK "Snipdo 설정 복원 완료"
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
# ============================================================
Write-Host ""
Write-Log "INFO 수동 설치 필요 항목:"
Write-Host "    Jump Desktop      - https://jumpdesktop.com/download.html"
Write-Host "    PhotoScape X Pro  - MS Store"
Write-Host "    Zoho Mail Desktop - https://zoho.com/mail/desktop-app.html"
Write-Host "    Blip              - https://www.blip.com"

# ============================================================
# Raycast 설정 복원 안내
# ============================================================
Write-Host ""
Write-Log "INFO Raycast 튜토리얼 완료 후 아래 명령 실행:"
Write-Host "    Stop-Process -Name 'Raycast' -Force -ErrorAction SilentlyContinue"
Write-Host "    Copy-Item `"$HOME\.dotfolders\windows\Raycast\settings.db`" `"$env:LOCALAPPDATA\Raycast\`" -Force"
Write-Host "    Copy-Item `"$HOME\.dotfolders\windows\Raycast\settings_v2.db`" `"$env:LOCALAPPDATA\Raycast\`" -Force"

# ============================================================
# 최종 요약
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