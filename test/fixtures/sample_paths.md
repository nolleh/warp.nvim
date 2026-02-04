# Sample Markdown file for testing warp.nvim

Run `:Warp` while viewing this file to test Markdown link detection

## Common config files

~/.zshrc
~/.bashrc
~/.config/nvim/init.lua
~/.gitconfig

## Project files (relative paths)

lua/warp/commands.lua
lua/warp/init.lua
lua/warp/finder.lua
lua/warp/ui.lua
README.md

## With line numbers

lua/warp/commands.lua:8
lua/warp/finder.lua:15
lua/warp/ui.lua:42

## With line and column numbers

lua/warp/finder.lua:42:10
lua/warp/ui.lua:139:3
lua/warp/commands.lua:8:1

## Typical error output patterns

Error in lua/warp/init.lua:3
--> lua/warp/commands.lua:12
Failed: test/fixtures/sample_paths.md:25

## Typical error output with column (Rust, TypeScript, Go style)

error[E0425]: cannot find value `x`
--> lua/warp/finder.lua:42:15
|
42 | let y = x + 1;
| ^ not found

src/main.ts:10:5 - error TS2304: Cannot find name 'foo'.
lua/warp/ui.lua:100:20: warning: unused variable

## System paths (if they exist on your system)

/etc/hosts
/etc/passwd

## Paths that look like paths but might not exist

./some/relative/path.lua
../parent/file.txt

## URLs (will open in browser)

https://github.com/nolleh/warp.nvim
https://neovim.io/doc/user/lua.html
http://localhost:3000
https://www.google.com/search?q=neovim

## Markdown links (file links - blue hints)

[README](README.md)
[Commands module](lua/warp/commands.lua)
[Relative path](./lua/warp/init.lua)

## Markdown links (anchor links - orange hints, jump within this file)

[Go to Common config files](#common-config-files)
[Go to URLs section](#urls-will-open-in-browser)
[Go to Edge cases](#edge-cases)

## Markdown links (URL links - green hints, opens in browser)

[GitHub Repo](https://github.com/nolleh/warp.nvim)
[Neovim Docs](https://neovim.io/doc/user/lua.html)

## Multi-line paths

[Word-wrapped path](/Users/nolleh/Documents/workspace_github/../../../../Users/nolleh/Documents/workspace_github/warp.nvim/lua/warp/init.lua)

## Edge cases

file.lua
config.json
.hidden_file
