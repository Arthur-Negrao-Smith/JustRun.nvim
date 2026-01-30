if not pcall(require, "justrun") then
	return
end

local justrun = require("justrun")

---@param opts vim.api.keyset.create_user_command.command_args
vim.api.nvim_create_user_command("JustRun", function(opts)
	---@type string?
	local args = opts.args

	if args == "" then
		args = nil
	end

	justrun.run(args)
end, {
	nargs = "?", -- just 1 or 0 arguments
	complete = function(ArgLead, CmdLine, CursorPos)
		local tasks, _ = justrun.load_tasks()

		if not tasks then
			return {}
		end

		local task_keys = vim.tbl_keys(tasks)
		table.sort(task_keys)

		local matches = {}
		for _, key in ipairs(task_keys) do
			if key:sub(1, #ArgLead) == ArgLead then
				table.insert(matches, key)
			end
		end

		return matches
	end,
})

vim.api.nvim_create_user_command("JustRunUnderCursor", justrun.run_under_cursor, {
	nargs = 0,
})
