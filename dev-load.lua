-- Development loader for warp.nvim
-- This appends warp to your existing config without replacing it
-- Usage: nvim -c "luafile dev-load.lua"

local plugin_path = vim.fn.expand("<sfile>:p:h")

-- Add warp to runtimepath
vim.opt.runtimepath:append(plugin_path)

-- Setup warp
require("warp").setup({})

print("✓ warp dev mode loaded!")
print("  Try :warp to start")
