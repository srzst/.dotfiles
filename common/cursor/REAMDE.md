**macOS**
완료(2026-03-25(수))

```bash
# VSCode
ln -sf "$HOME/.dotfiles/common/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
ln -sf "$HOME/.dotfiles/common/vscode/settings.json"    "$HOME/Library/Application Support/Code/User/settings.json"

# Cursor
ln -sf "$HOME/.dotfiles/common/cursor/keybindings.json" "$HOME/Library/Application Support/Cursor/User/keybindings.json"
ln -sf "$HOME/.dotfiles/common/cursor/settings.json"    "$HOME/Library/Application Support/Cursor/User/settings.json"

```

---

**Windows**

```powershell
# VSCode
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Code\User\keybindings.json"   -Target "$HOME\.dotfiles\common\vscode\keybindings.json"
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Code\User\settings.json"      -Target "$HOME\.dotfiles\common\vscode\settings.json"

# Cursor
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Cursor\User\keybindings.json" -Target "$HOME\.dotfiles\common\cursor\keybindings.json"
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Cursor\User\settings.json"    -Target "$HOME\.dotfiles\common\cursor\settings.json"
```
