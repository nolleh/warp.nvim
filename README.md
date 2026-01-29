# warp.nvim

Jump to any file path or URL visible on your screen. Instantly.

![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat&logo=neovim)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

## Demo

![Demo](./docs/demo/warp-demo-small.gif)

## Why warp.nvim?

You're in a terminal buffer. A test fails. The error shows `src/utils/parser.lua:42`.

With other plugins? Copy the path, switch windows, open file, go to line.

With **warp.nvim**? Press one key, type the hint, you're there.

```
  Error: assertion failed
  --> src/utils/parser.lua:42       [a] <- hint appears here
      expected: true
      got: false
```

## Features

- **Works everywhere** - Regular buffers, terminal buffers, floating windows
- **No terminal integration needed** - Unlike kitty hints, works with any terminal emulator
- **Line number aware** - Detects `file.lua:42` patterns and jumps to the exact line
- **URL support** - Opens URLs in your default browser (hints shown in green)
- **Wrapped path support** - Handles file paths broken across lines by terminal width
- **Smart window targeting** - Opens files in your editor window, not the terminal
- **Split/Vsplit support** - Prefix with `S` or `V` to open in split windows

## Installation

### lazy.nvim

```lua
{
  "nolleh/warp.nvim",
  config = true,  -- Default keymap: <leader>w
  -- Or customize:
  -- config = function()
  --   require("warp").setup({
  --     default_keymap = "<leader>wf",  -- or false to disable
  --   })
  -- end,
  keys = { "<leader>w" }, -- your binding key (trigger lazy loading)
}
```

### packer.nvim

```lua
use {
  "nolleh/warp.nvim",
  config = function()
    require("warp").setup()
  end
}
```

## Usage

1. Press `<leader>w` (default) or run `:Warp`
2. Hint labels appear on detected file paths
3. Type the hint to jump

That's it. No configuration needed.

### Split / Vsplit

Open files in split windows by prefixing the hint with uppercase `S` or `V`:

| Input | Action                        |
| ----- | ----------------------------- |
| `a`   | Open in current window (edit) |
| `Sa`  | Open in horizontal split      |
| `Va`  | Open in vertical split        |

### Keymap Configuration

Default keymap is `<leader>w`. You can customize or disable it:

```lua
require("warp").setup({
  default_keymap = "<leader>wf",  -- Custom keymap
  -- default_keymap = false,      -- Disable default keymap
})
```

**Note on keymap conflicts**: `<leader>w` won't interfere with `<leader>wk` or other longer sequences. Neovim waits for the full sequence before executing, so existing keymaps remain safe.

## How It Differs from hop/flash.nvim

| Feature                 | hop/flash.nvim | warp.nvim |
| ----------------------- | -------------- | --------- |
| Jump within buffer      | Yes            | -         |
| Jump to files           | -              | Yes       |
| Terminal buffer support | Limited        | Full      |
| Line number detection   | -              | Yes       |

**warp.nvim** complements motion plugins - use hop/flash for navigation within a file, use warp for jumping _to_ files.

## License

MIT
