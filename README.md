# warp.nvim

![](./docs/images/warp.png)

A motion plugin for file jumping. Hop to file paths, not words.

![Neovim](https://img.shields.io/badge/Neovim-0.10+-green.svg?style=flat&logo=neovim)
![License](https://img.shields.io/badge/License-MIT-blue.svg)

## Demo

https://github.com/user-attachments/assets/87b91299-bcf1-49af-95a4-be09752766ba

https://github.com/user-attachments/assets/1d9a2055-e67f-4663-9e1d-d21d09817dca

## Why warp.nvim?

You're in a terminal buffer. A test fails. The error shows `src/utils/parser.lua:42:15`.

With other plugins? Copy the path, switch windows, open file, go to line, find column.

With **warp.nvim**? Press one key, type the hint, you're there.

```
  Error: assertion failed
  --> src/utils/parser.lua:42:15    [a] <- hint appears here
      expected: true
      got: false
```

### Works on any path — not just your project

warp.nvim works on **every** file-like or link-like path visible in the buffer. That includes:

- Paths **outside** the current workspace (e.g. `~/jira-task/`, `/tmp/`, another repo)
- Paths and URLs printed by **CLI tools** (e.g. test output, build logs, or AI coding assistants)

So you can jump to external files and links without leaving the editor or copying paths.

**Examples:**

- **Jira / task notes outside the repo**  
  You use a skill like `/jira-task` so Claude Code (or similar) writes notes under `~/jira-task/`. When the assistant prints paths like `~/jira-task/PROJ-123.md`, you stay in your repo workspace but can jump to that file with warp — no need to `cd` or open another window.

- **PR / branch URLs after creating a PR**  
  After asking the assistant to open a PR, it may print the PR URL (e.g. `https://github.com/owner/repo/pull/42`). With warp you can jump to that URL (opens in browser) or to any file path it shows — all from the same buffer.

## Features

- **Works everywhere** - Regular buffers, terminal buffers, floating windows
- **No terminal integration needed** - Unlike kitty hints, works with any terminal emulator
- **Line & column aware** - Detects `file.lua:42` and `file.lua:42:15` patterns, jumps to exact position
- **URL support** - Opens URLs in your default browser (hints shown in green)
- **Markdown link support** - Follows `[text](target)` links including anchor links in `.md` files (hints shown in orange)
- **Wrapped path support** - Handles file paths broken across lines by terminal width
- **Smart window targeting** - Opens files in your editor window, not the terminal
- **Split/Vsplit support** - Prefix with `S` or `V` to open in split windows

### Hint Colors

| Type                   | Color  | Example               |
| ---------------------- | ------ | --------------------- |
| File path              | Blue   | `src/utils.lua:42:15` |
| URL                    | Green  | `https://example.com` |
| Markdown link (anchor) | Orange | `[Demo](#demo)`       |

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

## License

MIT
