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

--- Load all tasks in file
---@return string[] commands
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
	---@type string[], string?
	local commands, err = M.load_tasks()

	-- if a error occurs to load the commands
	if err then
		vim.notify(err, vim.log.levels.ERROR)
		return
	end

	if commands == {} then
		vim.notify("Undefined error to load the tasks", vim.log.levels.ERROR)
		return
	end

	---@type string
	local target_task = task_name or M.config.default_task

	---@type boolean
	local user_provide_args = (task_name ~= nil and task_name ~= "")

	---@type string?
	local cmd_to_run = commands[target_task]

	-- if the task is null
	if not cmd_to_run then
		-- if the user don't provide arguments and force run task
		if not user_provide_args and M.config.force_run then
			local first_key, first_val = next(commands)

			-- if the first value is not nil
			if first_val then
				cmd_to_run = first_val
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

	get_terminal_window()

	vim.notify("Running task: " .. target_task, vim.log.levels.INFO)

	vim.fn.jobstart(cmd_to_run, {
		term = true,
		on_exit = function(_, exit_code, _)
			print("Task '" .. target_task .. "' finished with code: " .. exit_code)
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
		format_item = function(item)
			if item == exit_option then
				return exit_option
			end

			return item .. " (" .. commands[item] .. ")"
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
---@type nil
M.run_last = function()
	if not state.last_task then
		vim.notify("No tasks have been run yet!", vim.log.levels.WARN)
		return
	end

	M.run(state.last_task)
end

return M
