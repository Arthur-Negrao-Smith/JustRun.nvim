local M = {}

M.config = {
	--- Default file to load the execute commands.
	--- Default: ".justrun.lua"
	---@type string
	filename = ".justrun.lua",

	--- Name to search the default task when use :JustRun
	--- without args. Default: "default"
	---@type string
	default_task = "default",

	--- If the user don't provide args and the default task
	--- not found, then run the first task in the table.
	--- Default: false
	---@type boolean
	force_run = false,

	--- Opened terminal orientation. Default: "vertical"
	---@type "vertical" | "horizontal"
	split_direction = "vertical",

	--- Terminal size. Default: 50
	---@type integer
	split_size = 50,

	--- Close the terminal if the task was a success. This
	--- option could be overwrited by 'exit_on_success' in
	--- current task in tasks table. Default: false
	---@type boolean
	exit_on_success = false,
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

--- Get a buffer to run the task
---@return integer|nil
local function get_terminal_window()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_set_current_win(state.win)
	else
		local split_cmd = M.config.split_direction == "vertical" and "vsplit" or "split"
		vim.cmd(split_cmd)
		state.win = vim.api.nvim_get_current_win()

		local resize_cmd = M.config.split_direction == "vertical" and "vertical resize " or "resize "
		vim.cmd(resize_cmd .. M.config.split_size)
	end

	-- delete the old buffer
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
---@field run_before string[]? Tasks to run before. (Only tasks name)
---@field desc string? Task description
---@field exit_on_success boolean?
local JustTask = {}

---@alias JustTasksTable table<string, string | string[] | JustTask>[]

--- Get the command of the current task
---@param task_data string | string[] | JustTask
---@param all_tasks JustTasksTable
---@return string
local function handle_task(task_data, all_tasks)
	if type(task_data) == "string" then
		return task_data
	end

	if type(task_data) == "table" and vim.islist(task_data) then
		return table.concat(task_data, " && ")
	end

	---@type string[]
	local commands_to_join = {}

	-- if task has others tasks to run
	if task_data.run_before then
		for _, item in ipairs(task_data.run_before) do
			-- if the item is a task, then use recursion
			if all_tasks[item] then
				table.insert(commands_to_join, handle_task(all_tasks[item], all_tasks))
			else
				-- if is not a task name, then is a command
				table.insert(commands_to_join, item)
			end
		end
	end

	-- if the task has a command, then use recursion
	if task_data.cmd then
		-- if the task is a function
		if type(task_data.cmd) == "function" then
			local func_res = task_data.cmd()
			-- if function returns a string
			if type(func_res) == "string" then
				table.insert(commands_to_join, func_res)

			-- if the function returns an array
			elseif type(func_res) == "table" and vim.islist(func_res) then
				table.insert(commands_to_join, table.concat(func_res, " && "))

			-- if the function returns a JustTask
			else
				table.insert(commands_to_join, handle_task(task_data.cmd(), all_tasks))
			end

		-- if the task is an array
		elseif type(task_data.cmd) == "table" and vim.islist(task_data.cmd) then
			table.insert(commands_to_join, table.concat(task_data.cmd, " && "))

		-- if the task is a string or a JustTask
		else
			table.insert(commands_to_join, handle_task(task_data.cmd, all_tasks))
		end
	end

	-- concat all strings to shell
	return table.concat(commands_to_join, " && ")
end

--- Load all tasks in file
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

--- Run a task from a lua file
---@param task_name string?
---@return nil
M.run = function(task_name)
	---@type JustTasksTable, string?
	local tasks_table, err = M.load_tasks()

	-- if a error occurs to load the commands
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

	-- if the task is null
	if not task_to_run then
		-- if the user don't provide arguments and force run task
		if not user_provide_args and M.config.force_run then
			local first_key, first_val = next(tasks_table)

			-- if the first value is not nil
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

	local cmd_to_run = handle_task(task_to_run, tasks_table)

	get_terminal_window()

	vim.notify("Running task: " .. target_task, vim.log.levels.INFO)

	---@type boolean
	local should_exit = M.config.exit_on_success
	if type(task_to_run) == "table" and task_to_run.exit_on_success ~= nil then
		should_exit = task_to_run.exit_on_success
	end

	vim.fn.jobstart(cmd_to_run, {
		term = true,
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
	vim.cmd("startinsert") -- enter in insert mode in terminal
end

--- Run the task under the cursor
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

	---@type TSNode? node under the cursor
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

--- Run a ui with all tasks in a menu to select
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
				return item .. " (" .. table.concat(task, " && ") .. ")"
			end

			if type(task) == "table" then
				-- if has a description
				if task.desc then
					return item .. " (" .. task.desc .. ")"
				end

				-- if is a list
				if task.cmd and vim.islist(task.cmd) then
					return item .. " (" .. table.concat(task.cmd, " && ") .. ")"
					-- if is a function
				elseif task.cmd and type(task.cmd) == "function" then
					return item .. " (" .. task.cmd() .. ")"
					-- if is a string
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

--- Run the last runned task
---@return nil
M.run_last = function()
	if not state.last_task then
		vim.notify("No tasks have been run yet!", vim.log.levels.WARN)
		return
	end

	M.run(state.last_task)
end

--- Helper function to enable typehint in user config
---@param tasks JustTasksTable
---@return JustTasksTable
M.create_tasks = function(tasks)
	return tasks
end

return M
