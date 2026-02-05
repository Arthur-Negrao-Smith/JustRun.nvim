local utils = require "justrun.utils"
local state = require "justrun.state"
local config = require "justrun.config"
local runner = require "justrun.runner"

local M = {}

---@private Setup plugin highlights
---@return nil
M.setup_highlights = function()
  vim.api.nvim_set_hl(M.namespace, "JustRunHeader", { link = "Title", default = true })
  vim.api.nvim_set_hl(M.namespace, "JustRunSuccess", { link = "String", default = true })
  vim.api.nvim_set_hl(M.namespace, "JustRunFail", { link = "Error", default = true })
  vim.api.nvim_set_hl(M.namespace, "JustRunRunning", { link = "WarningMsg", default = true })
  vim.api.nvim_set_hl(M.namespace, "JustRunSeparator", { link = "Comment", default = true })
end

M.setup_highlights()

---@type integer
M.namespace = vim.api.nvim_create_namespace "JustRunDashboard"

---@private Create a window to the task
---@param task_name string Target task name
---@return integer?, string? (buffer, error)
M.create_task_window = function(task_name)
  ---@type JustTaskState?
  local task_state = state.get_task_state(task_name)

  if not task_state then
    return nil, "The task '" .. task_name .. "' does not have a loaded state."
  end

  ---@type integer?
  local win = task_state.task_win

  if win and vim.api.nvim_win_is_valid(win) then
    return nil, "The task already has a window"
  end

  ---@type integer?, string?
  local buf, error = state.get_task_buffer(task_name, true)

  if error then
    return nil, error
  end
  ---@cast buf integer

  win = vim.api.nvim_open_win(buf, false, config.task_terminal_opts)

  if win == 0 then
    return nil, "Error to create a terminal task window by neovim api"
  end

  task_state.task_win = win

  return win, nil
end

--- Open a UI menu to select/find a task
---@return nil
M.find = function()
  ---@type string[], string?
  local commands, err = utils.load_tasks_table()

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  local task_keys = vim.tbl_keys(commands)
  table.sort(task_keys)
  table.insert(task_keys, "Exit Menu")

  ---@type string
  local exit_option = "Exit Menu"

  vim.ui.select(task_keys, {
    prompt = "Select a task to run:",
    ---@param item string
    ---@return string
    format_item = function(item)
      if item == exit_option then
        return exit_option
      end

      ---@type string | JustTask | JustTaskFunc
      local task = commands[item]

      if type(task) == "string" then
        return item .. " (" .. commands[item] .. ")"
      end

      -- if is a list
      if type(task) == "table" and vim.islist(task) then
        return item .. " (" .. utils.concat_with_sep(task) .. ")"
      end

      if type(task) == "table" then
        -- if has a description
        if task.desc then
          return item .. " (" .. task.desc .. ")"
        end

        return item .. " (Complex task)"
      end

      return item
    end,
  }, function(choice)
    if choice == exit_option then
      vim.notify("Closed the tasks menu.", vim.log.levels.INFO)
      return
    end

    if choice then
      runner.run(choice)
      return
    end
  end)
end

-- =======================
-- ====== DASHBOARD ======
-- =======================

---@type integer?
M.dashboard_buf = nil

---@type integer?
M.dashboard_win = nil

---@private
---@return string, string?
M.get_task_name_under_cursor = function()
  local cursor_row, _ = vim.api.nvim_win_get_cursor(M.dashboard_win) [[@as integer]]

  ---@type string[]
  local lines = vim.api.nvim_buf_get_lines(M.dashboard_buf, 0, cursor_row, false)

  for i = #lines, 1, -1 do
    ---@type string
    local line = lines[i]

    local name = line:match "^Task: (.+)$"

    if name then
      return name, nil
    end

    if line:match "^%-%-%-%-" and i == cursor_row then
      return "", "Cursor between tasks. Can not open a ambiguos task."
    end
  end

  return "", "No tasks under the cursor."
end

---@private
---@return nil
M.set_dashboard_keymaps = function()
  ---@type vim.keymap.set.Opts
  local opts = { noremap = true, silent = true, buffer = M.dashboard_buf }

  -- quit (q)
  vim.keymap.set("n", "q", function()
    M.toggle_dashboard()
  end, opts)

  -- refresh (r)
  vim.keymap.set("n", "r", function()
    M.render_dashboard()
  end, opts)

  -- enter task terminal (<CR>)
  vim.keymap.set("n", "<CR>", function()
    local task_name, error = M.get_task_name_under_cursor()

    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    M.create_task_window(task_name)
  end, opts)
end

---@private Creates a buffer to Task Dashboard buffer if needed
---@return string? error Returns a error message if any error occurs
M.create_dashboard_buf = function()
  if M.dashboard_win and vim.api.nvim_win_is_valid(M.dashboard_win) then
    return
  end

  if not M.dashboard_buf or not vim.api.nvim_buf_is_valid(M.dashboard_buf) then
    M.dashboard_buf = vim.api.nvim_create_buf(false, true)
  end

  if M.dashboard_buf == 0 then
    return "Error to create a buffer to the Tasks Dashboard"
  end
end

---@private Cleanup the dashboard
---@return nil
M.cleanup_dashboard_buf = function()
  vim.api.nvim_buf_set_lines(M.dashboard_buf, 0, -1, false, {})
  vim.api.nvim_buf_clear_namespace(M.dashboard_buf, M.namespace, 0, -1)
end

---@private
---@param value boolean
---@return nil
M.set_dashboard_modifiable = function(value)
  vim.api.nvim_set_option_value("modifiable", value, { buf = M.dashboard_buf })
end

---@private Updates the Tasks Dashboard buffer data
M.render_dashboard = function()
  ---@type string?
  local error = M.create_dashboard_buf()

  if error then
    return error
  end

  M.set_dashboard_modifiable(true)
  M.clean_up_dashboard_buf()

  ---@type table<string>
  local lines = {}

  ---@type integer
  local lines_number = 0

  local highlights = {}

  ---@type table<string, JustTaskState>
  local tasks_map = state.get_tasks_state_loaded()

  if #tasks_map == 0 then
    table.insert(lines, "No tasks runing or finished yet.")
    table.insert(highlights, { #lines - 1, "Comment", 0, -1 })
  end

  for task_name, task_state in ipairs(tasks_map) do
    --- Task name ---
    table.insert(lines, "Task: " .. task_name)
    table.insert(highlights, { lines_number - 1, "JustRunHeader", 0, 5 })
    table.insert(highlights, { lines_number - 1, "Special", 6, -1 })
    lines_number = lines_number + 1

    --- Status ---
    local status_icon = "●"
    local status_hl = "JustRunRunning"
    if task_state.status == "success" then
      status_hl = "JustRunSuccess"
      status_icon = "✔"
    elseif task_state.status == "fail" then
      status_hl = "JustRunFail"
      status_icon = "✖"
    end

    table.insert(lines, string.format("Status: %s %s", status_icon, task_state.status))
    table.insert(highlights, { lines_number, status_hl, 8, -1 })
    lines_number = lines_number + 1

    --- Output (Preview) ---
    ---@type string
    local output_preview = "*no output*"
    if task_state.task_buf and vim.api.nvim_buf_is_valid(task_state.task_buf) then
      local count = vim.api.nvim_buf_line_count(task_state.task_buf)
      local start_line = math.max(0, count - 10) -- get max 10 lines
      local buf_lines = vim.api.nvim_buf_get_lines(task_state.task_buf, start_line, count, false)

      for i = #buf_lines, 1, -1 do
        if buf_lines[i] and buf_lines[i] ~= "" then
          output_preview = buf_lines[1]
          break
        end
      end
    else
      output_preview = "*buffer not available*"
    end

    -- truncate output
    if #output_preview > 60 then
      output_preview = string.sub(output_preview, 1, 57) .. "..."
    end

    table.insert(lines, "Out: " .. output_preview)
    table.insert(highlights, { lines_number, "Comment", 0, 4 })
    lines_number = lines_number + 1

    --- Separator ---
    table.insert(lines, string.rep("-", 40))
    table.insert(highlights, { lines_number, "JustRunSeparator", 0, -1 })
    lines_number = lines_number + 1
  end

  --- Write in buffer ---
  vim.api.nvim_buf_set_lines(M.dashboard_buf, 0, lines_number, false, lines)

  for _, hl in pairs(highlights) do
    local line, group, col_start, col_end = unpack(hl)

    if col_end == -1 then
      col_end = #line[line]
    end
    vim.api.nvim_buf_set_extmark(M.dashboard_buf, M.namespace, line, col_start, { hl_group = group, col_end = col_end })
  end

  M.set_dashboard_modifiable(false)
end

M.toggle_dashboard = function()
  if M.dashboard_win and vim.api.nvim_win_is_valid(M.dashboard_win) then
    vim.api.nvim_win_close(M.dashboard_win, true)
    M.dashboard_win = nil
    return
  end

  M.set_dashboard_keymaps()

  M.render_dashboard()

  ---@type vim.api.keyset.win_config
  local win_opts = vim.deepcopy(config.dashboard_config)
  win_opts.title = " JustRun DashBoard "
  win_opts.title_pos = "center"

  M.dashboard_win = vim.api.nvim_open_win(M.dashboard_buf, true, win_opts)
end

return M
