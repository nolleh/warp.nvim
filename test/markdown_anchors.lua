-- Run with: nvim --headless -u NONE -i NONE -n -c 'luafile test/markdown_anchors.lua'
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.lines = 40
vim.o.columns = 120

local finder = require("warp.finder")
local ui = require("warp.ui")
local root = vim.fn.resolve(vim.fn.tempname())
local original_cwd = vim.fn.getcwd()
local original_getcharstr = vim.fn.getcharstr
local passed, failures = 0, 0

vim.fn.mkdir(root .. "/docs/wiki", "p")
vim.fn.writefile(
  { "# Getting Started", "", "## Install an agent", "", "Instructions" },
  root .. "/docs/wiki/Getting-Started.md"
)
vim.api.nvim_set_current_dir(root)

local function test(name, callback)
  local ok, err = xpcall(callback, debug.traceback)
  vim.fn.getcharstr = original_getcharstr
  if ok then
    passed = passed + 1
    print("PASS: " .. name)
  else
    failures = failures + 1
    print("FAIL: " .. name .. "\n" .. err)
  end
end

local function source(text)
  vim.cmd("silent! only!")
  vim.cmd("enew!")
  vim.bo.filetype = "markdown"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { text })
  vim.cmd("redraw")
  return vim.api.nvim_get_current_buf()
end

local link = "[`agent.cmd`](docs/wiki/Getting-Started.md#install-an-agent)"

test("visible and selected Markdown links separate file paths from heading fragments", function()
  local buf = source("Install and authenticate, then set " .. link .. " to its executable")
  for _, refs in ipairs({
    finder.find_refs(buf, vim.api.nvim_get_current_win()),
    finder.find_refs_in_segments({ { text = link, buf_line = 1, base_col = 1 } }),
  }) do
    assert(#refs == 1, "Expected a single link")
    assert(refs[1].path == "docs/wiki/Getting-Started.md", "Fragment remained in file path")
    assert(refs[1].anchor == "#install-an-agent", "Lost the heading fragment")
    assert(refs[1].type == "file", "Cross-document link must open a file")
  end
end)

for _, prefix in ipairs({ "", "S", "V" }) do
  test("hint opens the target heading in mode " .. (prefix == "" and "edit" or prefix), function()
    local buf = source(link)
    local refs = finder.find_refs(buf, vim.api.nvim_get_current_win())
    local keys = prefix == "" and { "a" } or { prefix, "a" }
    local index = 0
    vim.fn.getcharstr = function()
      index = index + 1
      return keys[index] or "\27"
    end
    ui.show_hints(refs, buf)
    assert(vim.api.nvim_buf_get_name(0) == root .. "/docs/wiki/Getting-Started.md", "Opened the wrong file")
    assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "Did not jump to the target heading")
  end)
end

test("visual selection opens the target heading", function()
  source(link)
  vim.api.nvim_buf_set_mark(0, "<", 1, 0, {})
  vim.api.nvim_buf_set_mark(0, ">", 1, #link - 1, {})
  ui.browse_selection("V")
  assert(vim.api.nvim_buf_get_name(0) == root .. "/docs/wiki/Getting-Started.md", "Opened the wrong file")
  assert(vim.api.nvim_win_get_cursor(0)[1] == 3, "Did not jump to the target heading")
end)

test("same-document anchors and URL fragments retain their original types", function()
  local buf = source("[Here](#install-an-agent) [Web](https://example.com/page#heading) [File](file.lua:42:3)")
  for _, refs in ipairs({
    finder.find_refs(buf, vim.api.nvim_get_current_win()),
    finder.find_refs_in_segments({ { text = vim.api.nvim_get_current_line(), buf_line = 1 } }),
  }) do
    assert(#refs == 3, "Expected three links")
    assert(refs[1].type == "anchor" and refs[1].path == "#install-an-agent")
    assert(refs[2].type == "url" and refs[2].path == "https://example.com/page#heading")
    assert(refs[3].path == "file.lua" and refs[3].line == 42 and refs[3].column == 3)
  end
end)

vim.api.nvim_set_current_dir(original_cwd)
vim.fn.delete(root, "rf")
print(string.format("%d passed, %d failed", passed, failures))
if failures > 0 then
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
