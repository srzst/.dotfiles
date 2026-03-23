-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- if vim.fn.has("win32") == 1 then
--   vim.o.shell = "powershell"
--   vim.o.shellcmdflag = "-NoLogo -NoProfile -ExecutionPolicy RemoteSigned -Command"
--   vim.o.shellxquote = ""
--   vim.o.shellquote = ""
--   vim.o.shellpipe = "| Out-File -Encoding UTF8 %s"
--   vim.o.shellredir = "| Out-File -Encoding UTF8 %s"
-- end

-- vim.opt.clipboard = "unnamedplus"

-- local ok, osc52 = pcall(require, "vim.ui.clipboard.osc52")
-- if ok then
--   vim.g.clipboard = {
--     name = "OSC 52",
--     copy = {
--       ["+"] = osc52.copy("+"),
--       ["*"] = osc52.copy("*"),
--     },
--     paste = {
--       ["+"] = osc52.paste("+"),
--       ["*"] = osc52.paste("*"),
--     },
--   }
-- end

local function setup_clipboard()
  local is_wsl = os.getenv("WSL_DISTRO_NAME") or os.getenv("WSL_INTEROP")
  local is_ssh = os.getenv("SSH_CLIENT") or os.getenv("SSH_TTY") or os.getenv("SSH_CONNECTION")

  if vim.g.neovide then
    vim.opt.clipboard = "unnamedplus"
    vim.g.clipboard = {
      name = "pbcopy",
      copy = { ["+"] = { "/usr/bin/pbcopy" }, ["*"] = { "/usr/bin/pbcopy" } },
      paste = { ["+"] = { "/usr/bin/pbpaste" }, ["*"] = { "/usr/bin/pbpaste" } },
    }
  elseif is_wsl then
    vim.g.clipboard = {
      name = "win32yank-wsl",
      copy = { ["+"] = { "win32yank.exe", "-i", "--crlf" }, ["*"] = { "win32yank.exe", "-i", "--crlf" } },
      paste = { ["+"] = { "win32yank.exe", "-o", "--lf" }, ["*"] = { "win32yank.exe", "-o", "--lf" } },
    }
  elseif vim.fn.has("win32") == 1 then
    vim.opt.clipboard = "unnamedplus"
  elseif vim.fn.has("mac") == 1 then
    vim.g.clipboard = {
      name = "pbcopy",
      copy = { ["+"] = { "/usr/bin/pbcopy" }, ["*"] = { "/usr/bin/pbcopy" } },
      paste = { ["+"] = { "/usr/bin/pbpaste" }, ["*"] = { "/usr/bin/pbpaste" } },
    }
  elseif is_ssh then
    local osc52 = require("vim.ui.clipboard.osc52")
    vim.g.clipboard = {
      name = "OSC 52",
      copy = { ["+"] = osc52.copy("+"), ["*"] = osc52.copy("*") },
      paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") },
    }
  end
end

-- VimEnter 이후 실행으로 vim.g.neovide 확실히 감지
vim.api.nvim_create_autocmd("VimEnter", {
  once = true,
  callback = setup_clipboard,
})

