local M = {}

-- Default configuration. opts passed to setup() are deep-merged over this.
local defaults = {
  auto_activate_venv = true, -- set vim.env.VIRTUAL_ENV and prepend venv bin dir to vim.env.PATH
  auto_restart_lsp = true, -- restart matching Python LSP clients so they pick up the new env
  lsp_client_names = { "pyright", "pylsp", "ruff", "ruff_lsp", "basedpyright", "python" },
  notify = true, -- gate ALL vim.notify calls on this
}

-- Merged config, populated by setup(). Module-local so the DirChanged autocmd reuses it.
local config

-- Guards autocmd registration so repeated setup() calls don't stack autocmds.
local did_setup = false

-- Capture the ORIGINAL environment ONCE at module load. Activation always rebuilds
-- PATH from this baseline, so switching projects replaces rather than stacks entries.
local original_path = vim.env.PATH
local original_virtual_env = vim.env.VIRTUAL_ENV

-- Cross-platform helpers. The venv layout differs on Windows (Scripts/python.exe)
-- vs POSIX (bin/python); these are used in EVERY detection branch.
local is_win = vim.fn.has("win32") == 1
local path_sep = is_win and ";" or ":"

local function python_subpath()
  return is_win and "/Scripts/python.exe" or "/bin/python"
end

local function bin_subdir()
  return is_win and "/Scripts" or "/bin"
end

-- Single fs_stat per path (the original code stat'd twice per check).
local function is_dir(p)
  local st = vim.uv.fs_stat(p)
  return st ~= nil and st.type == "directory"
end

local function is_absolute(p)
  return p:sub(1, 1) == "/" or (is_win and p:match("^%a:[\\/]") ~= nil)
end

-- A genuine venv (uv, poetry, std venv, virtualenv) always writes pyvenv.cfg at its
-- root. Requiring it rejects the trivial "bare script named python" code-execution
-- vector where a repo ships venv/bin/python without a real environment around it.
local function is_real_venv(venv_root)
  local st = vim.uv.fs_stat(venv_root .. "/pyvenv.cfg")
  return st ~= nil and st.type == "file"
end

-- Trust validation applied to every interpreter candidate before it is exposed or
-- activated. Canonicalizes the path, requires a real executable file, and on POSIX
-- rejects world-writable interpreters or ones not owned by the current user/root.
-- Returns the venv-LOCAL path (not the realpath) so site-packages resolution works.
local function validate_interpreter(path)
  local real = vim.uv.fs_realpath(path) -- rejects dangling symlinks
  if not real then
    return nil
  end
  local st = vim.uv.fs_stat(real)
  if not st or st.type ~= "file" then
    return nil
  end
  if vim.fn.executable(real) ~= 1 then
    return nil
  end
  if not is_win then
    local bit = require("bit")
    if bit.band(st.mode, 2) ~= 0 then -- other-write bit: world-writable
      return nil
    end
    local uid = vim.uv.getuid()
    if st.uid ~= uid and st.uid ~= 0 then -- allow current user or root (system python)
      return nil
    end
  end
  return path
end

-- Accept a venv root only if it is a directory carrying pyvenv.cfg AND its interpreter
-- passes trust validation. Returns the validated venv-local interpreter path or nil.
-- Folds the spec's per-branch "is_dir + is_real_venv + validate_interpreter" idiom into
-- one place so all four detection branches share identical acceptance semantics.
local function accept(venv_root)
  if not (is_dir(venv_root) and is_real_venv(venv_root)) then
    return nil
  end
  return validate_interpreter(venv_root .. python_subpath())
end

-- Detect a virtual environment for the current working directory.
-- Returns { python = <venv-local path>, venv_type = <string>, root = <venv root> } or nil.
-- Detection ALWAYS runs against the restored/original PATH (see run()), so a previously
-- activated venv's bin dir cannot hijack the poetry executable lookup below.
local function detect()
  local cwd = vim.fn.getcwd()

  -- 1. uv
  if vim.uv.fs_stat(cwd .. "/uv.lock") then
    -- Honor UV_PROJECT_ENVIRONMENT (absolute or cwd-relative), default to .venv.
    local env = os.getenv("UV_PROJECT_ENVIRONMENT")
    local venv_root = env and (is_absolute(env) and env or (cwd .. "/" .. env)) or (cwd .. "/.venv")
    local cand = accept(venv_root)
    if cand then
      return { python = cand, venv_type = "uv", root = venv_root }
    end
  end

  -- 2. poetry
  if vim.uv.fs_stat(cwd .. "/pyproject.toml") and vim.fn.executable("poetry") == 1 then
    local poetry = vim.fn.exepath("poetry")
    -- Spawn directly (no shell, argv form) with a 2s bound so a hung or interactive
    -- poetry cannot freeze startup, and there is no shell to mishandle "2>/dev/null".
    local res = vim.system({ poetry, "env", "info", "-p" }, { text = true }):wait(2000)
    if res and res.code == 0 and res.stdout and res.stdout ~= "" then
      local venv_root = vim.trim(res.stdout)
      local cand = accept(venv_root)
      if cand then
        return { python = cand, venv_type = "Poetry", root = venv_root }
      end
    end
  end

  -- 3. standard venv
  for _, pattern in ipairs({ "/.venv", "/venv" }) do
    local venv_root = cwd .. pattern
    local cand = accept(venv_root)
    if cand then
      return { python = cand, venv_type = "venv", root = venv_root }
    end
  end

  -- 4. virtualenvwrapper
  local workon = os.getenv("WORKON_HOME")
  if workon then
    local project_name = vim.fn.fnamemodify(cwd, ":t")
    local venv_root = workon .. "/" .. project_name
    local cand = accept(venv_root)
    if cand then
      return { python = cand, venv_type = "virtualenvwrapper", root = venv_root }
    end
  end

  return nil
end

-- Public, backward-compatible entry point. Returns (python_path, venv_type) or nil.
function M.find_venv_python()
  local r = detect()
  if r then
    return r.python, r.venv_type
  end
  return nil
end

-- Activate by rebuilding PATH from the original baseline (never the current PATH),
-- so repeated activation across project switches replaces rather than stacks entries.
local function activate(venv_root)
  vim.env.VIRTUAL_ENV = venv_root
  vim.env.PATH = (venv_root .. bin_subdir()) .. path_sep .. (original_path or "")
end

-- Restore the original environment captured at module load.
local function deactivate()
  vim.env.PATH = original_path
  vim.env.VIRTUAL_ENV = original_virtual_env
end

-- Return the currently-running LSP clients whose name is in cfg.lsp_client_names.
-- Used both to gate the restart (only restart when at least one matches) and to drive
-- it, so the name-set is built once with no duplication.
local function matching_clients(cfg)
  local get = vim.lsp.get_clients or vim.lsp.get_active_clients -- get_clients is 0.10+
  local names = {}
  for _, n in ipairs(cfg.lsp_client_names) do
    names[n] = true
  end
  local matched = {}
  for _, client in ipairs(get()) do
    if names[client.name] then
      matched[#matched + 1] = client
    end
  end
  return matched
end

-- Stop the given Python LSP clients, then re-trigger FileType so lspconfig-style
-- setups relaunch them with the new VIRTUAL_ENV/PATH inherited.
local function restart_lsp(clients)
  local bufs = {}
  for _, client in ipairs(clients) do
    for _, b in ipairs(vim.lsp.get_buffers_by_client_id(client.id)) do
      bufs[b] = true
    end
    vim.lsp.stop_client(client.id)
  end
  -- Give clients time to fully stop before re-triggering attach.
  vim.defer_fn(function()
    for b in pairs(bufs) do
      if vim.api.nvim_buf_is_valid(b) then
        vim.api.nvim_exec_autocmds("FileType", { buffer = b, modeline = false })
      end
    end
  end, 500)
end

-- Orchestrate a single detection + activation cycle for the current directory.
local function run()
  -- When activating, restore the clean baseline first so detection (incl. the poetry
  -- lookup) sees the original PATH and activation stacks off the original, not a stale
  -- venv. When auto_activate_venv is off we never touch the environment at all.
  if config.auto_activate_venv then
    deactivate()
  end
  local r = detect()
  if r then
    vim.g.venv_detector_python_path = r.python
    if config.auto_activate_venv then
      activate(r.root)
    end
    if config.auto_restart_lsp then
      local clients = matching_clients(config)
      if #clients > 0 then
        restart_lsp(clients)
      end
    end
    if config.notify then
      vim.notify(
        "Activated " .. r.venv_type .. " venv: " .. vim.fn.fnamemodify(r.python, ":~"),
        vim.log.levels.INFO,
        { title = "Venv Detector" }
      )
    end
  else
    vim.g.venv_detector_python_path = nil
  end
end

function M.setup(opts)
  -- Shallow merge: a user-provided lsp_client_names fully REPLACES the default list
  -- (deep-extend would index-merge the arrays and leak defaults the user wanted gone).
  config = vim.tbl_extend("force", defaults, opts or {})
  run() -- detect for the current dir immediately
  if not did_setup then
    did_setup = true
    local grp = vim.api.nvim_create_augroup("VenvDetector", { clear = true })
    vim.api.nvim_create_autocmd("DirChanged", {
      group = grp,
      callback = function()
        run()
      end,
    })
  end
end

return M