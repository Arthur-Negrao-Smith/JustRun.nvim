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

--- Represents a result/status of a runtime task instance.
---@alias JustTaskStatus "success" | "fail" | "running"

---@class JustState JustRun plugin global state
---
--- ATTRIBUTES
---
---@field private dashboard_buf integer? Buffer of the dashboard.
---@field private dashboard_win integer? Window of the dashboard.
---@field private dashboard_timer userdata? Timer to periodically update dashboard.
---@field last_task string? Last task executed.
---@field private loaded_tasks table<string, JustTaskState> All loaded tasks.
---
--- STATE MANAGEMENT METHODS
---
---@field is_running fun(task_name: string): boolean Checks if a task is currently running.
---@field is_loaded fun(task_name: string): boolean Checks if a task is loaded.
---@field private load_task fun(task_name: string, task: JustRunnable) Loads a task into memory (Internal).
---@field unload_task fun(task_name: string) Removes task from memory and clears associated buffers.
---@field active_task fun(task_name: string, task: JustRunnable) Loads/Reloads a task and sets its status to 'running'.
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
---@field get_dashboard_timer fun(): userdata? Returns the dashboard timer.
---
--- SETTERS
---
--- @field set_dashboard_buf fun(buf: integer?): nil Set the tasks dashboard buffer.
--- @field set_dashboard_win fun(win: integer?): nil Set the tasks dashboard window.
--- @field set_dashboard_timer fun(timer: userdata): nil Set the dashboard timer.
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
---@field private handle_task fun(task_data: JustRunnable, all_tasks: JustTasksTable, depth: integer): (string, string?) Recursively resolves command string.
---@field private start_job fun(cmd: string, task: JustTask, task_name: string, should_exit: boolean, buf: integer): nil Starts the job.

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
---@field create_task_win fun(task_name: string): (integer?, string?) Opens a floating window for a specific task's buffer. Returns window ID or error.
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
-- ======= UTILS =============
-- ============================

---@class JustUtils Helper functions and system utilities.
---@field get_sep fun(): string Get the default separator (e.g. " && ").
---@field concat_with_sep fun(t: string[], sep: string?): string Join a list of strings with the separator.
---@field is_windows boolean True if running on Windows.
---@field is_powershell fun(): boolean True if the shell is PowerShell/pwsh.
---@field replace_placeholders fun(cmd: string): string Replaces ${file}, ${cwd}, etc.
---@field process_cmd fun(cmd: string): string Wrapper to process a command string.
---@field load_tasks fun(): (JustTasksTable, string?) Load tasks from the config file.
---@field ANSI_COLORS table<string, string> ANSI escape codes for terminal colors.

-- ============================
-- ====== CONFIGURATION =======
-- ============================

---@class JustTerminalOpts : vim.api.keyset.win_config
---@field max_width integer? Maximum width limit for the floating window. Default: 80% of screen.
---@field max_height integer? Maximum height limit for the floating window. Default: 80% of screen.

---@class JustDashboardOpts
---PLUGIN SPECIFIC
---@field width integer? Width of the dashboard window. Default: 40.
---@field refresh_interval integer? Auto-refresh interval in ms. Default: 1000.
---
---WINDOW OPTIONS (vim.opt_local)
---@field number boolean? Show line numbers. Default: false.
---@field relativenumber boolean? Show relative line numbers. Default: false.
---@field cursorline boolean? Highlight the screen line of the cursor. Default: true.
---@field signcolumn string? Show sign column ("auto", "no", "yes"). Default: "no".
---@field foldcolumn string? Show fold column. Default: "0".
---@field wrap boolean? Wrap long lines. Default: false.
---@field spell boolean? Enable spell checking. Default: false.
---@field list boolean? Show hidden characters. Default: false.
---@field winfixwidth boolean? Keep window width when resizing others. Default: true.

---@class JustConfig JustRun custom table configs.
---@field filename string? Default file to load task definitions. Default: .justrun.lua.
---@field filetype JustTasksTable? Default table to run filetypes when :JustRunFile is used without arguments.
---@field show_filetype_tasks boolean? Show the others filetype taks in :JustRunFind. Show only the current filetype task if false. Default: false.
---@field default_task string? Task to run when :JustRun is used without arguments. Default: "default".
---@field cwd string? Default woriking directory. This option can be overridden by the "cwd" field in task definition. Default: ".".
---@field force_run boolean? If arguments are missing, run default task, if is not found, run the first available task. Default: false.
---@field exit_on_success boolean? Close the terminal if the task succeeds. This option can be overwritten in the task body. Default: false.
---@field default_sep string? Default separator to join tasks commands. This option can be overwritten in the task body. Default: "&&".
---@field max_depth integer? Maximum recursion depth for nested tasks to prevent infinity loops. Use -1 to disable the limit (caution). Default: 20.
---@field terminal_opts vim.api.keyset.win_config Task floating terminals options.
---@field dashboard_opts JustDashboardOpts Tasks dashboard options.
---
--- Methods
---
---@field setup fun(opts: JustConfig?): nil Default plugin setup function.
---@field get_cleaned_dashboard_opts fun(): table Get the cleaned dashboard options.
---@field get_cleaned_terminal_opts fun(): vim.api.keyset.win_config Get the cleaned task terminal options.

-- ============================
-- ===== MAIN MODULE (API) ====
-- ============================

---@class JustRun Public API for the plugin.
---@field setup fun(opts: JustConfig?): nil Setup the plugin.
---@field load_tasks fun(): (JustTasksTable, string?) Load tasks helper.
---@field run fun(task_name: string?): nil Run a task.
---@field run_file fun(filename: string?): nil Run a file based on filetype.
---@field run_last fun(): nil Re-run the last task.
---@field run_under_cursor fun(): nil Run the task defined under cursor in config file.
---@field toggle_dashboard fun(): nil Open/Close the dashboard.
---@field find fun(): nil Open the task selector.
---@field open_task_terminal fun(task_name: string, enter: boolean?, force: boolean?): nil Open task terminal.
---@field close_task_terminal fun(task_name: string): nil Close task terminal.
---@field toggle_task_terminal fun(task_name: string, enter: boolean?, force: boolean?): nil Toggle task terminal.
---@field create_tasks fun(tasks: JustTasksTable): JustTasksTable Helper for autocompletion.
