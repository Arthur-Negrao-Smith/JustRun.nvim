local config = require "justrun.config"

local M = {}

--- Get the default separator between blank spaces
---@return string
M.get_sep = function()
  return " " .. config.default_sep .. " "
end

--- Join all list of strings with a separator
---@param t table A table/list of strings to join
---@param sep string? A separator used to join strings. Uses the default_sep if is nil
---@return string
M.concat_with_sep = function(t, sep)
  if sep then
    return table.concat(t, sep)
  end

  return table.concat(t, M.get_sep())
end

--- Is true if the current system is windows
---@type boolean
M.is_windows = vim.fn.has "win33" == 1 or vim.fn.has "win64" == 1

--- Returns true if the current shell is powershell
---@return boolean
M.is_powershell = function()
  return M.is_windows and (vim.o.shell:lower():find "powershell" == 1 or vim.o.shell:lower():find "pwsh" == 1)
end

---@param cmd string Command to replace placeholders
---@return string
M.replace_placeholders = function(cmd)
  ---@type string
  local current_file = vim.api.nvim_buf_get_name(0)

  -- if does't have a file
  if current_file == "" then
    return cmd
  end

  -- replacements table like vscode
  local replacements = {
    ["${file}"] = vim.fn.expand "%:p", -- /home/user/main.py
    ["${fileNoExtension}"] = vim.fn.expand "%:r", -- /home/user/main
    ["${fileBasename}"] = vim.fn.expand "%:t", -- main.py
    ["${fileBasenameNoExtension}"] = vim.fn.expand "%:t:r", -- main
    ["${fileDirname}"] = vim.fn.expand "%:p:h", -- /home/user
    ["${relativeFile}"] = vim.fn.expand "%", -- main.py (if the file is in root)
    ["${workspaceFolder}"] = vim.fn.getcwd(), -- /home/user/project (open folder by nvim)
  }

  for key, value in pairs(replacements) do
    local escaped_key = key:gsub("([%-%^%$%%.%[%]%(%)%*%+%?])", "%%%1") -- create scapes to avoid
    cmd = cmd:gsub(escaped_key, value)
  end

  cmd = cmd:gsub("%%:r", vim.fn.expand "%:r")
  cmd = cmd:gsub("%%:t", vim.fn.expand "%:t")
  cmd = cmd:gsub("%%:h", vim.fn.expand "%:h")
  cmd = cmd:gsub("%%:p", vim.fn.expand "%:p")

  -- disable the symbol '%' when he is alone on windows: `lua %` will not works.
  -- prevent errors with windows envarioments variables like:
  -- %USERNAME% -> main.luaUSERNAMEmain.lua
  if not M.is_windows then
    cmd = cmd:gsub("%%", vim.fn.expand "%")
  end

  return cmd
end

--- A wrapper to process commands
---@param cmd string Command to process
---@return string
M.process_cmd = function(cmd)
  return M.replace_placeholders(cmd)
end

--- Load all tasks like a table from the configuration file
---@return JustTasksTable commands Table with runnable tasks. Return a empty table is error occurs
---@return string? err Error message
M.load_tasks = function()
  ---@type string
  local workdir = vim.fn.getcwd()

  ---@type string
  local tasks_file = workdir .. "/" .. config.filename

  if vim.fn.filereadable(tasks_file) == 0 then
    return {}, "File " .. config.filename .. " not found in root workdir: " .. workdir
  end

  ---@type boolean, string[]
  local status, result = pcall(dofile, tasks_file)

  if not status then
    return {}, "Syntax error in " .. config.filename .. ": " .. tostring(result)
  end

  if type(result) ~= "table" then
    return {}, "The file " .. config.filename .. " must return a Lua table."
  end

  return result, nil
end

--- ANSI colors to unix terminal
---@type table<string, string>
M.ANSI_COLORS = {
  RED = [=[\e[31m]=],
  GREEN = [=[\e[32m]=],
  BLUE = [=[\e[34m]=],
  MAGENTA = [=[\e[35m]=],
  RESET = [=[\e[0m]=],
  BOLD = [=[\e[1m]=],
  DARK_GREY = [=[\e[90m]=],
}

return M
