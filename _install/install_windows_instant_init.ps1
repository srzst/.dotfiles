# ============================================================
# install_windows_tmp.ps1
# 임시 PC 빠른 세팅 스크립트
# 관리자 PowerShell에서 실행:
# & "$HOME\.dotfiles\_install\install_windows_tmp.ps1"
# ============================================================

$INFISICAL_PROJECT_ID = "bc893247-af3f-4118-a8ec-bcb429338acb"
$INFISICAL_ENV        = "dev"

Write-Host "========== 임시 세팅 시작 =========="

# ============================================================
# 1. Infisical 토큰
# ============================================================
$existingToken = [System.Environment]::GetEnvironmentVariable("INFISICAL_TOKEN", "User")
if (-Not $existingToken) {
    $inputToken = Read-Host "Infisical 서비스 토큰을 입력하세요"
    [System.Environment]::SetEnvironmentVariable("INFISICAL_TOKEN", $inputToken, "User")
    $env:INFISICAL_TOKEN = $inputToken
    Write-Host "OK INFISICAL_TOKEN 등록 완료"
} else {
    $env:INFISICAL_TOKEN = $existingToken
    Write-Host "OK INFISICAL_TOKEN 이미 존재 (스킵)"
}

# Infisical 함수
function Get-InfisicalSecret {
    param([string]$Key, [string]$Path = "/")
    try {
        $val = infisical secrets get $Key `
            --projectId=$INFISICAL_PROJECT_ID `
            --env=$INFISICAL_ENV `
            --path=$Path `
            --plain --silent 2>$null
        return $val
    } catch { return $null }
}

# ============================================================
# 2. Infisical CLI 설치
# ============================================================
if (-Not (Get-Command infisical -ErrorAction SilentlyContinue)) {
    winget install --id Infisical.infisical -e --accept-package-agreements --accept-source-agreements
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Host "OK Infisical CLI 설치 완료"
}

# ============================================================
# 3. Scoop + 핵심 패키지
# ============================================================
if (-Not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
    Invoke-Expression (New-Object System.Net.WebClient).DownloadString('https://get.scoop.sh')
    $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
    Write-Host "OK Scoop 설치 완료"
}

scoop install git vim curl rclone python neovim fzf ripgrep 7zip
Write-Host "OK 핵심 패키지 설치 완료"

# ============================================================
# 4. Git 설정
# ============================================================
git config --global user.email "x@srzst.com"
git config --global user.name  "x"
git config --global credential.helper store
git config --global pull.rebase true
Write-Host "OK Git 설정 완료"

# ============================================================
# 5. SSH 개인키 복원
# ============================================================
New-Item -ItemType Directory -Force -Path "$HOME\.ssh" | Out-Null
$sshKey = Get-InfisicalSecret "github_private_ssh_os_srzst" "/github"
if ($sshKey) {
    Set-Content -Path "$HOME\.ssh\id_ed25519" -Value $sshKey -NoNewline
    icacls "$HOME\.ssh\id_ed25519" /inheritance:r /grant:r "${env:USERNAME}:F" | Out-Null
    Write-Host "OK SSH 개인키 복원 완료"
} else {
    Write-Host "WARN SSH 개인키 복원 실패"
}

# SSH config
$sshConfigPath = "$HOME\.ssh\config"
if (-Not (Test-Path $sshConfigPath)) { New-Item -ItemType File -Force -Path $sshConfigPath | Out-Null }
if (-Not (Select-String -Path $sshConfigPath -Pattern "Host github.com" -Quiet -ErrorAction SilentlyContinue)) {
    Add-Content -Path $sshConfigPath -Value "`nHost github.com`n  IdentityFile ~/.ssh/id_ed25519`n  User git`n  StrictHostKeyChecking no"
}
ssh-keyscan -t ed25519 github.com 2>$null | Add-Content "$HOME\.ssh\known_hosts"
Write-Host "OK SSH 설정 완료"

# ============================================================
# 6. git-credentials 복원
# ============================================================
$gitCreds = Get-InfisicalSecret "git_credentials" "/github"
if ($gitCreds) {
    Set-Content -Path "$HOME\.git-credentials" -Value $gitCreds -NoNewline
    Write-Host "OK .git-credentials 복원 완료"
}

# ============================================================
# 7. rclone.conf 복원
# ============================================================
New-Item -ItemType Directory -Force -Path "$HOME\.config\rclone" | Out-Null
$rcloneConf = Get-InfisicalSecret "rclone_onedrive_sv" "/rclone"
if ($rcloneConf) {
    Set-Content -Path "$HOME\.config\rclone\rclone.conf" -Value $rcloneConf -NoNewline
    Write-Host "OK rclone.conf 복원 완료"
}

# ============================================================
# 8. AutoHotkey 1.1
# ============================================================
scoop bucket add versions
scoop install autohotkey1.1
$ahkExe = "$HOME\scoop\apps\autohotkey1.1\current\AutoHotkeyU64.exe"
cmd /c "assoc .ahk=AutoHotkeyScript" 2>&1 | Out-Null
cmd /c "ftype AutoHotkeyScript=`"$ahkExe`" `"%1`" %*" 2>&1 | Out-Null
Write-Host "OK AutoHotkey 1.1 설치 및 .ahk 연결 완료"

# ============================================================
# 9. 저장소 clone
# ============================================================
$repos = @(
    @{ Url = "https://github.com/srzst/.dotfiles.git";   Dest = "$HOME\.dotfiles"   },
    @{ Url = "https://github.com/srzst/.dotfolders.git"; Dest = "$HOME\.dotfolders" }
)
foreach ($r in $repos) {
    if (-Not (Test-Path $r.Dest)) {
        git clone $r.Url $r.Dest
        Write-Host "OK clone 완료: $($r.Dest)"
    } else {
        git -C $r.Dest pull
        Write-Host "OK 이미 존재 (pull 완료): $($r.Dest)"
    }
}

Write-Host ""
Write-Host "========== 임시 세팅 완료 =========="
Write-Host "INFO 정리 시: & '.\cleanup_windows_tmp.ps1'"