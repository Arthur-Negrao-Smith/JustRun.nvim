if not pcall(require, "justrun") then
  return
end

local justrun = require "justrun"

---@param ArgLead string
---@return table
local function tasks_complete(ArgLead, _, _)
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
end

---@param opts vim.api.keyset.create_user_command.command_args
vim.api.nvim_create_user_command("JustRun", function(opts)
  ---@type string?
  local args = opts.args

  if args == "" then
    args = nil
  end

  justrun.run(args)
end, {
  nargs = "?", -- only 1 or 0 arguments
  complete = tasks_complete,
})

vim.api.nvim_create_user_command("JustRunUnderCursor", justrun.run_under_cursor, {
  nargs = 0,
})

vim.api.nvim_create_user_command("JustRunToggle", justrun.toggle_dashboard, {
  nargs = 0,
})

vim.api.nvim_create_user_command("JustRunFind", justrun.find, {
  nargs = 0,
})

vim.api.nvim_create_user_command("JustRunLast", justrun.run_last, {
  nargs = 0,
})

---@param opts vim.api.keyset.create_user_command.command_args
vim.api.nvim_create_user_command("JustRunFile", function(opts)
  ---@type string?
  local filename = opts.args

  if filename == "" then
    filename = nil
  end

  justrun.run_file(filename)
end, {
  nargs = "?",
  complete = "file",
})

---@param opts vim.api.keyset.create_user_command.command_args
vim.api.nvim_create_user_command("JustRunOpenTerminal", function(opts)
  ---@type string?
  local filename = opts.args

  if filename == "" then
    filename = nil
  end

  justrun.open_task_terminal(filename)
end, {
  nargs = 1,
  complete = tasks_complete,
})

---@param opts vim.api.keyset.create_user_command.command_args
vim.api.nvim_create_user_command("JustRunCloseTerminal", function(opts)
  ---@type string?
  local filename = opts.args

  if filename == "" then
    filename = nil
  end

  justrun.close_task_terminal(filename)
end, {
  nargs = 1,
  complete = tasks_complete,
})

---@param opts vim.api.keyset.create_user_command.command_args
vim.api.nvim_create_user_command("JustRunToggleTerminal", function(opts)
  ---@type string?
  local filename = opts.args

  if filename == "" then
    filename = nil
  end

  justrun.toggle_task_terminal(filename)
end, {
  nargs = 1,
  complete = tasks_complete,
})
