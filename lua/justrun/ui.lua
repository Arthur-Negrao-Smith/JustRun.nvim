local utils = require "justrun.utils"
local state = require "justrun.state"
local config = require "justrun.config"
local runner = require "justrun.runner"

local M = {}

---@type integer
M.namespace = vim.api.nvim_create_namespace "JustRunDashboard"

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

--- Set default keymaps to use inner task terminal
---@param task_name string Target task name
---@return nil
M.set_task_terminal_keymaps = function(task_name)
  ---@type vim.keymap.set.Opts
  local opts = { noremap = true, silent = true, buffer = state.get_task_buf(task_name) }

  -- quit (q)
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(0, true)
  end, opts)

  vim.keymap.set("n", "<Esc><Esc>", function()
    vim.api.nvim_win_close(0, true)
  end, opts)
end

---@private Create a window to the task
---@param task_name string Target task name
---@param enter boolean Automatically enter in terminal if is true.
---@param force boolean? Create a buffer if not exists. Will force if nil.
---@return integer?, string? (buffer, error) Returns a buffer id and error message
M.create_task_window = function(task_name, enter, force)
  if force == nil then
    force = true
  end

  ---@type JustTaskState?
  local task_state = state.get_task_state(task_name)

  if not task_state then
    return nil, "The task '" .. task_name .. "' does not have a loaded state."
  end

  ---@type integer?
  local win = task_state.task_win

  if win and vim.api.nvim_win_is_valid(win) then
    return nil, "The task already has a window."
  end

  ---@type integer?, string?
  local buf, error = state.get_task_buf(task_name, force)

  if error then
    return nil, error
  end
  ---@cast buf integer

  ---@type integer
  local total_width = vim.o.columns
  ---@type integer
  local total_height = vim.o.lines

  ---@type integer
  local width = math.floor(total_width * 0.8)
  ---@type integer
  local height = math.floor(total_height * 0.8)

  ---@type integer
  local row = math.floor((total_height - height) / 2)
  ---@type integer
  local col = math.floor((total_width - width) / 2)

  ---@type integer
  local dash_width = 0

  ---@type integer?
  local dash_win = state.get_dashboard_win()
  if dash_win and vim.api.nvim_win_is_valid(dash_win) then
    dash_width = vim.api.nvim_win_get_width(dash_win)
    col = dash_width + 2
  end

  ---@type integer
  local available_width = total_width - dash_width
  width = math.min(available_width - 4, config.task_terminal_opts.max_width)

  height = math.min(height, config.task_terminal_opts.max_height)

  local win_opts = vim.tbl_extend("force", config.task_terminal_opts, {
    width = width,
    height = height,
    row = row,
    col = col,
  })

  -- remove custom options
  win_opts.max_width = nil
  win_opts.max_height = nil

  win = vim.api.nvim_open_win(buf, enter, win_opts)

  if win == 0 then
    return nil, "Error to create a terminal task window by neovim api"
  end

  M.set_task_terminal_keymaps(task_name)

  task_state.task_win = win

  return win, nil
end

--- Open a UI menu to select/find a task
---@return nil
M.find = function()
  ---@type string[], string?
  local commands, err = utils.load_tasks()

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
      M.render_dashboard()
      return
    end
  end)
end

--- Open a runned/running task terminal
---@param task_name string Target task to open your terminal.
---@param enter boolean? Enter automatically in terminal, if true or nil
---@param force boolean? Create a buffer if not exists. Will force if nil.
M.open_task_terminal = function(task_name, enter, force)
  if enter == nil then
    enter = true
  end

  ---@type _, string?
  local _, error = M.create_task_window(task_name, enter, force)

  if error then
    vim.notify(error, vim.log.levels.ERROR)
    return
  end
end

--- Close a runned/running task terminal
---@param task_name string Target task to close your terminal.
M.close_task_terminal = function(task_name)
  if not state.is_loaded(task_name) then
    vim.notify("The task '" .. task_name .. "' was not runned yet.", vim.log.levels.ERROR)
    return
  end

  local task_state = state.get_task_state(task_name) --[[@as JustTaskState]]
  ---@type integer?
  local task_window = state.get_task_win(task_name)

  if not task_window or not vim.api.nvim_win_is_valid(task_window) then
    vim.notify("The task '" .. task_name .. "' was not open.", vim.log.levels.ERROR)
    return
  end

  vim.api.nvim_win_close(task_window, true)
  task_state.task_win = nil
end

--- Close a runned/running task terminal
---@param task_name string Target task to close your terminal.
---@param enter boolean? Enter automatically in terminal, if true or nil.
---@param force boolean? Create a buffer to task if not exists. Will force if nil.
M.toggle_task_terminal = function(task_name, enter, force)
  local task_state = state.get_task_state(task_name)

  if task_state and task_state.task_win and vim.api.nvim_win_is_valid(task_state.task_win) then
    M.close_task_terminal(task_name)
  else
    M.open_task_terminal(task_name, enter, force)
  end
end

-- =======================
-- ====== DASHBOARD ======
-- =======================

--- Get the task name under the cursor in dashboard
---@return string, string?
M.get_task_name_under_cursor = function()
  ---@type integer?
  local buf = state.get_dashboard_buf()

  ---@type integer?
  local win = state.get_dashboard_win()

  if not buf or not win then
    return "", "Can not get a task name. The Tasks Dashboard was not opened."
  end

  local cursor = vim.api.nvim_win_get_cursor(win)
  ---@type integer
  local cursor_row = cursor[1]

  ---@type string[]
  local lines = vim.api.nvim_buf_get_lines(buf, 0, cursor_row, false)

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

---@private Set the default keymaps to interact with dashboard
---@return nil
M.set_dashboard_keymaps = function()
  ---@type vim.keymap.set.Opts
  local opts = { noremap = true, silent = true, buffer = state.get_dashboard_buf() }

  -- quit (q) & (Esc + Esc)
  vim.keymap.set("n", "q", M.toggle_dashboard, opts)

  vim.keymap.set("n", "<Esc><Esc>", M.toggle_dashboard, opts)

  -- update (u)
  vim.keymap.set("n", "u", function()
    M.render_dashboard()
    vim.notify("Tasks Dashboard was updated.", vim.log.levels.INFO)
  end, opts)

  -- re-run
  vim.keymap.set("n", "r", function()
    local task_name, error = M.get_task_name_under_cursor()

    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    runner.run(task_name)
    M.render_dashboard()
  end, opts)

  -- enter/hide task terminal (<CR>)
  vim.keymap.set("n", "<CR>", function()
    local task_name, error = M.get_task_name_under_cursor()

    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    M.toggle_task_terminal(task_name, true, false)
  end, opts)

  -- show/hide task terminal (s)
  vim.keymap.set("n", "s", function()
    local task_name, error = M.get_task_name_under_cursor()

    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    M.toggle_task_terminal(task_name, false, false)
  end, opts)

  -- delete (d)
  vim.keymap.set("n", "d", function()
    local task_name, error = M.get_task_name_under_cursor()

    if error then
      vim.notify(error, vim.log.levels.ERROR)
      return
    end

    state.unload_task(task_name)
    M.render_dashboard()
    vim.notify("The task '" .. task_name .. "' was unloaded.", vim.log.levels.INFO)
  end, opts)
end

---@param value boolean
M.set_dashboard_modifiable = function(value)
  local buf = state.get_dashboard_buf() --[[@as integer]]
  vim.api.nvim_set_option_value("modifiable", value, { buf = buf })
end

---@private Creates a buffer to Task Dashboard buffer if needed
---@return string? error Returns a error message if any error occurs
M.create_dashboard_buf = function()
  ---@type integer?
  local buf = state.get_dashboard_buf()

  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    state.set_dashboard_buf(vim.api.nvim_create_buf(false, true))
  end

  if state.get_dashboard_buf() == 0 then
    return "Error to create a buffer to the Tasks Dashboard"
  else
    M.set_dashboard_keymaps()
    M.set_dashboard_modifiable(false)
  end
end

--- Cleanup the dashboard
---@return nil
M.cleanup_dashboard_buf = function()
  local buf = state.get_dashboard_buf()
  if buf then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {})
    vim.api.nvim_buf_clear_namespace(buf, M.namespace, 0, -1)
  end
end

---@private Updates the Tasks Dashboard buffer data
---@return string? error
M.render_dashboard = function()
  ---@type string?
  local error = M.create_dashboard_buf()

  ---@type integer?
  local buf = state.get_dashboard_buf()

  if error or not buf then
    return error
  end

  M.set_dashboard_modifiable(true)
  M.cleanup_dashboard_buf()

  ---@type table<string>
  local lines = {}

  ---@type integer
  local lines_idx = 0

  local highlights = {}

  ---@type table<string, JustTaskState>
  local tasks_map = state.get_tasks_state_loaded()

  ---@type string[]
  local tasks_names = vim.tbl_keys(tasks_map)
  table.sort(tasks_names)

  if #tasks_names == 0 then
    table.insert(lines, "No tasks runing or finished yet.")
    table.insert(highlights, { #lines - 1, "Comment", 0, -1 })
  end

  for _, task_name in ipairs(tasks_names) do
    ---@type JustTaskState
    local task_state = tasks_map[task_name]

    --- Task name ---
    table.insert(lines, "Task: " .. task_name)
    table.insert(highlights, { lines_idx, "JustRunHeader", 0, 5 })
    table.insert(highlights, { lines_idx, "Special", 6, -1 })
    lines_idx = lines_idx + 1

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
    table.insert(highlights, { lines_idx, status_hl, 8, -1 })
    lines_idx = lines_idx + 1

    --- Output (Preview) ---
    ---@type string
    local output_preview = "*no output*"
    if task_state.task_buf and vim.api.nvim_buf_is_valid(task_state.task_buf) then
      local count = vim.api.nvim_buf_line_count(task_state.task_buf)
      local start_line = math.max(0, count - 10) -- get max 10 lines
      local buf_lines = vim.api.nvim_buf_get_lines(task_state.task_buf, start_line, count, false)

      for i = #buf_lines, 1, -1 do
        if buf_lines[i] and buf_lines[i] ~= "" then
          output_preview = buf_lines[i]
          break
        end
      end
    else
      output_preview = "*buffer not available*"
    end

    -- truncate output
    local max_width = config.dashboard_config.width --[[@as integer]]

    if #output_preview > max_width then
      output_preview = string.sub(output_preview, 1, max_width - 3) .. "..."
    end

    table.insert(lines, "Out: " .. output_preview)
    table.insert(highlights, { lines_idx, "Comment", 0, 4 })
    lines_idx = lines_idx + 1

    --- Separator ---
    table.insert(lines, string.rep("-", config.dashboard_config.width))
    table.insert(highlights, { lines_idx, "JustRunSeparator", 0, -1 })
    lines_idx = lines_idx + 1
  end

  --- Write in buffer ---
  vim.api.nvim_buf_set_lines(buf, 0, lines_idx, false, lines)

  for _, hl in pairs(highlights) do
    local line, group, col_start, col_end = unpack(hl)

    if col_end == -1 then
      col_end = #lines[line + 1]
    end
    vim.api.nvim_buf_set_extmark(buf, M.namespace, line, col_start, { hl_group = group, end_col = col_end })
  end

  M.set_dashboard_modifiable(false)
end

M.toggle_dashboard = function()
  ---@type integer?
  local win = state.get_dashboard_win()
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_win_close(win, true)
    state.set_dashboard_win(nil)
    return
  end

  M.render_dashboard()

  local buf = state.get_dashboard_buf() --[[@as integer]]

  vim.cmd "topleft vsplit"

  ---@type integer
  local new_win = vim.api.nvim_get_current_win()
  state.set_dashboard_win(new_win)

  local width = config.dashboard_config.width --[[@as integer]]

  vim.api.nvim_win_set_buf(new_win, buf)
  vim.api.nvim_win_set_width(new_win, width)
  -- set the header
  vim.api.nvim_set_option_value("winbar", "%=%#JustRunHeader# JustRun Dashboard %*%=", { win = new_win })

  for opt, val in pairs(config.dashboard_config) do
    if opt ~= "width" then
      vim.api.nvim_set_option_value(opt, val, { win = new_win })
    end
  end
end

---@cast M JustUi
return M
