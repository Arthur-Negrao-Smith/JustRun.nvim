# JustRun.nvim 🏃

A simple, flexible, and powerful task runner for Neovim, written entirely in Lua. Define your project tasks in a local Lua file and run them easily inside a terminal buffer.

## ✨ Features

* **Pure Lua**: Written entirely in Lua, ensuring fast startup times and seamless Neovim integration.
* **Project-local configuration**: Define tasks in a `.justrun.lua` file in your project root.
* **Flexible Task Definitions**: Tasks can be simple strings, lists of commands, or complex objects.
* **Task Dependencies**: Use `run_before` to chain tasks (e.g., run `build` before `test`).
* **Smart Auto-closing**: Configure tasks to close the terminal automatically on success.
* **Placeholders**: Use variables like `${file}` to create flexible, context-aware tasks.
* **Run Under Cursor**: Execute a specific task just by placing your cursor over its name in the config file.
* **UI Menu**: Select tasks from a nice UI list (`vim.ui.select`).
* **Recursion Protection**: Built-in protection against infinite loops in nested tasks.
* **Type Hinting**: Full LSP support for your configuration file.

## ⚡ Installation

Install using your favorite package manager. For [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Arthur-Negrao-Smith/JustRun.nvim",
    tag = "v1.2.0", -- Recommended to lock to the stable version
    dependencies = {
        "nvim-treesitter/nvim-treesitter", -- Required for :JustRunUnderCursor
    },
    config = function()
        require("justrun").setup({
            -- Optional configuration (see 'Configuration' section)
            split_direction = "vertical",
            split_size = 50,
        })
    end,
    cmd = { "JustRun", "JustRunUi", "JustRunLast", "JustRunUnderCursor" },
    keys = {
        { "<leader>jr", "<cmd>JustRunUi<cr>", desc = "JustRun: Open Menu" },
        { "<leader>jl", "<cmd>JustRunLast<cr>", desc = "JustRun: Rerun Last" },
    },
}
```

## ⚙️ Configuration

You can customize the default behavior in the `setup` function. Here are the default values:

```lua
require("justrun").setup({
    -- Default file to load tasks from
    filename = ".justrun.lua",

    -- Default task to run if :JustRun is called without args
    default_task = "default",

    -- Current working directory (can be overwritten per task)
    cwd = ".",

    -- If true, runs the first available task if default_task is missing
    force_run = false,

    -- Terminal orientation: "vertical" | "horizontal"
    split_direction = "vertical",

    -- Terminal split size
    split_size = 50,

    -- Close terminal if task exits with code 0
    exit_on_success = false,

    -- Separator for command chaining (e.g., "&&" or ";")
    default_sep = "&&",

    -- Maximum recursion depth for nested tasks to prevent infinite loops.
    -- Set to -1 to disable the limit (use with caution).
    max_depth = 20,
})
```

## 🚀 Usage

Create a file named `.justrun.lua` in the root of your project.

### 1. Minimal Example
You can return a simple table where keys are task names and values are commands.

```lua
-- .justrun.lua
return {
    default = "echo 'Hello World'",
    build = "go build .",
    test = "go test ./...",
}
```

### 2. Complex Example with Type Hinting
Use `justrun.create_tasks` to enable autocomplete (LSP) for available fields.

```lua
-- .justrun.lua
local justrun = require("justrun")

return justrun.create_tasks({
    -- Simple String
    clean = "rm -rf ./dist",

    -- List of commands (joined by &&)
    lint = { "eslint .", "prettier --check ." },

    -- Complex Task Object
    build = {
        cmd = "npm run build",
        desc = "Builds the project for production",
        cwd = "./frontend", -- Run in a specific folder
    },

    -- Nested Tasks (Dependencies)
    deploy = {
        -- Runs 'clean', then 'lint', then 'build', then this cmd
        run_before = { "clean", "lint", "build" },
        cmd = "echo 'Deploying to server...'",
        exit_on_success = true, -- Close terminal if successful
    },

    -- Default Separator (&&)
    build_all = {
        -- Joins with &&: "cd build && cmake .. && make"
        cmd = {"cd build", "cmake ..", "make"}
    },

    -- Custom separator ( )
    run_args = {
            -- Joins with space: "python main.py --verbose --dry-run"
            cmd = {"python", "main.py", "--verbose", "--dry-run"},
            sep = " ", -- Custom separator for the cmd list
        },

    -- Placeholders
    run_lua = {
        cmd = "lua ${file}" -- JustRun replaces placeholder automatically
    },

    -- Dynamic Command (Function)
    -- cmd could be a function to return a string | string[] | JustTask
    -- Example: Manual string concatenation (Hard way)
    dynamic_cmd = {
        cmd = function()
            local cmd = ""
            for i=1, 5 do
                if i ~= 5 then
                    cmd = cmd .."echo '" .. i .. "';"
                else
                    cmd = cmd .. "echo '" .. i .. "'"
                end
            end
            return cmd
        end
    },

    -- Equivalent to dynamic_cmd but using table/list (Easy way)
    dynamic_cmd_with_sep = {
        cmd = function()
            local cmd_list = {}
            for i=1, 5 do
                table.insert(cmd_list, "echo '" .. i .. "'")
            end
            return cmd_list
        end,
        sep = "; " -- Custom separator for the list
    },
})
```

### Task Options Reference

| Field | Type | Description |
| :--- | :--- | :--- |
| `cmd` | `string` \| `string[]` \| `function` | The shell command(s) to execute. |
| `run_before` | `string[]` | List of other task **names** to run before this one. |
| `cwd` | `string` | Directory to execute the command in. |
| `exit_on_success`| `boolean` | If `true`, closes the split automatically on exit code 0. |
| `sep` | `string` | Custom separator to join `cmd` list items (default: `&&`). |
| `desc` | `string` | Description shown in the UI menu. |

## 🎮 Commands

| Command | Arguments | Description |
| :--- | :--- | :--- |
| `:JustRun` | `[task_name]` | Runs the specified task. If empty, runs `default_task`. |
| `:JustRunUi` | None | Opens a selection menu (UI) with all available tasks. |
| `:JustRunLast`| None | Re-runs the last executed task. Great for TDD. |
| `:JustRunUnderCursor` | None | Runs the task defined under the cursor in `.justrun.lua`. |

## 🤝 Contributing

Pull requests are welcome! The codebase is written entirely in Lua and documented in English. If you find a bug or have a feature request, please open an issue.

---
**License**: GNU v3.0
