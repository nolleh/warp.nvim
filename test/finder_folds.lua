-- Run with: nvim --headless -u NONE -i NONE -n -c 'luafile test/finder_folds.lua'
vim.opt.runtimepath:prepend(vim.fn.getcwd())
vim.o.lines = 40
vim.o.columns = 120

local finder = require("warp.finder")
local failures = 0
local passed = 0

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

local function reset(lines)
  vim.cmd("silent! only!")
  vim.cmd("enew!")
  vim.wo.wrap = false
  vim.wo.foldmethod = "manual"
  vim.wo.foldenable = true
  vim.wo.foldlevel = 0
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.cmd("normal! ggzt")
  vim.cmd("redraw")
end

local function assert_refs(expected, win_id)
  vim.cmd("redraw")
  win_id = win_id or vim.api.nvim_get_current_win()
  local refs = finder.find_refs(vim.api.nvim_win_get_buf(win_id), win_id)
  local actual = {}
  for _, ref in ipairs(refs) do
    actual[#actual + 1] = string.format("%s@%d:%d", ref.path, ref.buf_line, ref.col)
  end
  table.sort(actual)
  table.sort(expected)
  assert(vim.deep_equal(actual, expected), "Expected " .. vim.inspect(expected) .. ", got " .. vim.inspect(actual))
end

test("closed folds keep their first line and preserve later reference positions", function()
  reset({ "before.lua", "  header.lua", "hidden.lua", "https://hidden.example", "  after.lua:42:3" })
  vim.cmd("2,4fold")
  assert_refs({ "before.lua@1:0", "header.lua@2:2", "after.lua@5:2" })

  vim.cmd("normal! zR")
  assert_refs({ "before.lua@1:0", "header.lua@2:2", "hidden.lua@3:0", "https://hidden.example@4:0", "after.lua@5:2" })
end)

test("nested folds follow the visible outer and inner headers", function()
  reset({ "before.lua", "outer.lua", "inner.lua", "hidden.lua", "outer_tail.lua", "after.lua" })
  vim.cmd("3,4fold")
  vim.cmd("2,5fold")
  assert_refs({ "before.lua@1:0", "outer.lua@2:0", "after.lua@6:0" })

  vim.api.nvim_win_set_cursor(0, { 2, 0 })
  vim.cmd("normal! zo")
  assert_refs({ "before.lua@1:0", "outer.lua@2:0", "inner.lua@3:0", "outer_tail.lua@5:0", "after.lua@6:0" })
end)

test("adjacent folds and folds at buffer boundaries retain their headers", function()
  reset({ "first.lua", "hidden_first.lua", "second.lua", "hidden_second.lua" })
  vim.cmd("1,2fold")
  vim.cmd("3,4fold")
  assert_refs({ "first.lua@1:0", "second.lua@3:0" })

  vim.wo.foldenable = false
  assert_refs({ "first.lua@1:0", "hidden_first.lua@2:0", "second.lua@3:0", "hidden_second.lua@4:0" })
end)

test("folds are checked in the requested window without changing the active window", function()
  reset({ "header.lua", "hidden.lua", "after.lua" })
  vim.cmd("1,2fold")
  local folded_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  local open_win = vim.api.nvim_get_current_win()
  vim.cmd("normal! zR")
  assert_refs({ "header.lua@1:0", "after.lua@3:0" }, folded_win)
  assert(vim.api.nvim_get_current_win() == open_win, "Changed the active window")
  assert_refs({ "header.lua@1:0", "hidden.lua@2:0", "after.lua@3:0" }, open_win)
end)

test("large folded interiors are never read from the buffer", function()
  local lines = {}
  for i = 1, 10000 do
    lines[i] = "some log output"
  end
  lines[1], lines[2], lines[10000] = "before.lua", "header.lua", "after.lua"
  reset(lines)
  vim.cmd("2,9999fold")

  local original = vim.fn.getbufline
  local read_count = 0
  vim.fn.getbufline = function(bufnr, first, last)
    local result = original(bufnr, first, last)
    read_count = read_count + #result
    return result
  end
  local ok, err = pcall(assert_refs, { "before.lua@1:0", "header.lua@2:0", "after.lua@10000:0" })
  vim.fn.getbufline = original
  assert(ok, err)
  assert(read_count == 3, "Read " .. read_count .. " lines instead of the three visible lines")
end)

test("ordinary terminal-width path continuations still join", function()
  reset({ "" })
  local width = vim.api.nvim_win_get_width(0)
  local prefix = "/" .. string.rep("a", width - 2) .. "/"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { prefix, "file.lua" })
  assert_refs({ prefix .. "file.lua@1:0" })
end)

test("existing paths split before the window edge join across up to three lines", function()
  local path = vim.fn.getcwd() .. "/README.md"
  local prefix = path:sub(1, -6)
  reset({ "  (" .. prefix, "  " .. path:sub(-5) .. ")" })
  assert_refs({ path .. "@1:3" })

  reset({ "  (" .. prefix, "  " .. path:sub(-5, -5), "  " .. path:sub(-4) .. ")" })
  assert_refs({ path .. "@1:3" })
end)

test("separate path lines stay separate", function()
  reset({ "README.md", "test.sh" })
  assert_refs({ "README.md@1:0", "test.sh@2:0" })
end)

test("valid separate paths take priority even when their concatenation exists", function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  for _, name in ipairs({ "a", "b.md", "ab.md" }) do
    vim.fn.writefile({}, dir .. "/" .. name)
  end
  reset({ dir .. "/a", "b.md" })
  vim.api.nvim_buf_set_name(0, dir .. "/source.md")
  assert_refs({ dir .. "/a@1:0", "b.md@2:0" })
  vim.fn.delete(dir, "rf")
end)

test("short wrapped paths do not cross closed folds", function()
  local path = vim.fn.getcwd() .. "/README.md"
  reset({ path:sub(1, -6), "fold header", "hidden text", path:sub(-5) })
  vim.cmd("2,3fold")
  assert_refs({ path:sub(1, -6) .. "@1:0", path:sub(-5) .. "@4:0" })
end)

test("terminal-width paths do not join into or across a closed fold", function()
  reset({ "" })
  local width = vim.api.nvim_win_get_width(0)
  local before = "/" .. string.rep("a", width - 2) .. "/"
  local header = "/" .. string.rep("b", width - 2) .. "/"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, { before, header, "hidden.lua", "after.lua" })
  vim.cmd("2,3fold")
  assert_refs({ before .. "@1:0", header .. "@2:0", "after.lua@4:0" })
end)

test("Markdown targets after folds keep their target and buffer coordinates", function()
  reset({ "[Header](header.lua)", "[Hidden](hidden.lua)", "  [After](after.lua:42:3)", "[Heading](#heading)" })
  vim.bo.filetype = "markdown"
  vim.cmd("1,2fold")
  assert_refs({ "header.lua@1:0", "after.lua@3:2", "#heading@4:0" })
  local refs = finder.find_refs(vim.api.nvim_get_current_buf(), vim.api.nvim_get_current_win())
  assert(refs[2].line == 42 and refs[2].column == 3, "Lost the target line or column")
end)

test("Markdown paths wrapped with padded lines resolve without padding", function()
  local path = vim.fn.getcwd() .. "/README.md"
  local prefix = path:sub(1, -6)
  reset({ "  [Read](" .. prefix .. "     ", "  " .. path:sub(-5) .. ")  " })
  vim.bo.filetype = "markdown"
  assert_refs({ path .. "@1:2" })
end)

test("Markdown paths preserve spaces that belong to an existing filename", function()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/two words.md"
  vim.fn.writefile({}, path)
  reset({ "[Read](" .. path .. ")" })
  vim.bo.filetype = "markdown"
  assert_refs({ path .. "@1:0" })
  vim.fn.delete(dir, "rf")
end)

test("Markdown links cannot be assembled across a closed fold", function()
  reset({ "[broken", "fold header", "hidden text", "](after.lua)" })
  vim.bo.filetype = "markdown"
  vim.cmd("2,3fold")
  assert_refs({ "after.lua@4:2" })
end)

print(string.format("%d passed, %d failed", passed, failures))
if failures > 0 then
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
