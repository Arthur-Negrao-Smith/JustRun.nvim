---@meta

-- ============================
-- ===== TASKS DEFINITIONS ====
-- ============================

---@class JustTask A complex task definition.
---@field cmd JustRunnable | JustTaskFunc | nil Commands to run.
---@field run_before string[]? Tasks to run before this one (Only tasks name).
---@field desc string? Task description.
---@field exit_on_success boolean? Close window on success.
---@field cwd string? The task's current working directory.
---@field sep string? Separator to join task commands list. If nil uses the default_sep.

--- Represents any valid entry that the JustRun can execute.
--- It can be a simple shell string, a list of strings, or a full configuration object.
---@alias JustRunnable string | string[] | JustTask

--- A function that dynamically generates a task command or object at runtime.
---@alias JustTaskFunc fun(): JustRunnable

--- Table with runnable tasks. Maps from a task name to a runnable task.
---@alias JustTasksTable table<string, JustRunnable>[]

-- ============================
-- ======= RUNTIME STATE ======
-- ============================

--- Represents a resulta/status of a runtime task instance.
---@alias JustTaskStatus "success" | "fail" | "running"

---@class JustState JustRun plugin global state
---
--- ATTRIBUTES
---
---@field private dashboard_buf integer? Buffer of the dashboard.
---@field private dashboard_win integer? Window of the dashboard.
---@field last_task string? Last task executed.
---@field private loaded_tasks table<string, JustTaskState> All loaded tasks.
---
--- STATE MANAGEMENT METHODS
---
---@field is_running fun(task_name: string): boolean Checks if a task is currently running.
---@field load_task fun(task_name: string, task: JustRunnable) Loads a task into memory (Internal).
---@field unload_task fun(task_name: string) Removes task from memory and clears associated buffers.
---@field active_task fun(task_name: string, task: JustRunnable) Loads a task and sets its status to 'running'.
---@field finish_task fun(task_name: string, status: JustTaskStatus) Updates the task status to finished (success/fail).
---
--- GETTERS
---
---@field get_running_tasks fun(): table<string, JustTaskState> Returns a table of all currently running tasks.
---@field get_finished_tasks fun(): table<string, JustTaskState> Returns a table of all finished tasks (inactive).
---@field get_task_status fun(task_name: string): JustTaskStatus Returns the current status of a specific task.
---@field get_loaded_task fun(task_name: string): JustRunnable Returns the raw definition of a loaded task.
---
--- UI & BUFFER METHODS
---
---@field private create_task_buffer fun(task_name: string): (integer?, string?) Creates or retrieves the task buffer (Internal).
---@field private create_task_window fun(task_name: string): (integer?, string?) Creates or retrieves the task window (Internal).
---@field get_task_buffer fun(task_name: string): (integer?, string?) Safe wrapper to get the task buffer ID.
---@field get_task_window fun(task_name: string): (integer?, string?) Safe wrapper to get the task window ID.

---@class JustTaskState Tracks the runtime execution state of a task instance.
---@field task JustRunnable The a runnable task to execute.
---@field status JustTaskStatus State of the task.
---@field task_buf integer? Terminal task buffer.
---@field task_win integer? Terminal task window.

-- ============================
-- ====== CONFIGURATION =======
-- ============================

---@class JustConfig JustRun custom table configs.
---@field filename string? Default file to load task definitions. Default: .justrun.lua.
---@field filetype JustTasksTable? Default table to run filetypes when :JustRunFile is used without arguments.
---@field show_filetype_tasks boolean? Show the others filetype taks in :JustRunFind. Show only the current filetype task if false. Default: false.
---@field default_task string? Task to run when :JustRun is used without arguments. Default: "default".
---@field cwd string? Default woriking directory. This option can be overridden by the "cwd" field in task definition. Default: ".".
---@field force_run boolean? If arguments are missing, run default task, if is not found, run the first available task. Default: false.
---@field split_direction "vertical" | "horizontal" | nil Orientation of the terminal split
---@field exit_on_success boolean? Close the terminal if the task succeeds. This option can be overwritten in the task body. Default: false.
---@field default_sep string? Default separator to join tasks commands. This option can be overwritten in the task body. Default: "&&".
---@field max_depth integer? Maximum recursion depth for nested tasks to prevent infinity loops. Use -1 to disable the limit (caution). Default: 20.
---@field task_terminal_opts vim.api.keyset.win_config Configs to the floating terminal.
