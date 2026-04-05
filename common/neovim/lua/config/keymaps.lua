-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- === 1. Global Actions: gd (Delete All), gy (Yank All), gx (Cut All) ===
vim.keymap.set("n", "gd", 'gg"_dG', { noremap = true, silent = true, desc = "Delete all (Blackhole)" })
vim.keymap.set("n", "gy", 'gg"+yG', { noremap = true, silent = true, desc = "Yank all to system clipboard" })
vim.keymap.set("n", "gx", 'gg"+dG', { noremap = true, silent = true, desc = "Cut all to system clipboard" })
-- === 2. Clipboard Protection: d, c, dd (Blackhole Register) ===
vim.keymap.set({ "n", "v" }, "d", '"_d', { noremap = true, desc = "Delete without yank" })
vim.keymap.set("n", "dd", '"_dd', { noremap = true, desc = "Delete line without yank" })
vim.keymap.set({ "n", "v" }, "c", '"_c', { noremap = true, desc = "Change without yank" })
-- === 3. x: 잘라내기 (시스템 클립보드 "+" 레지스터 사용) ===
vim.keymap.set("n", "x", '"+x', { noremap = true, desc = "Cut char to system clipboard" })
vim.keymap.set("v", "x", '"+d', { noremap = true, desc = "Cut selection to system clipboard" })
-- === 4. 붙여넣기(p) 설정 ===
vim.keymap.set({ "n", "v" }, "p", '"+p', { noremap = true, desc = "Paste from system clipboard" })
-- === 5. LSP 매핑 강제 덮어쓰기 ===
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    vim.defer_fn(function()
      local opts = { buffer = args.buf, noremap = true, silent = true }
      vim.keymap.set("n", "gd", 'gg"_dG', opts)
      vim.keymap.set("n", "gy", 'gg"+yG', opts)
      vim.keymap.set("n", "gx", 'gg"+dG', opts)
    end, 100)
  end,
})
