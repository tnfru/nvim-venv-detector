-- lua/venv_detector/init.lua (Final Clean Version)
local M = {}

function M.find_venv_python()
  local cwd = vim.fn.getcwd()
  local venv_dir
  local python_path_to_check

  local function check_python_path(path_str)
    if vim.fn.executable(path_str) == 1 then
      return path_str
    end
    return nil
  end

  -- 1. UV check
  if vim.uv.fs_stat(cwd .. "/uv.lock") then
    venv_dir = cwd .. "/.venv"
    if vim.uv.fs_stat(venv_dir) and vim.uv.fs_stat(venv_dir).type == "directory" then
      python_path_to_check = venv_dir .. "/bin/python"
      local found_path = check_python_path(python_path_to_check)
      if found_path then
        return found_path
      end
    end
  end

  -- 2. Poetry check
  if vim.uv.fs_stat(cwd .. "/pyproject.toml") then
    local poetry_venv_cmd = "poetry env info -p 2>/dev/null"
    local poetry_venv_path_str = vim.fn.system(poetry_venv_cmd):gsub("%s+$", "")
    if
        poetry_venv_path_str ~= ""
        and vim.uv.fs_stat(poetry_venv_path_str)
        and vim.uv.fs_stat(poetry_venv_path_str).type == "directory"
    then
      python_path_to_check = poetry_venv_path_str .. "/bin/python"
      local found_path = check_python_path(python_path_to_check)
      if found_path then
        return found_path
      end
    end
  end

  -- 3. Standard .venv / venv check
  local venv_patterns = { "/.venv", "/venv" }
  for _, pattern in ipairs(venv_patterns) do
    venv_dir = cwd .. pattern
    if vim.uv.fs_stat(venv_dir) and vim.uv.fs_stat(venv_dir).type == "directory" then
      if vim.fn.has("win32") == 1 then
        python_path_to_check = venv_dir .. "/Scripts/python.exe"
      else
        python_path_to_check = venv_dir .. "/bin/python"
      end
      local found_path = check_python_path(python_path_to_check)
      if found_path then
        return found_path
      end
    end
  end

  -- 4. Virtualenvwrapper
  local venv_wrapper = os.getenv("WORKON_HOME")
  if venv_wrapper then
    local project_name = vim.fn.fnamemodify(cwd, ":t")
    local wrapper_path_dir = venv_wrapper .. "/" .. project_name
    if vim.uv.fs_stat(wrapper_path_dir) and vim.uv.fs_stat(wrapper_path_dir).type == "directory" then
      python_path_to_check = wrapper_path_dir .. "/bin/python"
      local found_path = check_python_path(python_path_to_check)
      if found_path then
        return found_path
      end
    end
  end

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
    -- Optional: You can uncomment this if you want a notification when no venv is found.
    -- vim.notify(
    --   "No local venv found. Using system Python.",
    --   vim.log.levels.DEBUG, -- Use DEBUG to make it less intrusive
    --   { title = "Venv Detector" }
    -- )
  end
end

return M

