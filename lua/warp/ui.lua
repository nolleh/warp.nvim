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

  -- Handle file
  local target_win = find_target_window()
  local path = finder.resolve_path(ref.path)

  if vim.fn.filereadable(path) == 0 then
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

  vim.api.nvim_win_set_cursor(0, { ref.line, 0 })
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
