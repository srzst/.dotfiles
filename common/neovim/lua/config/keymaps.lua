-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- bootstrap lazy.nvim, LazyVim and your plugins

-- === Global Actions: gd (Delete All) & gy (Yank All) ===
vim.keymap.set('n', 'gd', 'gg"_dG', { noremap = true, silent = true, desc = 'Delete all (Blackhole)' })
vim.keymap.set('n', 'gy', 'gg"+yG', { noremap = true, silent = true, desc = 'Yank all to system clipboard' })
-- ============================================================

-- === Clipboard Protection: Delete/Change to Blackhole Register ===
vim.keymap.set('n', 'ggdG', 'gg"_dG', { noremap = true, silent = true, desc = 'Delete all (Legacy)' })
vim.keymap.set({'n', 'v'}, 'd', '"_d', { noremap = true, desc = 'Delete without yank' })
vim.keymap.set({'n', 'v'}, 'x', '"_x', { noremap = true, desc = 'Delete char without yank' })
vim.keymap.set({'n', 'v'}, 'c', '"_c', { noremap = true, desc = 'Change without yank' })
vim.keymap.set('n', 'dd', '"_dd', { noremap = true, desc = 'Delete line without yank' })
-- ============================================================