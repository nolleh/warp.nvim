-- Command registration for warp.nvim
local M = {}

local finder = require("warp.finder")
local ui = require("warp.ui")

function M.setup()
  vim.api.nvim_create_user_command("Warp", function(opts)
    local bufnr = vim.api.nvim_get_current_buf()
    local win_id = vim.api.nvim_get_current_win()

    local refs = finder.find_refs(bufnr, win_id)
    ui.show_hints(refs, bufnr)
  end, {})
end

return M
