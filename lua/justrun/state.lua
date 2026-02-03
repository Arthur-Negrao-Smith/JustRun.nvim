---@alias JustTaskStatus "success" | "fail" | "running"

---@class JustTaskState
---@field task string | string[] | JustTask The task to run
---@field status JustTaskStatus State of the task
---@field task_buf integer? Terminal task buffer
---@field task_win integer? Terminal task window
local JustTaskState = {}

JustTaskState.__index = JustTaskState

---@param task string | string[] | JustTask
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

---@class JustState JustRun plugin global state
---@field private dashboard_buf integer? Buffer of the dashboard
---@field private dashboard_win integer? Window of the dashboard
---@field private last_task string? Last task executed
---@field private loaded_tasks table<string, JustTaskState> All loaded tasks
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

--- Check if a task is running
---@param task_name string Name of the task to check
---@return boolean
M.is_running = function(task_name)
	if M.loaded_tasks[task_name].status == "running" then
		return true
	end

	return false
end

---@private Load a task in global state
---@param task_name string
---@param task string | string[] | JustTask
---@return nil
M.load_task = function(task_name, task)
	if M.loaded_tasks[task_name] == nil then
		M.loaded_tasks[task_name] = JustTaskState:new(task)
	end
end

--- Change the state of a task to running
---@param task_name string Name of the task to run
---@param task string | string[] | JustTask
---@return nil
M.active_task = function(task_name, task)
	M.load_task(task_name, task)

	M.loaded_tasks[task_name].status = "running"
end

--- Change a State of a task to a finished state: success or fail
---@param task_name string
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
	for task_name, task in ipairs(M.loaded_tasks) do
		if task.is_running then
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
	for task_name, task in ipairs(M.loaded_tasks) do
		if not task.is_active then
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

---@private Create a buffer to the task
---@param task_name string
---@return integer, string? (buffer, error)
M.create_task_buffer = function(task_name)
	local task_state = M.loaded_tasks[task_name]
	---@type integer?
	local buf = task_state.task_buf
	---@type string?
	local error = nil

	if buf then
		return buf, nil
	end

	buf = vim.api.nvim_create_buf(false, true)

	if buf == 0 then
		error = "Error to create a buffer by neovim api"
		return -1, error
	end

	task_state.task_buf = buf

	return buf, nil
end

--- Get the task buffer
---@param task_name string Target task name
---@return integer? buffer Terminal task buffer
M.get_task_buffer = function(task_name)
	return M.loaded_tasks[task_name].task_buf
end

--- Get the terminal task window
---@param task_name string Target task name
---@return integer? window Terminal task window
M.get_task_window = function(task_name)
	return M.loaded_tasks[task_name].task_win
end

return M
