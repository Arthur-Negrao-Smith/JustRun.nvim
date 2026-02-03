local M = {}

M.config = {
  --- Default file to load task definitions.
  --- Default: ".justrun.lua"
  ---@type string
  filename = ".justrun.lua",

  --- Default table to run filetypes when :JustRunFile is
  --- used without arguments
  ---@type JustTasksTable
  filetype = {
    lua = { cmd = "lua ${file}", desc = "Run current lua file" },
    python = { cmd = "python ${file}", desc = "Run current python file" },
    javascript = { cmd = "node ${file}", desc = "Run current javascript file" },
  },

  -- TODO: implement show_filetype_tasks
  --- Show the others filetype taks in :JustRunFind. Show only the current
  --- filetype task if false. Default: false
  ---@type boolean
  show_filetype_tasks = false,

  --- Task to run when :JustRun is used without arguments
  --- Default: "default"
  ---@type string
  default_task = "default",

  --- Default working directory. This option can be overridden
  --- by the "cwd" field in the task definition.
  --- Default: "."
  ---@type string
  cwd = ".",

  --- If arguments are missing, run the default task, if it is not found,
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

  --- Terminal floating window opts
  ---@type vim.api.keyset.win_config
  task_terminal_opts = {
    relative = "editor",
    col = math.floor((vim.o.columns - vim.api.nvim_win_get_width(0)) / 2),
    row = math.floor((vim.o.lines - vim.api.nvim_win_get_width(0)) / 2),
    --- Default: current_window_width * 0.8
    width = math.floor(vim.api.nvim_win_get_width(0) * 0.8),
    --- Default: current_window_height * 0.8
    height = math.floor(vim.api.nvim_win_get_height(0) * 0.8),
    style = "minimal",
    border = "rounded",
  },
}

--- Default setup function
---@param opts JustConfig? All custom table configs
---@return nil
M.setup = function(opts)
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})
end

---@cast M JustConfig
return M
