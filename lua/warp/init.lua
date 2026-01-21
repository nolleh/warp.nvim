local M = {}

M.config = {
  -- Default keymap: <leader>w
  -- Set to false to disable default keymap
  -- Or set to a string like "<leader>wf" for a custom keymap
  default_keymap = "<leader>w",
}

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  require("warp.commands").setup()

  -- Register default keymap if enabled
  if M.config.default_keymap then
    vim.keymap.set("n", M.config.default_keymap, "<cmd>Warp<cr>", {
      desc = "Warp to file",
      silent = true,
    })
  end
end

return M
