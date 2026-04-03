-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua

-- === 1. Global Actions: gd (Delete All), gy (Yank All), gx (Cut All) ===
-- LazyVim의 기본 LSP gd 매핑을 무시하고 사용자 정의 매핑을 강제합니다.
vim.keymap.set('n', 'gd', 'gg"_dG', { noremap = true, silent = true, desc = 'Delete all (Blackhole)' })
vim.keymap.set('n', 'gy', 'gg"+yG', { noremap = true, silent = true, desc = 'Yank all to system clipboard' })
vim.keymap.set('n', 'gx', 'gg"+dG', { noremap = true, silent = true, desc = 'Cut all to system clipboard' })


-- === 2. Clipboard Protection: d, c, dd (Blackhole Register) ===
-- 삭제(d)와 변경(c) 시 기존 클립보드 내용을 유지합니다.
vim.keymap.set({'n', 'v'}, 'd', '"_d', { noremap = true, desc = 'Delete without yank' })
vim.keymap.set('n', 'dd', '"_dd', { noremap = true, desc = 'Delete line without yank' })
vim.keymap.set({'n', 'v'}, 'c', '"_c', { noremap = true, desc = 'Change without yank' })


-- === 3. x: 잘라내기 (시스템 클립보드 "+" 레지스터 사용) ===
-- 단일 문자 삭제(n) 및 선택 영역 삭제(v) 시 시스템 클립보드에 저장합니다.
-- 사용자님 원칙: x는 잘라내기 (복사됨)
vim.keymap.set('n', 'x', '"+x', { noremap = true, desc = 'Cut char to system clipboard' })
vim.keymap.set('v', 'x', '"+d', { noremap = true, desc = 'Cut selection to system clipboard' })


-- === 4. 붙여넣기(p) 설정 ===
-- 시스템 클립보드 내용을 기본으로 붙여넣습니다.
vim.keymap.set({'n', 'v'}, 'p', '"+p', { noremap = true, desc = 'Paste from system clipboard' })


-- === 5. LSP 매핑 강제 덮어쓰기 (중요) ===
-- LazyVim은 LSP가 붙을 때 gd를 다시 매핑하므로, 이를 방지하기 위한 콜백입니다.
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(args)
    local opts = { buffer = args.buf, noremap = true, silent = true }
    -- LSP의 정의 이동(gd)을 죽이고 사용자님의 전체 삭제를 다시 할당
    vim.keymap.set('n', 'gd', 'gg"_dG', opts)
  end,
})