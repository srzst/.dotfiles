-- -- Netrw 비활성화 (기본 트리와 충돌 방지)
-- vim.g.loaded_netrw = 1
-- vim.g.loaded_netrwPlugin = 1


-- return {
--   "nvim-neo-tree/neo-tree.nvim",
--   opts = {
--     window = {
--       mappings = {
--         ["<C-t>"] = function(state)
--           local node = state.tree:get_node()
--           local path = node:get_id()
--           if node.type ~= "directory" then
--             path = vim.fn.fnamemodify(path, ":h")
--           end
--           require("toggleterm").toggle({
--             dir = path,
--             direction = "float",
--           })
--         end,
--       },
--     },
--   },
-- }

return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        visible = true,
        hide_dotfiles = false,
        hide_gitignored = false,
      },
    },
  },
  init = function()
    if vim.g.neovide then
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        callback = function()
          vim.defer_fn(function()
            require("neo-tree.command").execute({ action = "show" })
          end, 100)
        end,
      })
    end
  end,
}