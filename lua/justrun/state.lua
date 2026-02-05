local JustTaskState = {}

JustTaskState.__index = JustTaskState

--- Create a new JustTaskState
---@param task JustRunnable Target task
---@return JustTaskState
function JustTaskState:new(task)
  ---@type JustTaskState
  local instance = setmetatable({}, self)

  instance.task = task
  instance.task_buf = nil
  instance.task_win = nil
  instance.status = "running"

  return instance
end

local M = {
  ---@type integer?
  dashboard_buf = nil,

  ---@type integer?
  dashboard_win = nil,

  --- Last task name runned
  ---@type string?
  last_task = nil,

  --- All loaded tasks: Map from task name to task
  ---@type table<string, JustTaskState>
  loaded_tasks = {},
}

--- Check if the task is running
---@param task_name string Name of the task to check
---@return boolean
M.is_running = function(task_name)
  if M.loaded_tasks[task_name].status == "running" then
    return true
  end

  return false
end

---@private Load a task in global state
---@param task_name string Target task name
---@param task string | string[] | JustTask
---@return nil
M.load_task = function(task_name, task)
  if M.loaded_tasks[task_name] == nil then
    M.loaded_tasks[task_name] = JustTaskState:new(task)
  end
end

--- Unload a task in global state
---@param task_name string Target task name
---@return nil
M.unload_task = function(task_name)
  ---@type JustTaskState
  local task_state = M.loaded_tasks[task_name]

  if not task_state then
    return
  end

  if task_state.task_win and vim.api.nvim_win_is_valid(task_state.task_win) then
    vim.api.nvim_win_close(task_state.task_win, true)
  end

  if task_state.task_buf and vim.api.nvim_buf_is_valid(task_state.task_buf) then
    vim.api.nvim_buf_delete(task_state.task_buf, { force = true })
  end

  M.loaded_tasks[task_name] = nil
end

---@param task_name any
---@return boolean
M.is_loaded = function(task_name)
  if M.loaded_tasks[task_name] then
    return true
  end

  return false
end

--- Change the state of a task to running and create a new buffer to the task.
---@param task_name string Name of the task to run
---@param task string | string[] | JustTask
---@return nil
M.active_task = function(task_name, task)
  M.load_task(task_name, task)

  local _, error = M.reset_task_buffer(task_name)

  if error then
    vim.notify(error, vim.log.levels.ERROR)
    return
  end

  local task_state = M.get_task_state(task_name) --[[@as JustTaskState]]
  task_state.status = "running"
end

--- Change a State of a task to a finished state: success or fail
---@param task_name string Target task name
---@param task_state "success" | "fail"
---@return nil
M.finish_task = function(task_name, task_state)
  M.loaded_tasks[task_name].status = task_state
end

--- Get all active tasks
---@return table<string, JustTaskState>
M.get_running_tasks = function()
  ---@type table<string, JustTaskState>
  local running_tasks = {}

  ---@type string, JustTaskState
  for task_name, task in pairs(M.loaded_tasks) do
    if M.is_running(task_name) then
      running_tasks[task_name] = task
    end
  end

  return running_tasks
end

--- Get all loaded finished tasks
---@return table<string, JustTaskState>
M.get_finished_tasks = function()
  ---@type table<string, JustTaskState>
  local finished_tasks = {}

  ---@type string, JustTaskState
  for task_name, task in pairs(M.loaded_tasks) do
    if not M.is_running(task_name) then
      finished_tasks[task_name] = task
    end
  end

  return finished_tasks
end

--- Get the task state
---@param task_name string Target task name
---@return JustTaskStatus
M.get_task_status = function(task_name)
  return M.loaded_tasks[task_name].status
end

--- Get a loaded task
---@param task_name string Target task name
---@return string | string[] | JustTask task Loaded task
M.get_loaded_task = function(task_name)
  return M.loaded_tasks[task_name].task
end

--- Get a loaded task state
---@param task_name string Target task name
---@return JustTaskState? task_state Loaded task state. Returns nil if the task state does not loaded.
M.get_task_state = function(task_name)
  return M.loaded_tasks[task_name]
end

--- Get all status tasks loaded
---@return table<string, JustTaskState>
M.get_tasks_state_loaded = function()
  return M.loaded_tasks
end

---@private Create a buffer to the task
---@param task_name string Target task name
---@return integer?, string? (buffer, error)
M.create_task_buffer = function(task_name)
  ---@type JustTaskState
  local task_state = M.loaded_tasks[task_name]

  ---@type integer?, string?
  local buf, error = nil, nil

  buf = vim.api.nvim_create_buf(false, true)

  if buf == 0 then
    error = "Error to create a buffer by neovim api"
    return nil, error
  end

  task_state.task_buf = buf

  return buf, nil
end

---@private Reset the task buffer
---@param task_name string
---@return string?
M.reset_task_buffer = function(task_name)
  local task_state = M.get_task_state(task_name)

  if not task_state then
    return "The task '" .. task_name .. "' is loaded."
  end

  ---@type integer?
  local buf = task_state.task_buf

  if buf and vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_delete(buf, { force = true })
  end

  local _, error = M.create_task_buffer(task_name)

  if error then
    return error
  end
end

--- Get the terminal task buffer
---@param task_name string Target task name
---@param force boolean? Create the buffer if does not exists
---@return integer?, string? (buffer, error) Terminal task buffer and error
M.get_task_buffer = function(task_name, force)
  ---@type JustTaskState?
  local task_state = M.get_task_state(task_name)

  if not task_state then
    return nil, "Task state not loaded for: " .. task_name
  end

  ---@type integer?, string?
  local buf, err = nil, nil
  buf = task_state.task_buf

  ---@type boolean
  local is_valid = buf ~= nil and vim.api.nvim_buf_is_valid(buf)

  if not is_valid and force == true then
    buf, err = M.create_task_buffer(task_name)
  elseif not is_valid then
    return nil, "Buffer for task '" .. task_name .. "' is invalid or deleted."
  end

  return buf, err
end

--- Get the terminal task window.
---@param task_name string Target task name.
---@return integer? window Terminal task window.
M.get_task_window = function(task_name)
  return M.loaded_tasks[task_name].task_win
end

--- Get the tasks dashboard buffer
---@return integer?
M.get_dashboard_buf = function()
  return M.dashboard_buf
end

--- Get the tasks dashboard window
---@return integer?
M.get_dashboard_win = function()
  return M.dashboard_win
end

-- Set the tasks dashboard buffer.
---@param buf integer? The new tasks dashboard buffer value.
---@return nil
M.set_dashboard_buf = function(buf)
  M.dashboard_buf = buf
end

-- Set the tasks dashboard window.
---@param win integer? The new tasks dashboard window value.
---@return nil
M.set_dashboard_win = function(win)
  M.dashboard_win = win
end

---@cast M JustState
return M
