-- UI and hint interaction logic for warp.nvim
local M = {}

local finder = require("warp.finder")

---Generate hint key from index
---@param idx number
---@return string
local function get_hint_key(idx)
  if idx <= 26 then
    return string.char(96 + idx)
  else
    local f = math.floor((idx - 1) / 26)
    local s = ((idx - 1) % 26) + 1
    return string.char(96 + f) .. string.char(96 + s)
  end
end

---Check if input is a prefix of any other hint
---@param prefix string
---@param hint_map table<string, WarpRef>
---@return boolean
local function has_longer_match(prefix, hint_map)
  for key, _ in pairs(hint_map) do
    if key ~= prefix and key:sub(1, #prefix) == prefix then
      return true
    end
  end
  return false
end

---Find appropriate target window for opening file
---@return number|nil
local function find_target_window()
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local bt = vim.bo[buf].buftype
    local ft = vim.bo[buf].filetype
    local cfg = vim.api.nvim_win_get_config(win)
    if
      (not cfg.relative or cfg.relative == "")
      and bt ~= "terminal"
      and bt ~= "prompt"
      and ft ~= "neo-tree"
      and ft ~= "NvimTree"
      and ft ~= "oil"
    then
      return win
    end
  end
  return nil
end

---@alias OpenMode "edit" | "split" | "vsplit"

---Open URL in browser using vim.ui.open (Neovim 0.10+)
---@param url string
local function open_url(url)
  if vim.ui.open then
    vim.ui.open(url)
  else
    vim.notify("vim.ui.open not available (requires Neovim 0.10+)", vim.log.levels.ERROR)
  end
end

---Jump to anchor (heading) in current buffer
---@param anchor string The anchor like "#section-name"
---@param bufnr number
local function jump_to_anchor(anchor, bufnr)
  -- Remove leading # and convert to heading search pattern
  local heading_slug = anchor:gsub("^#", "")
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

  for i, line in ipairs(lines) do
    -- Match markdown headings (# Heading, ## Heading, etc.)
    local heading_text = line:match("^#+ (.+)$")
    if heading_text then
      -- Convert heading to slug (lowercase, spaces to hyphens, remove special chars)
      local slug = heading_text:lower():gsub("%s+", "-"):gsub("[^%w%-]", "")
      if slug == heading_slug then
        vim.api.nvim_win_set_cursor(0, { i, 0 })
        vim.cmd("normal! zz")
        return true
      end
    end
  end

  vim.notify("Anchor not found: " .. anchor, vim.log.levels.INFO)
  return false
end

---Render directory contents into a buffer
---@param buf number
---@param dir string
---@return table[] entries List of {name, path, is_dir}
local function render_directory(buf, dir)
  dir = dir:gsub("/+$", "")
  local raw = vim.fn.readdir(dir)
  local dirs = {}
  local files = {}
  for _, name in ipairs(raw) do
    if vim.fn.isdirectory(dir .. "/" .. name) == 1 then
      table.insert(dirs, name)
    else
      table.insert(files, name)
    end
  end
  table.sort(dirs)
  table.sort(files)

  local entries = {}
  local lines = {}

  table.insert(entries, { name = "../", path = vim.fn.fnamemodify(dir, ":h"), is_dir = true })
  table.insert(lines, "../")

  for _, name in ipairs(dirs) do
    table.insert(entries, { name = name .. "/", path = dir .. "/" .. name, is_dir = true })
    table.insert(lines, name .. "/")
  end
  for _, name in ipairs(files) do
    table.insert(entries, { name = name, path = dir .. "/" .. name, is_dir = false })
    table.insert(lines, name)
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false

  return entries
end

---Open a floating directory browser anchored one line below the extmark
---@param ref WarpRef
---@param dir_path string
---@param mode OpenMode
local function open_directory_browser(ref, dir_path, mode)
  local source_win = vim.api.nvim_get_current_win()

  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false
  vim.bo[buf].filetype = "warp-browser"

  local entries = render_directory(buf, dir_path)

  local dir_ns = vim.api.nvim_create_namespace("warp_browser")
  local function highlight_entries()
    vim.api.nvim_buf_clear_namespace(buf, dir_ns, 0, -1)
    for i, entry in ipairs(entries) do
      if entry.is_dir then
        vim.api.nvim_buf_add_highlight(buf, dir_ns, "Directory", i - 1, 0, -1)
      end
    end
  end
  highlight_entries()

  local function calc_dimensions(entry_list)
    local max_len = 20
    for _, entry in ipairs(entry_list) do
      max_len = math.max(max_len, #entry.name)
    end
    return math.min(max_len + 2, 60), math.min(#entry_list, 15)
  end

  local function make_title(dir, w)
    local t = " " .. vim.fn.fnamemodify(dir, ":~") .. " "
    if #t > w then
      t = " " .. vim.fn.fnamemodify(dir, ":t") .. "/ "
    end
    return t
  end

  local width, height = calc_dimensions(entries)
  local topline = vim.fn.line("w0")
  local row = ref.buf_line - topline + 1

  local float_win = vim.api.nvim_open_win(buf, true, {
    relative = "win",
    win = source_win,
    row = row,
    col = ref.col,
    width = width,
    height = height,
    style = "minimal",
    border = "rounded",
    title = make_title(dir_path, width),
    title_pos = "center",
  })
  vim.wo[float_win].cursorline = true

  local function close()
    if vim.api.nvim_win_is_valid(float_win) then
      vim.api.nvim_win_close(float_win, true)
    end
  end

  local function navigate(dir)
    entries = render_directory(buf, dir)
    highlight_entries()

    local new_w, new_h = calc_dimensions(entries)
    vim.api.nvim_win_set_config(float_win, {
      relative = "win",
      win = source_win,
      row = row,
      col = ref.col,
      width = new_w,
      height = new_h,
      style = "minimal",
      border = "rounded",
      title = make_title(dir, new_w),
      title_pos = "center",
    })
    vim.api.nvim_win_set_cursor(float_win, { 1, 0 })
  end

  local function open_selected()
    local cursor = vim.api.nvim_win_get_cursor(float_win)
    local entry = entries[cursor[1]]
    if not entry then
      return
    end

    if entry.is_dir then
      navigate(entry.path)
      return
    end

    close()

    local target_win = find_target_window()
    local open_cmd = mode == "split" and "split" or mode == "vsplit" and "vsplit" or "edit"
    local escaped = vim.fn.fnameescape(entry.path)

    if target_win and mode == "edit" then
      vim.api.nvim_win_call(target_win, function()
        vim.cmd(open_cmd .. " " .. escaped)
      end)
      vim.api.nvim_set_current_win(target_win)
    else
      if mode ~= "edit" and target_win then
        vim.api.nvim_set_current_win(target_win)
      end
      vim.cmd(open_cmd .. " " .. escaped)
    end
  end

  local kopts = { buffer = buf, noremap = true, silent = true }
  vim.keymap.set("n", "<CR>", open_selected, kopts)
  vim.keymap.set("n", "<Esc>", close, kopts)
  vim.keymap.set("n", "q", close, kopts)
  vim.keymap.set("n", "<C-n>", "j", kopts)
  vim.keymap.set("n", "<C-p>", "k", kopts)

  vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(float_win),
    once = true,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })
end

---Process the matched ref and open file or URL
---@param ref WarpRef
---@param bufnr number
---@param ns number
---@param mode OpenMode
local function process_ref(ref, bufnr, ns, mode)
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  vim.api.nvim_echo({ { "" } }, false, {})

  -- Handle URL
  if ref.type == "url" then
    open_url(ref.path)
    return
  end

  -- Handle anchor (same document heading link)
  if ref.type == "anchor" then
    jump_to_anchor(ref.path, bufnr)
    return
  end

  -- Handle file or directory
  local target_win = find_target_window()
  local path, path_type = finder.resolve_path(ref.path, bufnr)

  if path_type == "directory" then
    open_directory_browser(ref, path, mode)
    return
  end

  if path_type == "notfound" then
    vim.notify("File not found: " .. path, vim.log.levels.INFO)
    return
  end

  local open_cmd = mode == "split" and "split" or mode == "vsplit" and "vsplit" or "edit"

  if target_win and mode == "edit" then
    vim.api.nvim_win_call(target_win, function()
      vim.cmd(open_cmd .. " " .. vim.fn.fnameescape(path))
    end)
    vim.api.nvim_set_current_win(target_win)
  else
    if mode ~= "edit" then
      -- For split/vsplit, go to target window first if available
      if target_win then
        vim.api.nvim_set_current_win(target_win)
      end
    end
    vim.cmd(open_cmd .. " " .. vim.fn.fnameescape(path))
  end

  -- Set cursor to line and column (column is 0-indexed in nvim_win_set_cursor)
  local target_col = ref.column and (ref.column - 1) or 0
  vim.api.nvim_win_set_cursor(0, { ref.line, target_col })
  vim.cmd("normal! zz")
end

---Display hints and handle user input
---@param refs WarpRef[]
---@param bufnr number
function M.show_hints(refs, bufnr)
  if #refs == 0 then
    vim.notify("No visible file paths, URLs, or links found", vim.log.levels.INFO)
    return
  end

  -- Setup highlight groups
  vim.api.nvim_set_hl(0, "FileHintBg", { fg = "#1a1b26", bg = "#7aa2f7", bold = true })
  vim.api.nvim_set_hl(0, "FileHintLeft", { fg = "#7aa2f7", bg = "NONE" })
  vim.api.nvim_set_hl(0, "FileHintRight", { fg = "#7aa2f7", bg = "NONE" })
  -- URL hints have different color (green)
  vim.api.nvim_set_hl(0, "UrlHintBg", { fg = "#1a1b26", bg = "#9ece6a", bold = true })
  vim.api.nvim_set_hl(0, "UrlHintLeft", { fg = "#9ece6a", bg = "NONE" })
  vim.api.nvim_set_hl(0, "UrlHintRight", { fg = "#9ece6a", bg = "NONE" })
  -- Anchor hints have different color (orange/yellow)
  vim.api.nvim_set_hl(0, "AnchorHintBg", { fg = "#1a1b26", bg = "#e0af68", bold = true })
  vim.api.nvim_set_hl(0, "AnchorHintLeft", { fg = "#e0af68", bg = "NONE" })
  vim.api.nvim_set_hl(0, "AnchorHintRight", { fg = "#e0af68", bg = "NONE" })

  local ns = vim.api.nvim_create_namespace("file_hints")
  vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
  local hint_map = {}

  -- Place hint extmarks
  for idx, ref in ipairs(refs) do
    local key = get_hint_key(idx)
    hint_map[key] = ref
    local hl_left, hl_bg, hl_right
    if ref.type == "url" then
      hl_left, hl_bg, hl_right = "UrlHintLeft", "UrlHintBg", "UrlHintRight"
    elseif ref.type == "anchor" then
      hl_left, hl_bg, hl_right = "AnchorHintLeft", "AnchorHintBg", "AnchorHintRight"
    else
      hl_left, hl_bg, hl_right = "FileHintLeft", "FileHintBg", "FileHintRight"
    end
    pcall(vim.api.nvim_buf_set_extmark, bufnr, ns, ref.buf_line - 1, ref.col, {
      virt_text = {
        { "", hl_left },
        { " " .. key .. " ", hl_bg },
        { "", hl_right },
      },
      virt_text_pos = "inline",
      priority = 1000,
    })
  end

  vim.cmd("redraw")
  vim.api.nvim_echo({ { "Press hint key (S=split, V=vsplit, or Esc to cancel): ", "Question" } }, false, {})

  -- Input handling loop
  local input = ""
  local mode = "edit" ---@type OpenMode

  while true do
    local ok, char = pcall(vim.fn.getcharstr)
    if not ok or char == "\27" then -- Esc
      vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
      vim.api.nvim_echo({ { "" } }, false, {})
      return
    end

    -- Check for split/vsplit prefix (only at the start, use uppercase to avoid hint conflicts)
    local is_mode_prefix = false
    if input == "" and char == "S" then
      mode = "split"
      is_mode_prefix = true
    elseif input == "" and char == "V" then
      mode = "vsplit"
      is_mode_prefix = true
    end

    if not is_mode_prefix then
      input = input .. char

      if hint_map[input] then
        -- Exact match found
        if has_longer_match(input, hint_map) then
          -- There are longer hints starting with this input, wait for timeout
          local timeout_ms = vim.o.timeoutlen
          local next_char = nil

          vim.wait(timeout_ms, function()
            local c = vim.fn.getchar(0)
            if c ~= 0 then
              next_char = vim.fn.nr2char(c)
              return true
            end
            return false
          end, 10)

          if next_char then
            if next_char == "\27" then -- Esc during timeout
              vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
              vim.api.nvim_echo({ { "" } }, false, {})
              return
            end
            input = input .. next_char
            if hint_map[input] then
              process_ref(hint_map[input], bufnr, ns, mode)
              return
            elseif not has_longer_match(input, hint_map) then
              vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
              vim.api.nvim_echo({ { "No match for: " .. input, "ErrorMsg" } }, false, {})
              return
            end
          -- Continue loop if still has potential matches
          else
            -- Timeout - use current match
            process_ref(hint_map[input], bufnr, ns, mode)
            return
          end
        else
          -- No longer hints, process immediately
          process_ref(hint_map[input], bufnr, ns, mode)
          return
        end
      elseif not has_longer_match(input, hint_map) then
        -- No match and no potential longer match
        vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)
        vim.api.nvim_echo({ { "No match for: " .. input, "ErrorMsg" } }, false, {})
        return
      end
      -- Has potential longer match, continue waiting for input
    end
  end
end

return M
