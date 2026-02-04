local M = {}

local config = require "justrun.config"
local utils = require "justrun.utils"
local state = require "justrun.state"

--- Recursively resolve the command string for a task
---@param task_data string | string[] | JustTask Current task to handle
---@param all_tasks JustTasksTable Table containing all tasks
---@param depth integer Current recursion depth
---@return string command
---@return string? err
M.handle_task = function(task_data, all_tasks, depth)
  -- check for max recursion depth
  if depth ~= -1 and depth > config.max_depth then
    ---@type string
    local err = "Max nesting limit reached (" .. config.max_depth .. "). Possible circular dependency."
    return "", err
  end

  if type(task_data) == "string" then
    return utils.process_cmd(task_data), nil
  end

  if type(task_data) == "table" and vim.islist(task_data) then
    ---@type string[]
    local processed_list = vim.tbl_map(utils.process_cmd, task_data)
    return utils.concat_with_sep(processed_list), nil
  end

  ---@type string[]
  local commands_to_join = {}

  -- handle dependencies (run_before)
  if task_data.run_before then
    for _, item in ipairs(task_data.run_before) do
      -- if the item is a known task, recurse
      if all_tasks[item] then
        local sub_cmd, err = M.handle_task(all_tasks[item], all_tasks, depth + 1)

        if err then
          return "", err
        end

        table.insert(commands_to_join, sub_cmd)

        -- if is not a task name, treat as a raw command
      else
        table.insert(commands_to_join, item)
      end
    end
  end

  -- handle the main command
  if task_data.cmd then
    -- if cmd is a function (dynamic command)
    if type(task_data.cmd) == "function" then
      ---@type string | string[] | JustTask
      local func_res = task_data.cmd()

      if type(func_res) == "string" then
        table.insert(commands_to_join, utils.process_cmd(func_res))

        -- if cmd is table/list of strings
      elseif type(func_res) == "table" and vim.islist(func_res) then
        ---@type string[]
        local processed_list = vim.tbl_map(utils.process_cmd, func_res)
        table.insert(commands_to_join, utils.concat_with_sep(processed_list))

      -- function returned a JustTask object
      else
        local sub_cmd, err = M.handle_task(task_data.cmd(), all_tasks, depth + 1)

        if err then
          return "", err
        end

        table.insert(commands_to_join, sub_cmd)
      end

    -- if cmd is a list of strings
    elseif type(task_data.cmd) == "table" and vim.islist(task_data.cmd) then
      ---@type string[]
      local processed_list = vim.tbl_map(utils.process_cmd, task_data.cmd)
      table.insert(commands_to_join, utils.concat_with_sep(processed_list, task_data.sep))

    -- if the task is a string or a nested JustTask
    else
      local sub_cmd, err = M.handle_task(task_data.cmd, all_tasks, depth + 1)

      if err then
        return "", err
      end

      table.insert(commands_to_join, sub_cmd)
    end
  end

  -- join all strings to shell
  return utils.concat_with_sep(commands_to_join)
end

---@private Init a job to run a command in the background
---@param cmd string Command to run
---@param task JustRunnable Target task to manage
---@param task_name string Target task name
---@param should_exit boolean Close the terminal automatically when the job finish if true
---@param buf integer Buffer id
M.start_job = function(cmd, task, task_name, should_exit, buf)
  state.active_task(task_name, task)
  vim.notify("Running task: " .. task_name, vim.log.levels.INFO)

  local job_opts = {
    term = true,
    cwd = task.cwd or config.cwd,

    on_exit = function(job_id, exit_code, event)
      if should_exit and exit_code == 0 then
        state.finish_task(task_name, "success")
        ---@integer?, string?
        local win, err = state.get_task_window(task_name)

        if err then
          vim.notify(err, vim.log.levels.ERROR)
          return
        end

        if win and vim.api.nvim_win_is_valid(win) then
          vim.api.nvim_win_close(win, true)
        end
      end
    end,
  }

  vim.api.nvim_buf_call(buf, function()
    vim.fn.jobstart(cmd, job_opts)
  end)

  vim.api.nvim_buf_call(buf, function()
    vim.cmd "startinsert" -- enter insert mode in terminal to autoscroll
  end)
end

--- Run a  specific task or the default one
---@param task_name string? Target task to run
---@return nil
M.run = function(task_name)
  ---@type JustTasksTable, string?
  local tasks_table, err = utils.load_tasks_table()

  ---@type boolean
  local is_filetype = (task_name ~= nil and config.filetype[task_name] ~= nil)

  if err and not is_filetype then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  if vim.tbl_isempty(tasks_table) and not is_filetype then
    vim.notify("Undefined error to load the tasks", vim.log.levels.ERROR)
    return
  end

  ---@type string
  local target_task_name = task_name or config.default_task --[[@as string]]

  ---@type boolean
  local user_provide_args = (task_name ~= nil and task_name ~= "")

  ---@type JustRunnable?
  local task_to_run = tasks_table[target_task_name] or config.filetype[target_task_name]

  -- handle missing task
  if not task_to_run then
    -- if the user doesn't provide args and force_run is enable, run the first task available
    if not user_provide_args and config.force_run then
      local first_task_name, first_task = next(tasks_table)

      if first_task then
        target_task_name = first_task_name --[[@as string]]
        task_to_run = first_task
        vim.notify("No tasks were provided. Runnig: " .. first_task_name, vim.log.levels.INFO)
      else
        vim.notify("No tasks found in file.", vim.log.levels.ERROR)
        return
      end
    else
      vim.notify("Task not found: " .. target_task_name, vim.log.levels.ERROR)
      return
    end
  end

  state.last_task = target_task_name

  ---@type string
  local cmd_to_run = ""

  cmd_to_run, err = M.handle_task(task_to_run, tasks_table, 1)

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

  ---@type boolean
  local should_exit = config.exit_on_success
  if type(task_to_run) == "table" and task_to_run.exit_on_success ~= nil then
    should_exit = task_to_run.exit_on_success
  end

  ---@type integer?
  local buf = nil

  buf, err = state.get_task_buffer(target_task_name, true)

  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  ---@cast buf integer

  M.start_job(cmd_to_run, task_to_run, target_task_name, should_exit, buf)
end

--- Run the task defined under the cursor in the config file
---@return nil
M.run_under_cursor = function()
  if vim.o.filetype ~= "lua" then
    vim.notify("Just lua files can run tasks: " .. vim.o.filetype, vim.log.levels.ERROR)
    return
  end

  local current_filename = string.gsub(vim.api.nvim_buf_get_name(0), vim.fn.getcwd() .. "/", "")
  if current_filename ~= config.filename then
    vim.notify(
      "Just default tasks file '" .. config.filename .. "' can run tasks: " .. current_filename,
      vim.log.levels.ERROR
    )
    return
  end

  local treesitter = vim.treesitter

  local has_parser = pcall(treesitter.get_parser, 0, "lua")
  if not has_parser then
    vim.notify("TreeSitter Lua parser not found.", vim.log.levels.ERROR)
    return
  end

  ---@type TSNode?
  local node = treesitter.get_node()

  while node do
    if node:type() == "field" then
      break
    end

    node = node:parent()
  end

  if not node then
    vim.notify("Cursor is not inside a task definition.", vim.log.levels.ERROR)
    return
  end

  ---@type TSNode[]
  local key_nodes = node:field "name" -- name in lua is just a variable or string

  if #key_nodes == 0 then
    key_nodes = node:field "key" -- key in lua is a [""]
  end

  if #key_nodes == 0 then
    vim.notify("Could not identify task name.", vim.log.levels.ERROR)
    return
  end

  ---@type TSNode
  local task_key = key_nodes[1]

  ---@type string
  local task_name = treesitter.get_node_text(task_key, 0)

  -- clean the task name. Ex: ["key"] -> key
  task_name = task_name:gsub("[%[%]\"']", "")

  M.run(task_name)
end

--- Run a file with JustRun tasks. Run the current file if no privede arguments
---@param filename string? Name of the file to run. Run the current file if nil
---@return nil
M.run_file = function(filename)
  ---@type JustTasksTable
  local tasks, _ = utils.load_tasks_table()

  if filename then
    ---@type string?
    local filetype = vim.filetype.match { filename = filename }

    if not filetype then
      vim.notify("Neovim can not to infer filetype of the file: " .. filename, vim.log.levels.ERROR)
      return
    end

    ---@type JustRunnable | nil
    local current_filetype_task = tasks[filetype] or config.filetype[filetype]

    if not current_filetype_task then
      vim.notify(
        "Filetype '" .. filetype .. "' does not have a task to run the file: " .. filename,
        vim.log.levels.ERROR
      )
      return
    end

    M.run(filetype)
    return
  end

  ---@type string?
  local filetype = vim.filetype.match { buf = 0 }

  if not filetype then
    vim.notify("Neovim can not to infer filetype of the current file: " .. vim.fn.expand "%", vim.log.levels.ERROR)
    return
  end

  local current_filetype_task = tasks[filetype] or config.filetype[filetype]
  if not current_filetype_task then
    vim.notify(
      "Filetype '" .. filetype .. "' does not have a task to run the current file: " .. vim.fn.expand "%",
      vim.log.levels.ERROR
    )
    return
  end

  M.run(filetype)
end

--- Re-run the last executed task
---@return nil
M.run_last = function()
  if not state.last_task then
    vim.notify("No tasks have been run yet!", vim.log.levels.WARN)
    return
  end

  M.run(state.last_task)
end

---@cast M JustRunner
return M
