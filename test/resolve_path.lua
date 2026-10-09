-- Run with: nvim --headless -u NONE -i NONE -n -c 'luafile test/resolve_path.lua'
vim.opt.runtimepath:prepend(vim.fn.getcwd())

local finder = require("warp.finder")
local root = vim.fn.tempname()
local cwd = root .. "/workspace"
local docs = root .. "/documents"
local original_cwd = vim.fn.getcwd()
local buffers = {}
local passed, failures = 0, 0

vim.fn.mkdir(cwd, "p")
vim.fn.mkdir(docs, "p")
vim.fn.writefile({}, cwd .. "/shared.lua")
vim.fn.writefile({}, docs .. "/shared.lua")
vim.fn.writefile({}, cwd .. "/fallback.lua")
vim.fn.writefile({}, docs .. "/local.lua")
vim.fn.mkdir(cwd .. "/folder", "p")
vim.fn.mkdir(docs .. "/folder", "p")
vim.api.nvim_set_current_dir(cwd)

local function buffer(name, buftype, filetype)
  local buf = vim.api.nvim_create_buf(false, true)
  buffers[#buffers + 1] = buf
  vim.bo[buf].buftype = buftype or ""
  vim.bo[buf].filetype = filetype or ""
  if name then
    vim.api.nvim_buf_set_name(buf, name)
  end
  return buf
end

local function expect(path, buf, expected_path, expected_type)
  local resolved, path_type = finder.resolve_path(path, buf)
  assert(resolved == expected_path, "Expected " .. expected_path .. ", got " .. resolved)
  assert(path_type == expected_type, "Expected " .. expected_type .. ", got " .. path_type)
end

local function test(name, callback)
  local ok, err = xpcall(callback, debug.traceback)
  if ok then
    passed = passed + 1
    print("PASS: " .. name)
  else
    failures = failures + 1
    print("FAIL: " .. name .. "\n" .. err)
  end
end

test("all file types prefer the document directory when both targets exist", function()
  for _, ft in ipairs({ "markdown", "text", "lua" }) do
    local buf = buffer(docs .. "/document." .. ft, "", ft)
    expect("shared.lua", buf, docs .. "/shared.lua", "file")
  end
end)

test("document-only targets resolve without a cwd copy", function()
  expect("local.lua", buffer(docs .. "/local.txt"), docs .. "/local.lua", "file")
end)

test("missing document targets fall back to cwd", function()
  expect("fallback.lua", buffer(docs .. "/fallback.txt"), cwd .. "/fallback.lua", "file")
end)

test("directories also prefer the document directory", function()
  expect("folder", buffer(docs .. "/folder.txt"), docs .. "/folder", "directory")
end)

test("unnamed buffers use cwd", function()
  expect("shared.lua", buffer(), cwd .. "/shared.lua", "file")
end)

test("named special buffers use cwd instead of their apparent directory", function()
  for _, bt in ipairs({ "nofile", "acwrite", "prompt" }) do
    expect("shared.lua", buffer(docs .. "/special-" .. bt, bt), cwd .. "/shared.lua", "file")
  end
  local terminal = buffer()
  vim.api.nvim_open_term(terminal, {})
  vim.api.nvim_buf_set_name(terminal, "term://" .. docs .. "//123:sh")
  expect("shared.lua", terminal, cwd .. "/shared.lua", "file")
end)

test("omitting the buffer uses cwd", function()
  expect("shared.lua", nil, cwd .. "/shared.lua", "file")
end)

test("buffer zero resolves from the current file", function()
  local original_buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_set_current_buf(buffer(docs .. "/current.txt"))
  local ok, err = pcall(expect, "shared.lua", 0, docs .. "/shared.lua", "file")
  vim.api.nvim_set_current_buf(original_buf)
  assert(ok, err)
end)

test("absolute paths bypass relative resolution", function()
  expect(cwd .. "/shared.lua", buffer(docs .. "/absolute.txt"), cwd .. "/shared.lua", "file")
  expect(root .. "/missing.lua", nil, root .. "/missing.lua", "notfound")
end)

test("home-relative paths keep home expansion", function()
  local home = vim.fn.expand("~")
  expect("~/", buffer(docs .. "/home.txt"), home .. "/", "directory")
end)

test("missing targets retain the cwd path for diagnostics", function()
  expect("missing.lua", buffer(docs .. "/missing.txt"), cwd .. "/missing.lua", "notfound")
end)

vim.api.nvim_set_current_dir(original_cwd)
for _, buf in ipairs(buffers) do
  vim.api.nvim_buf_delete(buf, { force = true })
end
vim.fn.delete(root, "rf")

print(string.format("%d passed, %d failed", passed, failures))
if failures > 0 then
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
