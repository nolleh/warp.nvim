#!/usr/bin/env bash
# Development test with your existing Neovim config

cd "$(dirname "$0")"

echo "Loading warp.nvim into your existing Neovim setup..."
echo ""

nvim -c "luafile dev-load.lua"
