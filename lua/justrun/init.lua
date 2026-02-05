local M = {}

local config = require "justrun.config"
local runner = require "justrun.runner"
local ui = require "justrun.ui"
local utils = require "justrun.utils"

-- Setup
M.setup = config.setup

-- Utils
M.load_tasks = utils.load_tasks

-- Commands
M.run = runner.run
M.run_file = runner.run_file
M.run_last = runner.run_last
M.run_under_cursor = runner.run_under_cursor

-- UI
M.toggle_dashboard = ui.toggle_dashboard
M.find = ui.find
M.open_task_terminal = ui.open_task_terminal
M.close_task_terminal = ui.close_task_terminal
M.toggle_task_terminal = ui.toggle_task_terminal

-- Helper
---@param tasks JustTasksTable
---@return JustTasksTable
M.create_tasks = function(tasks)
  return tasks
end

return M
