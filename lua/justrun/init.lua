local M = {}

M.config = {
	--- Default file to load task definitions.
	--- Default: ".justrun.lua"
	---@type string
	filename = ".justrun.lua",

	--- Task to run when use :JustRun is used without arguments
	--- Default: "default"
	---@type string
	default_task = "default",

	--- Default working directory. This option can be overridden
	--- by the "cwd" field in the task definition.
	--- Default: "."
	---@type string
	cwd = ".",

	--- If arguments are missing and the default task is not found,
	--- run the first available task in the table.
	--- Default: false
	---@type boolean
	force_run = false,

	--- Orientation of the terminal split.
	--- Default: "vertical"
	---@type "vertical" | "horizontal"
	split_direction = "vertical",

	--- Size of the terminal split.
	--- Default: 50
	---@type integer
	split_size = 50,

	--- Close the terminal if the task succeeds. This option can be
	--- overridden by 'exit_on_success' in the task definition.
	--- Default: false
	---@type boolean
	exit_on_success = false,

	--- Default separator used to join task commands.
	--- Default: "&&"
	---@type string
	default_sep = "&&",

	--- Maximum recursion depth for nested tasks to prevent
	--- infinite loops. Set to -1 to disable the limit (use
	--- with caution).
	--- Default: 20
	---@type integer
	max_depth = 20,
}

--- Default setup function
---@param opts table?
---@return nil
M.setup = function(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

local state = {
	---@type integer?
	buf = nil,

	---@type integer?
	win = nil,

	--- last task runned
	---@type string?
	last_task = nil,
}

---@return string
local function get_sep()
	return " " .. M.config.default_sep .. " "
end

---@param t table A table/list of strings to join
---@return string
local function concat_with_sep(t)
	return table.concat(t, get_sep())
end

--- Get a buffer to run the task, recycling a window if possible
---@return integer|nil
local function get_terminal_window()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_set_current_win(state.win)
	else
		---@type "vsplit" | "split"
		local split_cmd = M.config.split_direction == "vertical" and "vsplit" or "split"
		vim.cmd(split_cmd)
		state.win = vim.api.nvim_get_current_win()

		---@type "vertical resize " | "resize "
		local resize_cmd = M.config.split_direction == "vertical" and "vertical resize " or "resize "
		vim.cmd(resize_cmd .. M.config.split_size)
	end

	-- delete the older buffer
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end

	state.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(state.win, state.buf)
	return state.buf
end

---@alias JustTaskFunc fun(): JustTask | string | string[]

---@class JustTask
---@field cmd string | string[] | JustTaskFunc | nil Commands to run
---@field run_before string[]? Tasks to run before this one. (Only tasks name)
---@field desc string? Task description
---@field exit_on_success boolean? Close window on success
---@field cwd string? The task's current working directory
local JustTask = {}

---@alias JustTasksTable table<string, string | string[] | JustTask>[]

--- Recursively resolve the command string for a task
---@param task_data string | string[] | JustTask Current task to handle
---@param all_tasks JustTasksTable Table containing all tasks
---@param depth integer Current recursion depth
---@return string command
---@return string? err
local function handle_task(task_data, all_tasks, depth)
	-- check for max recursion depth
	if depth ~= -1 and depth > M.config.max_depth then
		---@type string
		local err = "Max nesting limit reached (" .. M.config.max_depth .. "). Possible circular dependency."
		return "", err
	end

	if type(task_data) == "string" then
		return task_data, nil
	end

	if type(task_data) == "table" and vim.islist(task_data) then
		return concat_with_sep(task_data), nil
	end

	---@type string[]
	local commands_to_join = {}

	-- handle dependencies (run_before)
	if task_data.run_before then
		for _, item in ipairs(task_data.run_before) do
			-- if the item is a known task, recurse
			if all_tasks[item] then
				local sub_cmd, err = handle_task(all_tasks[item], all_tasks, depth + 1)

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
			local func_res = task_data.cmd()

			if type(func_res) == "string" then
				table.insert(commands_to_join, func_res)

				-- if cmd is table/list of strings
			elseif type(func_res) == "table" and vim.islist(func_res) then
				table.insert(commands_to_join, concat_with_sep(func_res))

			-- function returned a JustTask object
			else
				local sub_cmd, err = handle_task(task_data.cmd(), all_tasks, depth + 1)

				if err then
					return "", err
				end

				table.insert(commands_to_join, sub_cmd)
			end

		-- if cmd is a list of strings
		elseif type(task_data.cmd) == "table" and vim.islist(task_data.cmd) then
			table.insert(commands_to_join, concat_with_sep(task_data.cmd))

		-- if the task is a string or a nested JustTask
		else
			local sub_cmd, err = handle_task(task_data.cmd, all_tasks, depth + 1)

			if err then
				return "", err
			end

			table.insert(commands_to_join, sub_cmd)
		end
	end

	-- join all strings to shell
	return concat_with_sep(commands_to_join)
end

--- Load all tasks from the configuration file
---@return JustTasksTable commands
---@return string? err
M.load_tasks = function()
	---@type string
	local workdir = vim.fn.getcwd()

	---@type string
	local task_file = workdir .. "/" .. M.config.filename

	if vim.fn.filereadable(task_file) == 0 then
		return {}, "File " .. M.config.filename .. " not found in root workdir: " .. workdir
	end

	---@type boolean, string[]
	local status, result = pcall(dofile, task_file)

	if not status then
		return {}, "Syntax error in " .. M.config.filename .. ": " .. tostring(result)
	end

	if type(result) ~= "table" then
		return {}, "The file " .. M.config.filename .. " must return a Lua table."
	end

	return result, nil
end

--- Run a  specific task or the default one
---@param task_name string?
---@return nil
M.run = function(task_name)
	---@type JustTasksTable, string?
	local tasks_table, err = M.load_tasks()

	if err then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	if vim.tbl_isempty(tasks_table) then
		vim.notify("Undefined error to load the tasks", vim.log.levels.ERROR)
		return
	end

	---@type string
	local target_task = task_name or M.config.default_task

	---@type boolean
	local user_provide_args = (task_name ~= nil and task_name ~= "")

	---@type string | JustTask | nil
	local task_to_run = tasks_table[target_task]

	-- handle missing task
	if not task_to_run then
		-- if the user doesn't provide args and force_run is enable, run the first task available
		if not user_provide_args and M.config.force_run then
			local first_key, first_val = next(tasks_table)

			if first_val then
				task_to_run = first_val
				vim.notify("No tasks were provided. Runnig: " .. first_key, vim.log.levels.INFO)
			else
				vim.notify("No tasks found in file.", vim.log.levels.ERROR)
				return
			end
		else
			vim.notify("Task not found: " .. target_task, vim.log.levels.ERROR)
			return
		end
	end

	state.last_task = target_task

	---@type string, string?
	local cmd_to_run, err = handle_task(task_to_run, tasks_table, 1)

	if err then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	get_terminal_window()

	vim.notify("Running task: " .. target_task, vim.log.levels.INFO)

	---@type boolean
	local should_exit = M.config.exit_on_success
	if type(task_to_run) == "table" and task_to_run.exit_on_success ~= nil then
		should_exit = task_to_run.exit_on_success
	end

	vim.fn.jobstart(cmd_to_run, {
		term = true,
		cwd = task_to_run.cwd or M.config.cwd,
		on_exit = function(_, exit_code, _)
			print("Task '" .. target_task .. "' finished with code: " .. exit_code)

			if should_exit then
				vim.api.nvim_win_close(state.win, true)
				return
			end
		end,
	})

	vim.opt_local.number = false
	vim.opt_local.relativenumber = false
	vim.cmd("startinsert") -- enter insert mode in terminal
end

--- Run the task defined under the cursor in the config file
---@return nil
M.run_under_cursor = function()
	if vim.o.filetype ~= "lua" then
		vim.notify("Just lua files can run tasks: " .. vim.o.filetype, vim.log.levels.ERROR)
		return
	end

	local current_filename = string.gsub(vim.api.nvim_buf_get_name(0), vim.fn.getcwd() .. "/", "")
	if current_filename ~= M.config.filename then
		vim.notify(
			"Just default tasks file '" .. M.config.filename .. "' can run tasks: " .. current_filename,
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
	local key_nodes = node:field("name") -- name in lua is just a variable or string

	if #key_nodes == 0 then
		key_nodes = node:field("key") -- key in lua is a [""]
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

--- Open a UI menu to select a task
---@return nil
M.ui = function()
	---@type string[], string?
	local commands, err = M.load_tasks()

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
				return item .. " (" .. concat_with_sep(task) .. ")"
			end

			if type(task) == "table" then
				-- if has a description
				if task.desc then
					return item .. " (" .. task.desc .. ")"
				end

				-- if the cmd is a list
				if task.cmd and vim.islist(task.cmd) then
					return item .. " (" .. concat_with_sep(task.cmd) .. ")"

					-- if the cmd is a function
				elseif task.cmd and type(task.cmd) == "function" then
					---@type string | string[] | JustTask
					local func_return = task.cmd()

					-- if the function returns a string
					if type(func_return) == "string" then
						return item .. " (" .. func_return .. ")"

					-- if the function returns a string list
					elseif type(func_return) == "table" and vim.islist(func_return) then
						return item .. " (" .. concat_with_sep(func_return) .. ")"

					-- if the function returns a JustTask
					else
						return item .. " (Nested tasks)"
					end

					-- if the cmd is a string
				elseif task.cmd and type(task.cmd) == "string" then
					return item .. " (" .. task.cmd .. ")"
				end
			end

			return item
		end,
	}, function(choice)
		if choice == exit_option then
			vim.notify("Closed the tasks menu.", vim.log.levels.INFO)
			return
		end

		if choice then
			M.run(choice)
			return
		end
	end)
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

--- Helper function to enable type hinting in user config
---@param tasks JustTasksTable
---@return JustTasksTable
M.create_tasks = function(tasks)
	return tasks
end

return M
