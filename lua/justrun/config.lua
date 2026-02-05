local M = {}

M = {
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
  terminal_opts = {
    ---@type string
    relative = "editor",

    --- Vim ui effects
    ---@type string
    style = "minimal",

    --- Border style
    ---@type string
    border = "rounded",

    --- Default: current_window_width * 0.8
    ---@type integer
    max_width = math.floor(vim.o.columns * 0.8),

    ---@type integer
    --- Default: current_window_height * 0.8
    max_height = math.floor(vim.o.lines * 0.8),
  },

  dashboard_opts = {
    width = 40,
    number = false,
    refresh_interval = 1000, -- 1s
    relativenumber = false,
    cursorline = true,
    signcolumn = "no",
    foldcolumn = "0",
    wrap = false,
    spell = false,
    list = false,
    winfixwidth = true,
  },
}

--- Default setup function
---@param opts JustConfig? All custom table configs
---@return nil
M.setup = function(opts)
  M = vim.tbl_deep_extend("force", M.config, opts or {})
end

M.get_cleaned_dashboard_opts = function()
  local dashboard_opts = vim.deepcopy(M.dashboard_opts)
  dashboard_opts["refresh_interval"] = nil
  dashboard_opts["width"] = nil

  return dashboard_opts
end

M.get_cleaned_terminal_opts = function()
  local terminal_opts = vim.deepcopy(M.terminal_opts)
  terminal_opts["max_width"] = nil
  terminal_opts["max_height"] = nil

  return terminal_opts
end

---@cast M JustConfig
return M
