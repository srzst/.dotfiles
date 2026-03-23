-- -- Netrw 비활성화 (기본 트리와 충돌 방지)
-- vim.g.loaded_netrw = 1
-- vim.g.loaded_netrwPlugin = 1


return{}
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