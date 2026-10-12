-- Path detection logic for warp.nvim
local M = {}

---@param target string
---@return string path, number line, number|nil column
local function parse_file_target(target)
  local path, line, column = target:match("^(.-):(%d+):(%d+)$")
  if path then
    return path, tonumber(line), tonumber(column)
  end

  path, line = target:match("^(.-):(%d+)$")
  if path then
    return path, tonumber(line), nil
  end

  return target, 1, nil
end

---@alias RefType "file" | "url" | "anchor"

---@class WarpRef
---@field path string
---@field line number
---@field column number|nil Column number (1-indexed, nil if not specified)
---@field display string
---@field buf_line number
---@field col number
---@field type RefType

---Read visible line ranges without fetching closed fold interiors.
---@param bufnr number
---@param win_id number
---@param first number
---@param last number
---@return string[] lines, number[] line_numbers, table<number, boolean> folded_lines
local function get_visible_lines(bufnr, win_id, first, last)
  local lines, line_numbers, folded_lines = {}, {}, {}

  local function read_range(start_line, end_line)
    for i, line in ipairs(vim.fn.getbufline(bufnr, start_line, end_line)) do
      lines[#lines + 1] = line
      line_numbers[#line_numbers + 1] = start_line + i - 1
    end
  end

  -- Fold state belongs to the window, even when another window shows the same buffer.
  vim.api.nvim_win_call(win_id, function()
    local range_start = first
    local lnum = first
    while lnum <= last do
      local fold_end = vim.fn.foldclosedend(lnum)
      if fold_end ~= -1 then
        read_range(range_start, lnum)
        folded_lines[lnum] = true
        lnum = fold_end + 1
        range_start = lnum
      else
        lnum = lnum + 1
      end
    end
    if range_start <= last then
      read_range(range_start, last)
    end
  end)

  return lines, line_numbers, folded_lines
end

---Find file paths in visible buffer area
---@param bufnr number
---@param win_id number
---@return WarpRef[]
function M.find_refs(bufnr, win_id)
  local first = vim.fn.line("w0", win_id)
  local last = vim.fn.line("w$", win_id)
  local lines, line_numbers, folded_lines = get_visible_lines(bufnr, win_id, first, last)

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
  local fold_boundaries = {}
  local path_char = "[~%.%w/_%-]"
  local win_width = vim.api.nvim_win_get_width(win_id)

  for i, line in ipairs(lines) do
    local prev_len = i > 1 and #lines[i - 1] or 0
    local is_fold_boundary = i > 1
      and (
        line_numbers[i] ~= line_numbers[i - 1] + 1
        or folded_lines[line_numbers[i - 1]]
        or folded_lines[line_numbers[i]]
      )
    local is_forced_wrap = not is_fold_boundary and prev_len >= win_width - 1

    if is_forced_wrap and lines[i - 1]:match(path_char .. "$") and line:match("^" .. path_char) then
      line_offsets[i] = #combined
      combined = combined .. line
    else
      combined = combined .. " "
      line_offsets[i] = #combined
      if is_fold_boundary then
        fold_boundaries[#fold_boundaries + 1] = #combined
      end
      combined = combined .. line
    end
  end

  -- Helper: convert combined position to (buf_line, col)
  local function pos_to_line_col(pos)
    for i = #line_offsets, 1, -1 do
      if line_offsets[i] < pos then
        return line_numbers[i], pos - line_offsets[i] - 1
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
    -- A multiline match must not bridge text hidden by a closed fold.
    for _, boundary in ipairs(fold_boundaries) do
      if s <= boundary and e > boundary then
        return
      end
    end

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
        local path, line, column = parse_file_target(target)
        if path:find("%s") and select(2, M.resolve_path(path, bufnr)) == "notfound" then
          local without_padding = path:gsub("%s+", "")
          if select(2, M.resolve_path(without_padding, bufnr)) ~= "notfound" then
            path = without_padding
          end
        end
        try_add_ref(path, line, display, s, e, "file", column)
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

  -- Some terminal buffers insert newlines before reaching the Neovim window edge.
  -- Only join adjacent path fragments when the resulting path exists.
  for i, line in ipairs(lines) do
    local start_col, first_part = line:match("()([~%.%w/_%-]+)%s*$")
    if first_part and first_part:find("/", 1, true) then
      local joined = first_part
      local separate_paths_exist = select(2, M.resolve_path(first_part, bufnr)) ~= "notfound"
      for j = i + 1, math.min(i + 2, #lines) do
        if
          line_numbers[j] ~= line_numbers[j - 1] + 1
          or folded_lines[line_numbers[j - 1]]
          or folded_lines[line_numbers[j]]
        then
          break
        end

        local indent, part = lines[j]:match("^(%s*)([~%.%w/_%-]+)")
        if not part or #joined + #part > 1024 then
          break
        end

        joined = joined .. part
        separate_paths_exist = separate_paths_exist and select(2, M.resolve_path(part, bufnr)) ~= "notfound"
        local _, path_type = M.resolve_path(joined, bufnr)
        if path_type ~= "notfound" and not separate_paths_exist then
          local start_pos = line_offsets[i] + start_col
          local end_pos = line_offsets[j] + #indent + #part
          try_add_ref(joined, 1, joined, start_pos, end_pos, "file")
          break
        end
      end
    end
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
---Prefer file-buffer-relative resolution, with cwd as a fallback
---@alias PathType "file" | "directory" | "notfound"

---Classify a path as file, directory, or notfound
---@param p string
---@return PathType
local function classify_path(p)
  if vim.fn.filereadable(p) == 1 then
    return "file"
  elseif vim.fn.isdirectory(p) == 1 then
    return "directory"
  end
  return "notfound"
end

---Scan a single selected line for refs without visibility filtering.
---@param line string
---@param buf_line number
---@param base_col number
---@param refs WarpRef[]
---@param seen table<string, boolean>
local function scan_line_for_refs(line, buf_line, base_col, refs, seen)
  local matched_ranges = {}

  local function is_range_matched(s, e)
    for _, range in ipairs(matched_ranges) do
      if not (e < range.s or s > range.e) then
        return true
      end
    end
    return false
  end

  local function try_add_ref(path, display, s, e, ref_type, line_num, column)
    if is_range_matched(s, e) then
      return
    end

    local col = base_col + s - 1
    local key = buf_line .. ":" .. col .. ":" .. display
    if not seen[key] then
      seen[key] = true
      table.insert(matched_ranges, { s = s, e = e })
      table.insert(refs, {
        path = path,
        line = line_num or 1,
        column = column,
        display = display,
        buf_line = buf_line,
        col = col,
        type = ref_type,
      })
    end
  end

  local ft = vim.bo[0].filetype
  local search_start = 1

  if ft == "markdown" then
    local md_link_pattern = "%[([^%]]+)%]%(([^%)]+)%)"
    while true do
      local s, e, text, target = line:find(md_link_pattern, search_start)
      if not s then
        break
      end
      local display = "[" .. text .. "](" .. target .. ")"
      if target:match("^#") then
        try_add_ref(target, display, s, e, "anchor", 0)
      elseif target:match("^https?://") then
        try_add_ref(target, display, s, e, "url", 1)
      else
        local path, line_num, column = parse_file_target(target)
        try_add_ref(path, display, s, e, "file", line_num, column)
      end
      search_start = e + 1
    end
  end

  local url_pattern = "(https?://[%w%-_.~:/?#%[%]@!$&'()*+,;=%%]+)"
  search_start = 1
  while true do
    local s, e, url = line:find(url_pattern, search_start)
    if not s then
      break
    end
    local clean_url = url:gsub("[,.)>]+$", "")
    local clean_e = s + #clean_url - 1
    try_add_ref(clean_url, clean_url, s, clean_e, "url", 1)
    search_start = e + 1
  end

  local pattern_with_line_col = "([~%.%w/_%-][~%w%./_%-]*):(%d+):(%d+)"
  search_start = 1
  while true do
    local s, e, path, lnum, cnum = line:find(pattern_with_line_col, search_start)
    if not s then
      break
    end
    if not path:match("^%d+$") and #path >= 2 then
      try_add_ref(path, path .. ":" .. lnum .. ":" .. cnum, s, e, "file", tonumber(lnum), tonumber(cnum))
    end
    search_start = e + 1
  end

  local pattern_with_line = "([~%.%w/_%-][~%w%./_%-]*):(%d+)"
  search_start = 1
  while true do
    local s, e, path, lnum = line:find(pattern_with_line, search_start)
    if not s then
      break
    end
    if not path:match("^%d+$") and #path >= 2 then
      try_add_ref(path, path .. ":" .. lnum, s, e, "file", tonumber(lnum))
    end
    search_start = e + 1
  end

  local pattern_file_only = "([~%.%w/_%-][~%w%./_%-]*)"
  search_start = 1
  while true do
    local s, e, path = line:find(pattern_file_only, search_start)
    if not s then
      break
    end
    local next_chars = line:sub(e + 1, e + 2)
    local looks_like_path = path:match("/") or path:match("%.")
    if not next_chars:match("^:%d") and #path >= 2 and looks_like_path then
      try_add_ref(path, path, s, e, "file", 1)
    end
    search_start = e + 1
  end
end

---Find refs from selected text segments.
---@param segments table[] List of {text, buf_line, base_col}
---@return WarpRef[]
function M.find_refs_in_segments(segments)
  local refs = {}
  local seen = {}

  for _, segment in ipairs(segments) do
    if segment.text and segment.text ~= "" then
      scan_line_for_refs(segment.text, segment.buf_line, segment.base_col or 1, refs, seen)
    end
  end

  return refs
end

---@param path string
---@param bufnr number|nil optional file buffer to resolve relative paths from first
---@return string resolved_path, PathType path_type
function M.resolve_path(path, bufnr)
  if path:match("^~") then
    local expanded = path:gsub("^~", vim.fn.expand("~"))
    return expanded, classify_path(expanded)
  elseif not path:match("^/") then
    -- Named special buffers (for example term://...) are not document paths.
    if bufnr and vim.bo[bufnr].buftype == "" then
      local buf_name = vim.api.nvim_buf_get_name(bufnr)
      if buf_name ~= "" then
        local buf_dir = vim.fn.fnamemodify(buf_name, ":p:h")
        local buf_relative_path = buf_dir .. "/" .. path
        local buf_type = classify_path(buf_relative_path)
        if buf_type ~= "notfound" then
          return buf_relative_path, buf_type
        end
      end
    end

    local cwd_path = vim.fn.getcwd() .. "/" .. path
    return cwd_path, classify_path(cwd_path)
  end
  return path, classify_path(path)
end

return M
