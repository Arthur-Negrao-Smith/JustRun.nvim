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
---@field is_loaded fun(task_name: string): boolean Checks if a task is loaded.
---@field private load_task fun(task_name: string, task: JustRunnable) Loads a task into memory (Internal).
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
---@field get_task_state fun(task_name: string): JustTaskState? Returns the current loaded task state. Returns nil if the task state does not loaded.
---@field get_tasks_state_loaded fun(): table<string, JustTaskState> Get all status tasks loaded.
---@field get_task_buf fun(task_name: string, force: boolean?): (integer?, string?) Safe wrapper to get the task buffer ID.
---@field get_task_win fun(task_name: string, force: boolean?): (integer?, string?) Safe wrapper to get the task window ID.
---@field get_dashboard_buf fun(): integer? Returns the tasks dashboard buffer id.
---@field get_dashboard_win fun(): integer? Returns the tasks dashboard window id.
---
--- SETTERS
---
--- @field set_dashboard_buf fun(buf: integer?): nil Set the tasks dashboard buffer.
--- @field set_dashboard_win fun(win: integer?): nil Set the tasks dashboard window.
---
--- UI & BUFFER METHODS
---
---@field private create_task_buf fun(task_name: string): (integer?, string?) Creates or retrieves the task buffer (Internal).
---@field private create_task_win fun(task_name: string): (integer?, string?) Creates or retrieves the task window (Internal).

---@class JustTaskState Tracks the runtime execution state of a task instance.
---@field task JustRunnable The a runnable task to execute.
---@field status JustTaskStatus State of the task.
---@field task_buf integer? Terminal task buffer.
---@field task_win integer? Terminal task window.

-- ============================
-- ========= RUNNER ===========
-- ============================

---@class JustRunner The core of the JustRun. A runner to execute any task.
---@field run fun(task_name: string?): nil Run a task. Runs default task if task_name is nil.
---@field run_last fun(): nil Run the last task executed.
---@field run_file fun(filename: string?): nil Run a file by filetype.
---@field run_under_cursor fun(): nil Run a task under the cursor.

-- ============================
-- =========== UI =============
-- ============================

---@class JustUi UI components and Dashboard management.
---@field namespace integer The namespace used for highlighting dashboard components.
---
--- HIGHLIGHTS & SETUP
---
---@field private setup_highlights fun(): nil Sets up the highlight groups for the UI (Header, Success, Fail, etc.).
---
--- TASK WINDOW
---
---@field create_task_window fun(task_name: string): (integer?, string?) Opens a floating window for a specific task's buffer. Returns window ID or error.
---
--- SELECTION MENU
---
---@field find fun(): nil Opens a `vim.ui.select` menu to pick and run tasks.
---
--- DASHBOARD METHODS
---
---@field get_task_name_under_cursor fun(): (string, string?) Retrieves the task name based on the cursor position in the dashboard.
---@field private set_dashboard_keymaps fun(): nil Sets the keymaps (q, r, <CR>) for the dashboard buffer.
---@field private create_dashboard_buf fun(): string? Creates the dashboard buffer if it doesn't exist. Returns an error message if it fails.
---@field cleanup_dashboard_buf fun(): nil Clears content and highlights from the dashboard buffer.
---@field private set_dashboard_modifiable fun(value: boolean): nil Toggles the 'modifiable' option of the dashboard buffer.
---@field render_dashboard fun(): string? Re-renders the dashboard content (tasks, status, output). Returns an error if buffer creation fails.
---@field toggle_dashboard fun(): nil Toggles the visibility of the dashboard window (opens or closes).

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
---@field dashboard_config vim.api.keyset.win_config Configs to tasks dashboard.
---
--- Methods
---
---@field setup fun(opts: JustConfig?): nil Default plugin setup function
