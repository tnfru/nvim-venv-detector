-- Self-contained test runner for nvim-venv-detector.
-- Run with:  nvim --headless --noplugin -u NONE -l tests/run.lua
-- Exits non-zero if any assertion fails. No external deps (no plenary/busted).

local repo = vim.fn.getcwd()
vim.opt.runtimepath:append(repo)

local failures = 0
local total = 0

local function check(name, ok, detail)
  total = total + 1
  if ok then
    io.write("  PASS  " .. name .. "\n")
  else
    failures = failures + 1
    io.write("  FAIL  " .. name .. (detail and ("  -> " .. tostring(detail)) or "") .. "\n")
  end
end

-- Build a fake venv at <root>: optionally with pyvenv.cfg and an executable bin/python.
-- mode is the octal permission for the python file (default 0o755).
local function make_venv(root, opts)
  opts = opts or {}
  local bindir = root .. "/bin"
  vim.fn.mkdir(bindir, "p")
  if opts.pyvenv ~= false then
    local f = io.open(root .. "/pyvenv.cfg", "w")
    f:write("home = /usr/bin\nversion = 3.12.0\n")
    f:close()
  end
  if opts.python ~= false then
    local py = bindir .. "/python"
    local f = io.open(py, "w")
    f:write("#!/bin/sh\necho fake\n")
    f:close()
    vim.uv.fs_chmod(py, opts.mode or tonumber("755", 8))
  end
  return root
end

local function fresh_module()
  package.loaded["venv_detector"] = nil
  return require("venv_detector")
end

local function tmpdir()
  local d = vim.fn.tempname()
  vim.fn.mkdir(d, "p")
  return d
end

local SEP = "/"

-- ---------------------------------------------------------------------------
-- Detection: each manager returns the venv-local python and the right label
-- ---------------------------------------------------------------------------

-- uv: uv.lock + .venv (with pyvenv.cfg)
do
  local proj = tmpdir()
  io.open(proj .. "/uv.lock", "w"):close()
  make_venv(proj .. "/.venv")
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  local M = fresh_module()
  local path, kind = M.find_venv_python()
  check("uv: detects .venv python", path == proj .. "/.venv/bin/python", path)
  check("uv: labels as uv", kind == "uv", kind)
end

-- uv honoring UV_PROJECT_ENVIRONMENT (relative path), no default .venv present
do
  local proj = tmpdir()
  io.open(proj .. "/uv.lock", "w"):close()
  make_venv(proj .. "/.custom-env")
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  vim.env.UV_PROJECT_ENVIRONMENT = ".custom-env"
  local M = fresh_module()
  local path, kind = M.find_venv_python()
  check("uv: honors UV_PROJECT_ENVIRONMENT", path == proj .. "/.custom-env/bin/python", path)
  check("uv: UV_PROJECT_ENVIRONMENT labeled uv", kind == "uv", kind)
  vim.env.UV_PROJECT_ENVIRONMENT = nil
end

-- standard .venv (no uv.lock)
do
  local proj = tmpdir()
  make_venv(proj .. "/.venv")
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  local M = fresh_module()
  local path, kind = M.find_venv_python()
  check("venv: detects .venv python", path == proj .. "/.venv/bin/python", path)
  check("venv: labels as venv", kind == "venv", kind)
end

-- standard venv/ (bare 'venv' dir)
do
  local proj = tmpdir()
  make_venv(proj .. "/venv")
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  local M = fresh_module()
  local path = M.find_venv_python()
  check("venv: detects bare 'venv' dir", path == proj .. "/venv/bin/python", path)
end

-- virtualenvwrapper via WORKON_HOME (env named after project dir)
do
  local workon = tmpdir()
  local proj = tmpdir() .. "/myproject"
  vim.fn.mkdir(proj, "p")
  make_venv(workon .. "/myproject")
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  vim.env.WORKON_HOME = workon
  local M = fresh_module()
  local path, kind = M.find_venv_python()
  check("virtualenvwrapper: detects WORKON_HOME env", path == workon .. "/myproject/bin/python", path)
  check("virtualenvwrapper: labeled", kind == "virtualenvwrapper", kind)
  vim.env.WORKON_HOME = nil
end

-- ---------------------------------------------------------------------------
-- Security / trust validation
-- ---------------------------------------------------------------------------

-- Reject a venv that lacks pyvenv.cfg (the "bare attacker script named python" vector)
do
  local proj = tmpdir()
  make_venv(proj .. "/.venv", { pyvenv = false })
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  local M = fresh_module()
  local path = M.find_venv_python()
  check("security: rejects venv without pyvenv.cfg", path == nil, path)
end

-- Reject a world-writable interpreter even if pyvenv.cfg is present
do
  local proj = tmpdir()
  make_venv(proj .. "/.venv", { mode = tonumber("777", 8) })
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  local M = fresh_module()
  local path = M.find_venv_python()
  check("security: rejects world-writable interpreter", path == nil, path)
end

-- No venv at all -> nil
do
  local proj = tmpdir()
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  local M = fresh_module()
  local path = M.find_venv_python()
  check("empty project: returns nil", path == nil, path)
end

-- ---------------------------------------------------------------------------
-- setup(): exposes vim.g, idempotency, re-detection on DirChanged
-- ---------------------------------------------------------------------------

-- setup() exposes vim.g.venv_detector_python_path and is idempotent
do
  local proj = tmpdir()
  make_venv(proj .. "/.venv")
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  vim.g.venv_detector_python_path = nil
  local M = fresh_module()
  M.setup({ notify = false, auto_restart_lsp = false, auto_activate_venv = false })
  check("setup: sets vim.g.venv_detector_python_path", vim.g.venv_detector_python_path == proj .. "/.venv/bin/python", vim.g.venv_detector_python_path)
  local ok = pcall(function() M.setup({ notify = false, auto_restart_lsp = false }) end)
  check("setup: idempotent (second call does not error)", ok)
end

-- Re-detection on DirChanged: switching projects updates the detected path (the HIGH fix)
do
  local empty = tmpdir()
  local proj = tmpdir()
  make_venv(proj .. "/.venv")
  vim.cmd("cd " .. vim.fn.fnameescape(empty))
  vim.g.venv_detector_python_path = nil
  local M = fresh_module()
  M.setup({ notify = false, auto_restart_lsp = false, auto_activate_venv = false })
  check("re-detect: no venv in starting dir", vim.g.venv_detector_python_path == nil, vim.g.venv_detector_python_path)
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  check("re-detect: picks up venv after :cd (DirChanged)", vim.g.venv_detector_python_path == proj .. "/.venv/bin/python", vim.g.venv_detector_python_path)
  vim.cmd("cd " .. vim.fn.fnameescape(empty))
  check("re-detect: clears venv after :cd to empty", vim.g.venv_detector_python_path == nil, vim.g.venv_detector_python_path)
end

-- ---------------------------------------------------------------------------
-- Activation: sets VIRTUAL_ENV / PATH, restores on switch, does not stack
-- ---------------------------------------------------------------------------
do
  local empty = tmpdir()
  local proj = tmpdir()
  make_venv(proj .. "/.venv")
  local orig_path = vim.env.PATH
  vim.cmd("cd " .. vim.fn.fnameescape(empty))
  local M = fresh_module()
  M.setup({ notify = false, auto_restart_lsp = false, auto_activate_venv = true })
  -- activate
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  check("activate: VIRTUAL_ENV set to venv root", vim.env.VIRTUAL_ENV == proj .. "/.venv", vim.env.VIRTUAL_ENV)
  check("activate: PATH prepends venv bin", (vim.env.PATH or ""):sub(1, #(proj .. "/.venv/bin")) == proj .. "/.venv/bin", vim.env.PATH)
  local path_after_first = vim.env.PATH
  -- switching away restores original PATH (no leftover venv bin)
  vim.cmd("cd " .. vim.fn.fnameescape(empty))
  check("deactivate: PATH restored on switch to non-venv dir", vim.env.PATH == orig_path, vim.env.PATH)
  -- re-activating the same project does not stack a second bin entry
  vim.cmd("cd " .. vim.fn.fnameescape(proj))
  check("activate: PATH does not stack across re-activation", vim.env.PATH == path_after_first, vim.env.PATH)
  vim.cmd("cd " .. vim.fn.fnameescape(empty))
end

-- auto_activate_venv=false must NOT touch the environment, even on DirChanged
do
  local empty = tmpdir()
  vim.cmd("cd " .. vim.fn.fnameescape(empty))
  local M = fresh_module()
  vim.env.VIRTUAL_ENV = "/sentinel/venv"
  M.setup({ notify = false, auto_restart_lsp = false, auto_activate_venv = false })
  vim.cmd("cd " .. vim.fn.fnameescape(tmpdir()))  -- triggers DirChanged
  check("auto_activate=false: VIRTUAL_ENV left untouched", vim.env.VIRTUAL_ENV == "/sentinel/venv", vim.env.VIRTUAL_ENV)
  vim.env.VIRTUAL_ENV = nil
end

-- ---------------------------------------------------------------------------
io.write(string.format("\n%d/%d passed, %d failed\n", total - failures, total, failures))
if failures > 0 then
  vim.cmd("cq")  -- exit non-zero
else
  vim.cmd("qa!")
end
