$REPO = "$HOME\.dotfiles"
# Windows PowerShell 프로필
Remove-Item "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Force `
  -Path "$HOME\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1" `
  -Target "$REPO\Alias\Windows\PowerShell\profile.ps1"
Write-Host "OK Windows PowerShell 프로필 연결 완료"
# PowerShell Core 프로필
Remove-Item "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" -Force -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Force `
  -Path "$HOME\Documents\PowerShell\Microsoft.PowerShell_profile.ps1" `
  -Target "$REPO\Alias\Windows\PowerShell_Core\profile.ps1"
Write-Host "OK PowerShell Core 프로필 연결 완료"
# Neovim
$nvimTarget = "$HOME\AppData\Local\nvim"
if (Test-Path $nvimTarget) { Remove-Item $nvimTarget -Recurse -Force }
New-Item -ItemType SymbolicLink -Force `
  -Path $nvimTarget `
  -Target "$REPO\neovim"
Write-Host "OK Neovim 연결 완료"
# Zed
Remove-Item "$HOME\AppData\Roaming\Zed\settings.json" -Force -ErrorAction SilentlyContinue
New-Item -ItemType SymbolicLink -Force `
  -Path "$HOME\AppData\Roaming\Zed\settings.json" `
  -Target "$REPO\zed\settings.json"
Write-Host "OK Zed 설정 연결 완료"
# BWS 액세스 토큰 (사용자 환경변수)
$existingToken = [System.Environment]::GetEnvironmentVariable("BWS_ACCESS_TOKEN", "User")
if (-Not $existingToken) {
  Write-Host ""
  $bwsToken = Read-Host "BWS 액세스 토큰을 입력하세요"
  [System.Environment]::SetEnvironmentVariable("BWS_ACCESS_TOKEN", $bwsToken, "User")
  $env:BWS_ACCESS_TOKEN = $bwsToken
  Write-Host "OK BWS_ACCESS_TOKEN 사용자 환경변수 등록 완료 (재시작 후 적용)"
} else {
  Write-Host "OK BWS_ACCESS_TOKEN 이미 존재 (스킵)"
}
# 글로벌 gitignore 설정
$gitignorePath = "$HOME\.gitignore_global"
git config --global core.excludesfile $gitignorePath
$existingContent = if (Test-Path $gitignorePath) { Get-Content $gitignorePath } else { @() }
if ($existingContent -notcontains '*_secrets*') { Add-Content -Path $gitignorePath -Value '*_secrets*' }
Write-Host "OK 글로벌 gitignore 설정 완료"
# BWS secrets 복원
$BWS_BIN = "$HOME\bws\bws.exe"
function Fetch-Secret($id) {
  $raw = & $BWS_BIN secret get $id 2>$null
  $json = $raw | ConvertFrom-Json
  return $json.value
}
# .aws
New-Item -ItemType Directory -Force -Path "$HOME\.aws" | Out-Null
Fetch-Secret "95831a03-5ddd-46de-ac7c-b40000d57326" | Set-Content -Path "$HOME\.aws\config" -NoNewline
Fetch-Secret "96f60cf0-88f7-474d-9336-b40000d54799" | Set-Content -Path "$HOME\.aws\credentials" -NoNewline
Write-Host "OK .aws 완료"
# .backblaze
New-Item -ItemType Directory -Force -Path "$HOME\.backblaze" | Out-Null
Fetch-Secret "fd5852f6-8474-4fac-9888-b40000d8ea90" | Set-Content -Path "$HOME\.backblaze\backblazeapi" -NoNewline
Write-Host "OK .backblaze 완료"
# .git-credentials
Fetch-Secret "711d2b06-8271-4470-8e63-b40000d9129f" | Set-Content -Path "$HOME\.git-credentials" -NoNewline
Write-Host "OK .git-credentials 완료"
# GitBash (.bashrc 는 GitBash 터미널 안에서 실행)
Write-Host ""
Write-Host "INFO GitBash .bashrc 는 GitBash 터미널에서 아래 명령 실행:"
Write-Host "    REPO=""/c/Users/$env:USERNAME/.dotfiles"""
Write-Host "    rm ~/.bashrc"
Write-Host "    ln -sf ""`$REPO/Alias/Windows/GitBash/.bashrc"" ~/.bashrc"
Write-Host ""
Write-Host "OK Windows 설치 완료"
# ============================================================
# 관리자 권한 PowerShell에서:
# & "$HOME\.dotfiles\_install\install_windows.ps1"
#
# GitBash 추가 작업:
# REPO="/c/Users/$USERNAME/.dotfiles"
# rm ~/.bashrc
# ln -sf "$REPO/Alias/Windows/GitBash/.bashrc" ~/.bashrc
# ============================================================