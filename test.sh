#!/usr/bin/env bash

# Test with clean environment

cd "$(dirname "$0")"

echo "=========================================="
echo " Testing warp.nvim in clean environment"
echo "=========================================="
echo ""
echo "This simulates a fresh user installation"
echo "without your personal Neovim configuration."
echo ""

nvim -u test-init.lua
