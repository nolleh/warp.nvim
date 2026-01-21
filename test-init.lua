vim.opt.compatible = false

vim.opt.termguicolors = true
vim.opt.hidden = true
vim.opt.splitbelow = true
vim.opt.splitright = true

local test_root = vim.fn.stdpath("data") .. "/warp-test-env"
local lazy_path = test_root .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazy_path) then
  print("Installing lazy.nvim for test environment...")
  local result = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazy_path,
  })

  if vim.v.shell_error ~= 0 then
    print("Failed to install lazy.nvim:")
    print(result)
    print("\nPlease check your internet connection and try again.")
    return
  end

  print("lazy.nvim installed successfully!")
end

vim.opt.runtimepath:prepend(lazy_path)

local plugin_path = vim.fn.expand("<sfile>:p:h")

print("plugin_path" .. plugin_path)

-- Setup lazy.nvim with dependencies
require("lazy").setup({
  {
    dir = plugin_path,
    name = "warp.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
    },
    config = function()
      require("warp").setup({})
    end,
  },
}, {
  root = test_root .. "/lazy",
  lockfile = test_root .. "/lazy-lock.json",
})

print("")
print("========================================")
print("  warp.nvim Test Mode (Clean Environment)")
print("========================================")
print("")
print("  This is a minimal environment without your config")
print("  Try :Warp to start")
print("")
