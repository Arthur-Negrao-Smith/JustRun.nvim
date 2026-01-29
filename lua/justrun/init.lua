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

	--- If the selected task not found, then run
	--- the first task in the table. Default: false
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

--- Load all tasks in file
---@return string[]? commands
---@return string? err
M.load_tasks = function()
	---@type string
	local workdir = vim.fn.getcwd()

	---@type string
	local task_file = workdir .. "/" .. M.config.filename

	if vim.fn.filereadable(task_file) == 0 then
		return nil, "File " .. task_file .. " not found in root workdir"
	end

	---@type boolean, string[]
	local status, result = pcall(dofile, task_file)

	if not status then
		return nil, "Error reading " .. M.config.filename .. " must return a Lua table"
	end

	return result, nil
end

--- Run a task from a lua file
---@param task_name string?
---@return nil
M.run = function(task_name)
	---@type string[]?, string?
	local commands, err = M.load_tasks()

	-- if a error occurs to load the commands
	if err then
		vim.notify(err, vim.log.levels.ERROR)
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

	---@type "vsplit" | "split"
	local split_cmd = M.config.split_direction == "vertical" and "vsplit" or "split"
	vim.cmd(split_cmd)

	-- create a new buffer
	local terminal_buffer = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_win_set_buf(0, terminal_buffer)

	if M.config.split_direction == "vertical" then
		vim.cmd("vertical resize " .. M.config.split_size)
	else
		vim.cmd("resize " .. M.config.split_size)
	end

	vim.fn.jobstart(cmd_to_run, {
		term = true,
		on_exit = function(job_id, exit_code, event_type)
			print("Task exited with code: " .. exit_code)
		end,
	})

	vim.opt_local.number = false
	vim.opt_local.relativenumber = false
	vim.cmd("startinsert") -- enter in insert mode in terminal
end

return M
