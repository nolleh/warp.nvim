-- Path detection logic for warp.nvim
local M = {}

---@alias RefType "file" | "url" | "anchor"

---@class WarpRef
---@field path string
---@field line number
---@field column number|nil Column number (1-indexed, nil if not specified)
---@field display string
---@field buf_line number
---@field col number
---@field type RefType

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
  local matched_ranges = {} -- Track matched ranges to avoid overlapping matches

  -- Helper: check if a range overlaps with any existing matched range
  local function is_range_matched(s, e)
    for _, range in ipairs(matched_ranges) do
      -- Check for overlap: not (e < range.s or s > range.e)
      if not (e < range.s or s > range.e) then
        return true
      end
    end
    return false
  end

  -- Combine lines for detecting wrapped paths (lines broken by terminal width)
  local combined = ""
  local line_offsets = {} -- line_offsets[i] = start position of line i in combined
  local path_char = "[~%.%w/_%-]"
  local win_width = vim.api.nvim_win_get_width(win_id)

  for i, line in ipairs(lines) do
    local prev_len = i > 1 and #lines[i - 1] or 0
    local is_forced_wrap = prev_len >= win_width - 1

    if is_forced_wrap and lines[i - 1]:match(path_char .. "$") and line:match("^" .. path_char) then
      line_offsets[i] = #combined
      combined = combined .. line
    else
      combined = combined .. " "
      line_offsets[i] = #combined
      combined = combined .. line
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
  ---@param path string
  ---@param lnum number
  ---@param display string
  ---@param s number start position in combined string
  ---@param e number end position in combined string
  ---@param ref_type RefType
  ---@param column number|nil optional column number
  local function try_add_ref(path, lnum, display, s, e, ref_type, column)
    -- Skip if this range overlaps with an already matched range
    if is_range_matched(s, e) then
      return
    end

    local buf_line, col = pos_to_line_col(s)
    col = math.max(0, col)
    local pos = vim.fn.screenpos(win_id, buf_line, col + 1)
    -- Only add if visible on screen (screenpos returns row=0 if not visible)
    if pos.row > 0 then
      local key = buf_line .. ":" .. col .. ":" .. display
      if not seen[key] then
        seen[key] = true
        table.insert(matched_ranges, { s = s, e = e })
        table.insert(refs, {
          path = path,
          line = lnum,
          column = column,
          display = display,
          buf_line = buf_line,
          col = col,
          type = ref_type,
        })
      end
    end
  end

  -- Pattern: Markdown link [text](target) - only for markdown files
  -- Run this BEFORE URL pattern so markdown links get proper hint position at [
  local ft = vim.bo[bufnr].filetype
  local search_start = 1
  if ft == "markdown" then
    local md_link_pattern = "%[([^%]]+)%]%(([^%)]+)%)"
    while true do
      local s, e, text, target = combined:find(md_link_pattern, search_start)
      if not s then
        break
      end
      local display = "[" .. text .. "](" .. target .. ")"
      if target:match("^#") then
        -- Anchor link (same document)
        try_add_ref(target, 0, display, s, e, "anchor")
      elseif target:match("^https?://") then
        -- URL link in markdown format
        try_add_ref(target, 0, display, s, e, "url")
      else
        -- File link
        try_add_ref(target, 1, display, s, e, "file")
      end
      search_start = e + 1
    end
  end

  -- Pattern: URL (http:// or https://) - raw URLs not in markdown link format
  local url_pattern = "(https?://[%w%-_.~:/?#%[%]@!$&'()*+,;=%%]+)"
  search_start = 1
  while true do
    local s, e, url = combined:find(url_pattern, search_start)
    if not s then
      break
    end
    -- Remove trailing punctuation that's likely not part of the URL
    local clean_url = url:gsub("[,.)>]+$", "")
    local clean_e = s + #clean_url - 1
    try_add_ref(clean_url, 0, clean_url, s, clean_e, "url")
    search_start = e + 1
  end

  -- Pattern: file:line:col (must be before file:line to match first)
  local pattern_with_line_col = "([~%.%w/_%-][~%w%./_%-]*):(%d+):(%d+)"
  search_start = 1
  while true do
    local s, e, path, lnum, cnum = combined:find(pattern_with_line_col, search_start)
    if not s then
      break
    end
    if not path:match("^%d+$") and #path >= 2 then
      try_add_ref(path, tonumber(lnum), path .. ":" .. lnum .. ":" .. cnum, s, e, "file", tonumber(cnum))
    end
    search_start = e + 1
  end

  -- Pattern: file:line
  local pattern_with_line = "([~%.%w/_%-][~%w%./_%-]*):(%d+)"
  search_start = 1
  while true do
    local s, e, path, lnum = combined:find(pattern_with_line, search_start)
    if not s then
      break
    end
    if not path:match("^%d+$") and #path >= 2 then
      try_add_ref(path, tonumber(lnum), path .. ":" .. lnum, s, e, "file")
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
      try_add_ref(path, 1, path, s, e, "file")
    end
    search_start = e + 1
  end

  return refs
end

---Resolve path to absolute path
---Falls back to buffer-relative resolution if cwd-relative path doesn't exist
---@param path string
---@param bufnr number|nil optional buffer number for buffer-relative fallback
---@return string
function M.resolve_path(path, bufnr)
  if path:match("^~") then
    return path:gsub("^~", vim.fn.expand("~"))
  elseif not path:match("^/") then
    local cwd_path = vim.fn.getcwd() .. "/" .. path
    if vim.fn.filereadable(cwd_path) == 1 then
      return cwd_path
    end

    if bufnr then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      if buf_name ~= "" then
        local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
        local buf_relative_path = buf_dir .. "/" .. path
        if vim.fn.filereadable(buf_relative_path) == 1 then
          return buf_relative_path
        end
      end
    end

    return cwd_path
  end
  return path
end

return M
