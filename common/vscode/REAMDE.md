**macOS**
완료(2026-03-25(수))

```bash
ln -sf "$HOME/.dotfiles/common/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
ln -sf "$HOME/.dotfiles/common/vscode/keybindings.json" "$HOME/Library/Application Support/Cursor/User/keybindings.json"
ln -sf "$HOME/.dotfiles/common/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
ln -sf "$HOME/.dotfiles/common/vscode/settings.json" "$HOME/Library/Application Support/Cursor/User/settings.json"
ln -sf "$HOME/.dotfolders/common/tabby/config.yaml" "$HOME/Library/Application Support/tabby/config.yaml"
```

---

**Windows**

```powershell
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Code\User\keybindings.json"   -Target "$HOME\.dotfiles\common\vscode\keybindings.json"
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Cursor\User\keybindings.json" -Target "$HOME\.dotfiles\common\vscode\keybindings.json"
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Code\User\settings.json"      -Target "$HOME\.dotfiles\common\vscode\settings.json"
New-Item -ItemType SymbolicLink -Force -Path "$env:APPDATA\Cursor\User\settings.json"    -Target "$HOME\.dotfiles\common\vscode\settings.json"
```
