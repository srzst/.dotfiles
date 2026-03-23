-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

-- Neovide 전용 설정
if vim.g.neovide then
  -- 1. Hack 너드 폰트를 사용하는 경우
  vim.o.guifont = "Hack Nerd Font:h10"

  -- 2. 만약 Fira Code를 선호하신다면 아래 줄의 주석을 해제하고 위 줄을 지우세요.
  -- vim.o.guifont = "FiraCode Nerd Font:h10"

  -- 글자 크기가 여전히 크다면 h10을 h9 등으로 낮추세요.
  vim.g.neovide_scale_factor = 1.0
end

if vim.g.neovide then
  -- (최신 버전 권장 방식: 0.0 ~ 1.0 사이 값)
  vim.g.neovide_opacity = 0.8

  -- 2. 윈도우 블러 효과는 그대로 유지 (가독성 향상)
  vim.g.neovide_window_blurred = true

  -- 3. 폰트 설정 (기존에 잘 되던 설정 유지)
  vim.o.guifont = "Hack Nerd Font:h10"
end
