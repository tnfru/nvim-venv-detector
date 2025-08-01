# nvim-venv-detector

### 🐍 Automatic Python Virtual Environment Detection for Neovim

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Neovim >= 0.9.0](https://img.shields.io/badge/Neovim-≥%200.9.0-blueviolet.svg)](https://github.com/neovim/neovim)

Stop manually configuring Python virtual environments in Neovim. `nvim-venv-detector` is a lightweight, zero-config plugin that automatically finds and activates the correct virtual environment for your projects.

## ✨ Features

- 🚀 **Zero-Config & Automatic**: Runs on startup without needing any configuration.
- 🐍 **Broad Support**: Detects virtual environments from **uv**, **Poetry**, **standard venv**, and **virtualenvwrapper**.
- ⚡️ **Fast & Lightweight**: Written in pure Lua with a minimal codebase. It has no impact on your startup time.
- 🔄 **Full Environment Activation**: Automatically sets `VIRTUAL_ENV` and `PATH` environment variables, just like `source .venv/bin/activate`.
- 🛠️ **Smart LSP Integration**: Automatically restarts Python LSP clients to pick up the new environment.
- ⚙️ **Configurable**: Fine-tune behavior with optional configuration settings.
- 🛠️ **Backward Compatible**: Still exposes the detected Python path to `vim.g.venv_detector_python_path` for manual LSP configuration.

## Demo

[https://github.com/user-attachments/assets/9eda0dda-cd3b-406d-aa99-b9d4febe3722](https://github.com/user-attachments/assets/9eda0dda-cd3b-406d-aa99-b9d4febe3722)

_<p align="center">nvim-venv-detector automatically activates the project's UV environment.</p>_

## 💡 Philosophy

As a software engineer, you jump between multiple projects a day. Your editor should adapt to your project, not the other way around. Manually setting the Python path for your LSP, linter, and formatters is a tedious distraction that breaks your flow.

This plugin is built on a simple "fire-and-forget" principle: install it, and it just works. It silently scans your project on startup, finds the right `python` executable, and configures Neovim for you.

## 📦 Installation

Install the plugin with your favorite package manager.

### [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

This is the recommended setup. Using `event = "VimEnter"` ensures the plugin loads just after startup, preventing any delay.

```lua
-- lua/plugins/venv.lua
return {
  "tnfru/nvim-venv-detector",
  event = "VimEnter",
  config = function()
    require("venv_detector").setup()
  end,
}
```

<details>
<summary>Other Plugin Managers</summary>

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "tnfru/nvim-venv-detector",
  config = function()
    require("venv_detector").setup()
  end,
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'tnfru/nvim-venv-detector'

" Call setup in your init.lua or via a lua heredoc
lua << EOF
require("venv_detector").setup()
EOF
```

</details>

## ⚙️ Configuration

The plugin works out of the box with zero configuration, but you can customize its behavior:

```lua
require("venv_detector").setup({
  auto_activate_venv = true,     -- Set VIRTUAL_ENV and PATH automatically (default: true)
  auto_restart_lsp = true,       -- Restart Python LSP clients automatically (default: true)
  lsp_client_names = {           -- LSP client names to restart (default list includes common Python LSPs)
    "pyright",
    "pylsp", 
    "ruff",
    "ruff_lsp",
    "basedpyright",
    "python"
  },
  notify = true                  -- Show notifications (default: true)
})
```

## 🛠️ Usage with LSP & Tooling

### Automatic Mode (Recommended)

By default, the plugin automatically:
1. **Activates the virtual environment** by setting `VIRTUAL_ENV` and `PATH` environment variables
2. **Restarts Python LSP clients** to pick up the new environment
3. **Resolves "unknown module" errors** for packages like `torch`, `numpy`, etc.

No additional configuration needed! Your LSP will automatically detect packages installed in the virtual environment.

### Manual LSP Configuration (Legacy)

If you prefer manual control or need to integrate with custom LSP setups, the plugin still sets `vim.g.venv_detector_python_path`:

```lua
-- lua/configs/lspconfig.lua
local lspconfig = require("lspconfig")

-- For basedpyright, pyright, etc.
lspconfig.basedpyright.setup {
  settings = {
    python = {
      pythonPath = vim.g.venv_detector_python_path,
    },
  },
}

-- For ruff
lspconfig.ruff.setup {
  cmd = { vim.g.venv_detector_python_path, "-m", "ruff", "server", "--preview" },
  init_options = {
    settings = {
      interpreter = { vim.g.venv_detector_python_path },
    },
  },
}
```

To use manual mode only, disable automatic activation:

```lua
require("venv_detector").setup({
  auto_activate_venv = false,  -- Only detect, don't activate
  auto_restart_lsp = false     -- Don't restart LSP clients
})
```

## 🔬 Detection Logic

The plugin searches for a virtual environment in the current project directory using the following order of priority:

1.  **uv**: Checks for a `uv.lock` file and a corresponding `.venv` directory.
2.  **Poetry**: Runs `poetry env info -p` to find the environment path managed by Poetry.
3.  **Standard Virtual Environments**: Looks for common `.venv` or `venv` directories. It checks for both `bin/python` (Linux/macOS) and `Scripts/python.exe` (Windows).
4.  **Virtualenvwrapper**: Checks for an environment in the `$WORKON_HOME` directory that matches the project's folder name.

If a valid Python executable is found, it is set, and a notification is shown. If not, the plugin does nothing and falls back to your global Python configuration.

## 🙏 Contributing

This project is open to contributions! Feel free to open an issue or submit a pull request if you have suggestions for improvements, find a bug, or want to add support for another environment manager.

## 📄 License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
