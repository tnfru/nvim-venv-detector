-- lua/venv_detector/init.lua
local M = {}

function M.find_venv_python()
  local cwd = vim.fn.getcwd()
  local venv_dir

  -- 1. Check for `uv` environment
  local uv_lockfile = io.open(cwd .. "/uv.lock", "r")
  if uv_lockfile then
    uv_lockfile:close()
    venv_dir = cwd .. "/.venv"
    if vim.fn.isdirectory(venv_dir) == 1 then
      local python_path = venv_dir .. "/bin/python"
      if vim.fn.executable(python_path) == 1 then
        return python_path
      end
    end
  end

  -- 2. Check for Poetry virtual environment
  local poetry_config = io.open(cwd .. "/pyproject.toml", "r")
  if poetry_config then
    poetry_config:close()
    local poetry_venv_cmd = "poetry env info -p 2>/dev/null"
    local poetry_venv = vim.fn.system(poetry_venv_cmd):gsub("%s+$", "")
    if poetry_venv ~= "" and vim.fn.isdirectory(poetry_venv) == 1 then
      local python_path = poetry_venv .. "/bin/python"
      if vim.fn.executable(python_path) == 1 then
        return python_path
      end
    end
  end

  -- 3. Check for other common virtual environment locations
  local venv_patterns = { "/.venv", "/venv" }
  for _, pattern in ipairs(venv_patterns) do
    venv_dir = cwd .. pattern
    if vim.fn.isdirectory(venv_dir) == 1 then
      local python_path
      if vim.fn.has("win32") == 1 then
        python_path = venv_dir .. "/Scripts/python.exe"
      else
        python_path = venv_dir .. "/bin/python"
      end
      if vim.fn.executable(python_path) == 1 then
        return python_path
      end
    end
  end

  -- 4. Check for virtualenvwrapper environments
  local venv_wrapper = os.getenv("WORKON_HOME")
  if venv_wrapper then
    local project_name = vim.fn.fnamemodify(cwd, ":t")
    local wrapper_path = venv_wrapper .. "/" .. project_name
    if vim.fn.isdirectory(wrapper_path) == 1 then
      local python_path = wrapper_path .. "/bin/python"
      if vim.fn.executable(python_path) == 1 then
        return python_path
      end
    end
  end

  -- Return nil as fallback
  return nil
end

function M.setup()
  local python_path = M.find_venv_python()
  if python_path then
    vim.g.python3_host_prog = python_path
    vim.notify(
      "venv detected: " .. vim.fn.fnamemodify(python_path, ":~"),
      vim.log.levels.INFO,
      { title = "Venv Detector" }
    )
  else
    -- This part is optional and commented out by default to reduce noise.
    -- vim.notify(
    --   "No local venv found. Using system Python.",
    --   vim.log.levels.DEBUG,
    --   { title = "Venv Detector" }
    -- )
  end
end

return M
