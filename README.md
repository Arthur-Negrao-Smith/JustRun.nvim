# JustRun.nvim 🏃

A simple, flexible, and powerful task runner for Neovim, written entirely in Lua. Define your project tasks in a local Lua file and run them easily inside a terminal buffer.

## ✨ Features

* **Pure Lua**: Written entirely in Lua for fast startup.
* **Project-local configuration**: Define tasks in `.justrun.lua`.
* **Interactive Dashboard**: Real-time status updates, logs preview, and task management.
* **Smart Task Menu**: Automatically prioritizes the default task and the current filetype task in the search menu.
* **Filetype Awareness**: Auto-detects and runs tasks based on the current filetype.
* **Flexible Definitions**: Supports strings, lists, complex objects, and dynamic functions.
* **Dependencies**: Chain tasks using `run_before`.
* **Placeholders**: VSCode-style variables (`${file}`, `${workspaceFolder}`) and Vim modifiers.
* **Recursion Protection**: Prevents infinite loops in nested tasks.
* **Type Hinting**: Full LSP support with provided classes.
## ⚡ Installation

Install using your favorite package manager. For [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Arthur-Negrao-Smith/JustRun.nvim",
    tag = "v2.0.1", -- Recommended to lock to the stable version
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
    cmd = { "JustRun", "JustRunUi", "JustRunLast", "JustRunUnderCursor", "JustRunFile" },
    keys = {
        { "<leader>jd", "<cmd>JustRun<cr>", desc = "JustRun: Run default task" },
        { "<leader>jf", "<cmd>JustRunFile<cr>", desc = "JustRun: Run current file" },
        { "<leader>js", "<cmd>JustRunFind<cr>", desc = "JustRun: Open Find Menu" },
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

    -- Default tasks for filetypes (overridable)
    filetype = {
        lua = { cmd = "lua ${file}", desc = "Run current lua file" },
        python = { cmd = "python ${file}", desc = "Run current python file" },
        javascript = { cmd = "node ${file}", desc = "Run current javascript file" },

        -- *Others default filetypes tasks* --
    },

    -- Behavior of the Find Menu (:JustRunFind)
    -- false: Shows project tasks + ONLY the current filetype task.
    -- true: Shows project tasks + ALL global filetype tasks.
    show_filetype_tasks = false,

    -- Default task if :JustRun is called without args
    default_task = "default",

    -- Global working directory
    cwd = ".",

    -- If true, runs the first available task if default_task is missing
    force_run = false,

    -- Close terminal if task exits with code 0
    exit_on_success = false,

    -- Separator for command chaining (e.g., "&&" or ";")
    default_sep = "&&",

    -- Floating Window Options for the Task Terminal
    terminal_opts = {
        relative = "editor",
        style = "minimal",
        border = "rounded",
        -- Dynamic sizing (defaults to 80% of screen)
        max_width = math.floor(vim.o.columns * 0.8),
        max_height = math.floor(vim.o.lines * 0.8),
    },

    -- Dashboard Configuration
    dashboard_opts = {
        width = 40,              -- Width of the dashboard split
        refresh_interval = 1000, -- Auto-refresh interval in ms
        -- Window options for the dashboard buffer
        cursorline = true,
        number = false,
        wrap = false,
    },
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
    run_script = {
        -- JustRun replaces placeholders automatically
        cmd = "lua ${file} && echo '${fileBasename}'"
    },

    -- Filetypes
    -- :JustRunFile can infer the current filetype to run the correct task.
    -- JustRun.nvim use the filetype tasks with the same filetype name to 
    -- run automatically.
    python = {
        cmd = "python ${file}",
        desc = "Run current python file"
    }

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

## 📊 Interactive Dashboard

JustRun v2.0 introduces a real-time Dashboard to monitor your tasks. It opens automatically (or via toggle) and updates the status of running tasks.

**Keymaps inside the Dashboard:**

| Key | Action |
| :--- | :--- |
| `<CR>` | **Enter/Focus or Hide**: Opens the task terminal and focuses it. |
| `s` | **Show or Hide**: Opens the task terminal without focusing (peek). |
| `r` | **Re-run**: Re-runs the task under the cursor. |
| `d` | **Delete**: Unloads/Stops the task and clears the buffer. |
| `u` | **Update**: Manually refreshes the dashboard view. |
| `q` | **Quit**: Closes the dashboard. |

The dashboard displays:
- **Status Icons**: `✔` (Success), `✖` (Fail), `●` (Running).
- **Output Preview**: The last few lines of the terminal output.

### Task Options Reference

| Field | Type | Description |
| :--- | :--- | :--- |
| `cmd` | `string` \| `string[]` \| `function` | The shell command(s) to execute. |
| `run_before` | `string[]` | List of other task **names** to run before this one. |
| `cwd` | `string` | Directory to execute the command in. |
| `exit_on_success`| `boolean` | If `true`, closes the split automatically on exit code 0. |
| `sep` | `string` | Custom separator to join `cmd` list items (default: `&&`). |
| `desc` | `string` | Description shown in the UI menu. |

### Placeholders

The JustRun.nvim supports placeholder to create flexible, context-aware tasks. List of supported placeholders:

| Vim style | VS-Code style | Description |
| :--- | :--- | :--- |
| `%` | `${relativeFile}` | Relative path to current file. |
| `%:p` | `${file}` | Absolute path to current file. |
| `%:r` | `${fileNoExtension}` | Absolute path to current file without extension (e.g., /home/user/project/main). |
| `%:t` | `${fileBasename}` | Filename without path (e.g., main.py) |
| `%:t:r` | `${fileBasenameNoExtension}` | Filename without path and no extension (e.g., /home/user/project/main.py -> main). |
| `%:p:h` | `${fileDirname}` | Directory name of the current file. |
| None | `${workspaceFolder}` | Absolute path to workspace opened by neovim. |

See [filename-modifiers](https://neovim.io/doc/user/cmdline.html#filename-modifiers) to learn about Vim style placeholders.

### Filetypes

The JustRun.nvim supports running files by the filetype. This option can be useful to run default files without extra code. Example:

```lua
    require("justrun").setup({
        -- use this keyword to create a table with all default filetype tasks
        filetype = {
            lua = {
                cmd = "lua ${file}",
                desc = "Run the current lua file",
            },
            python = {
                cmd = "python %{file}",
                desc = "Run the current python file",
            },
            -- filetype tasks could be string, string[] or JustTask
            javascript = "node %{file}",
            }
        }
    })
```

Additionally, you can also overwrite the default filetype task using the filetype name in your tasks table. Example:

```lua
local justrun = require("justrun")

return justrun.create_tasks({
    -- the task must have the same name of the filetype name task to overwrite the default filetype task
    python = {
        cmd = "echo 'Runing the python file' && python ${file}",
        desc = "Run the current python file",
    }
})
```

Whenever the command `:JustRunFile` is called, the filetype will be inferred by the neovim and the JustRun.nvim will automatically search the correct filetype task to this file. See [neovim filetypes](https://neovim.io/doc/user/filetype.html) to learn more about filetypes.

## 🎮 Commands

| Command | Arguments | Description |
| :--- | :--- | :--- |
| `:JustRun` | `[task_name]` | Runs the specified task. If empty, runs `default_task`. |
| `:JustRunFind` | None | Opens a selection menu (UI) with all available tasks. |
| `:JustRunLast` | None | Re-runs the last executed task. Great for TDD. |
| `:JustRunUnderCursor` | None | Runs the task defined under the cursor in `.justrun.lua`. |
| `:JustRunFile` | `[file_name]` | Runs the file using a filetype task. If empty, tries run the current file. |
| `:JustRunToggle` | None | Toggles the Dashboard visibility. |
| `:JustRunOpenTerminal` | `[task_name]` | Opens the floating terminal window for a specific task. |
| `:JustRunCloseTerminal` | `[task_name]` | Closes the floating terminal window for a specific task. |
| `:JustRunToggleTerminal` | `[task_name]` | Toggles (Open/Close) the floating terminal window for a specific task. |

## 🤝 Contributing

Pull requests are welcome! The codebase is written entirely in Lua and documented in English. If you find a bug or have a feature request, please open an issue.

---
**License**: GNU GPL-3.0
