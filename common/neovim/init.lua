
-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Neovide 전용 설정
if vim.g.neovide then
  vim.o.guifont = "Hack Nerd Font:h15"
  vim.g.neovide_scale_factor = 1.0
  vim.g.neovide_opacity = 0.8
  vim.g.neovide_window_blurred = true
end