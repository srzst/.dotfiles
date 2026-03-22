# ============================================================
# cleanup_windows_tmp.ps1
# 임시 세팅 원상복구 스크립트
# 관리자 PowerShell에서 실행:
# & ".\cleanup_windows_tmp.ps1"
# ============================================================

Write-Host "========== 임시 세팅 정리 시작 =========="

# ============================================================
# 1. Infisical 토큰 제거
# ============================================================
[System.Environment]::SetEnvironmentVariable("INFISICAL_TOKEN", $null, "User")
$env:INFISICAL_TOKEN = $null
Write-Host "OK INFISICAL_TOKEN 제거 완료"

# ============================================================
# 2. SSH 키 및 설정 제거
# ============================================================
Remove-Item "$HOME\.ssh\id_ed25519"       -Force -ErrorAction SilentlyContinue
Remove-Item "$HOME\.ssh\id_ed25519.pub"   -Force -ErrorAction SilentlyContinue
Remove-Item "$HOME\.ssh\known_hosts"       -Force -ErrorAction SilentlyContinue
Remove-Item "$HOME\.ssh\config"            -Force -ErrorAction SilentlyContinue
Write-Host "OK SSH 파일 제거 완료"

# ============================================================
# 3. Git 자격증명 제거
# ============================================================
Remove-Item "$HOME\.git-credentials" -Force -ErrorAction SilentlyContinue
git config --global --unset credential.helper
git config --global --unset user.email
git config --global --unset user.name
git config --global --unset pull.rebase
Write-Host "OK Git 자격증명 및 설정 제거 완료"

# ============================================================
# 4. rclone.conf 제거
# ============================================================
Remove-Item "$HOME\.config\rclone\rclone.conf" -Force -ErrorAction SilentlyContinue
Write-Host "OK rclone.conf 제거 완료"

# ============================================================
# 5. Scoop 패키지 제거
# ============================================================
$scoopApps = @("git", "vim", "curl", "rclone", "python", "neovim", "fzf", "ripgrep", "7zip", "autohotkey1.1", "infisical")
foreach ($app in $scoopApps) {
    scoop uninstall $app 2>$null
    Write-Host "OK scoop 제거: $app"
}

# ============================================================
# 6. 저장소 제거
# ============================================================
Remove-Item "$HOME\.dotfiles"   -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$HOME\.dotfolders" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "OK 저장소 제거 완료"

# ============================================================
# 6. 크리덴셜 매니저 제거 (Windows Credential Manager)
# ============================================================
$targets = @("git:https://github.com", "github.com")
foreach ($target in $targets) {
    cmdkey /delete:$target 2>$null
}
Write-Host "OK Windows Credential Manager 항목 제거 완료"

# ============================================================
# 7. 환경변수 PATH 정리
# ============================================================
$userPath = [System.Environment]::GetEnvironmentVariable("PATH", "User")
$cleanPath = ($userPath -split ';' | Where-Object {
    $_ -notlike "*scoop*" -and $_ -notlike "*infisical*"
}) -join ';'
[System.Environment]::SetEnvironmentVariable("PATH", $cleanPath, "User")
Write-Host "OK PATH 정리 완료"

Write-Host ""
Write-Host "========== 정리 완료 =========="
Write-Host "INFO 민감 정보가 남아있을 수 있으니 PC 재시작을 권장합니다."