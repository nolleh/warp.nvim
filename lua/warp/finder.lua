-- Path detection logic for warp.nvim
local M = {}

---@class WarpRef
---@field path string
---@field line number
---@field display string
---@field buf_line number
---@field col number

---Find file paths in visible buffer area
---@param bufnr number
---@param win_id number
---@return WarpRef[]
function M.find_refs(bufnr, win_id)
  local first = vim.fn.line("w0", win_id)
  local last = vim.fn.line("w$", win_id)
  local lines = vim.fn.getbufline(bufnr, first, last)

  local refs = {}
  local seen = {}

  -- Combine lines for detecting wrapped paths (lines broken by terminal width)
  local combined = ""
  local line_offsets = {} -- line_offsets[i] = start position of line i in combined
  local path_char = "[~%.%w/_%-]"
  local win_width = vim.api.nvim_win_get_width(win_id)

  for i, line in ipairs(lines) do
    line_offsets[i] = #combined
    local prev_len = i > 1 and #lines[i - 1] or 0
    local is_forced_wrap = prev_len >= win_width - 1

    if is_forced_wrap and lines[i - 1]:match(path_char .. "$") and line:match("^" .. path_char) then
      combined = combined .. line
    else
      combined = combined .. " " .. line
    end
  end

  -- Helper: convert combined position to (buf_line, col)
  local function pos_to_line_col(pos)
    for i = #line_offsets, 1, -1 do
      if line_offsets[i] < pos then
        return first + i - 1, pos - line_offsets[i] - 1
      end
    end
    return first, pos - 1
  end

  -- Helper: check if position is visible on screen and add to refs
  local function try_add_ref(path, lnum, display, s)
    local buf_line, col = pos_to_line_col(s)
    col = math.max(0, col)
    local pos = vim.fn.screenpos(win_id, buf_line, col + 1)
    -- Only add if visible on screen (screenpos returns row=0 if not visible)
    if pos.row > 0 then
      local key = buf_line .. ":" .. col .. ":" .. display
      if not seen[key] then
        seen[key] = true
        table.insert(refs, { path = path, line = lnum, display = display, buf_line = buf_line, col = col })
      end
    end
  end

  -- Pattern: file:line
  local pattern_with_line = "([~%.%w/_%-][~%w%./_%-]*):(%d+)"
  local search_start = 1
  while true do
    local s, e, path, lnum = combined:find(pattern_with_line, search_start)
    if not s then
      break
    end
    if not path:match("^%d+$") and #path >= 2 then
      try_add_ref(path, tonumber(lnum), path .. ":" .. lnum, s)
    end
    search_start = e + 1
  end

  -- Pattern: file only (without line number)
  local pattern_file_only = "([~%.%w/_%-][~%w%./_%-]*)"
  search_start = 1
  while true do
    local s, e, path = combined:find(pattern_file_only, search_start)
    if not s then
      break
    end
    local next_chars = combined:sub(e + 1, e + 2)
    local looks_like_path = path:match("/") or path:match("%.")
    if not next_chars:match("^:%d") and #path >= 2 and looks_like_path then
      try_add_ref(path, 1, path, s)
    end
    search_start = e + 1
  end

  return refs
end

---Resolve path to absolute path
---@param path string
---@return string
function M.resolve_path(path)
  if path:match("^~") then
    return path:gsub("^~", vim.fn.expand("~"))
  elseif not path:match("^/") then
    return vim.fn.getcwd() .. "/" .. path
  end
  return path
end

return M
