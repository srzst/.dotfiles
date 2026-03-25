# windows\install\01_basic_bootstrap_windows.ps1

# ============================================================
# CONFIG
# ============================================================
$TARGET = 2  # 0: 복구  1: 기본  2: 경량  3: 임시
$MODE   = 2  # 1: install  2: bootstrap

$BOOTSTRAP_TOKEN_URL  = "https://dl.srz.st/t.enc"
$INFISICAL_PROJECT_ID = "bc893247-af3f-4118-a8ec-bcb429338acb"
$INFISICAL_ENV        = "dev"
$REPO                 = "$HOME\.dotfiles"
$FOLDERS              = "$HOME\.dotfolders"
$MACHINE_TYPE         = "main"
# ============================================================
