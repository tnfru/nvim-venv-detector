# nvim-venv-detector

### 🐍 Automatic Python Virtual Environment Detection for Neovim

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Neovim >= 0.9.0](https://img.shields.io/badge/Neovim-≥%200.9.0-blueviolet.svg)](https://github.com/neovim/neovim)

Stop manually configuring Python virtual environments in Neovim. `nvim-venv-detector` is a lightweight, zero-config plugin that automatically finds and activates the correct virtual environment for your projects.

---

## 💡 Philosophy

As a software engineer, you jump between multiple projects a day. Your editor should adapt to your project, not the other way around. Manually setting the Python path for your LSP, linter, and formatters is a tedious distraction that breaks your flow.

This plugin is built on a simple "fire-and-forget" principle: install it, and it just works. It silently scans your project on startup, finds the right `python` executable, and configures Neovim for you.

## ✨ Features

* 🚀 **Zero-Config & Automatic**: Runs on startup without needing any configuration.
* 🐍 **Broad Support**: Detects virtual environments from **uv**, **Poetry**, **standard venv**, and **virtualenvwrapper**.
* ⚡️ **Fast & Lightweight**: Written in pure Lua with a minimal codebase. It has no impact on your startup time.
* 🛠️ **Simple Integration**: Exposes the detected Python path to `vim.g.python3_host_prog` for easy use with any LSP, linter, or formatter.

## Demo


https://github.com/user-attachments/assets/9eda0dda-cd3b-406d-aa99-b9d4febe3722

*<p align="center">nvim-venv-detector automatically activates the project's UV environment.</p>*

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

## 🛠️ Usage with LSP & Tooling

The plugin works by setting a single global variable: `vim.g.python3_host_prog`.

You can then reference this variable in your other plugin configurations to ensure they always use the project's isolated Python environment.

Here is a typical example for `nvim-lspconfig` with `basedpyright` and `ruff_lsp`:

```lua
-- lua/configs/lspconfig.lua
local lspconfig = require("lspconfig")

-- For basedpyright, pyright, etc.
lspconfig.basedpyright.setup {
  settings = {
    python = {
      pythonPath = vim.g.python3_host_prog,
    },
  },
}

-- For ruff-lsp
lspconfig.ruff_lsp.setup {
  init_options = {
    settings = {
      -- Tell ruff-lsp to use the detected interpreter
      interpreter = { vim.g.python3_host_prog },
    },
  },
}
```

That's it! Your entire Python toolchain will now use the correct interpreter for every project, every time.

## ⚙️ Configuration

The plugin is designed to be zero-config. However, you can pass options to the `setup()` function if needed.

For example, to ensure notifications from this plugin appear correctly with `nvim-notify`, you can declare it as a dependency. You could also disable the notifications entirely.

```lua
-- Using lazy.nvim
{
  "tnfru/nvim-venv-detector",
  event = "VimEnter",
  dependencies = {
    -- Recommended to ensure notifications are properly displayed
    "rcarriga/nvim-notify",
  },
  opts = {
    -- You can add options here in the future. For example:
    -- notifications = {
    --   enabled = true,
    -- },
  },
}
```
*(Note: You would need to update the `setup` function in `init.lua` to handle the `opts` table for this to work).*

## 🔬 Detection Logic

The plugin searches for a virtual environment in the current project directory using the following order of priority:

1.  **uv**: Checks for a `uv.lock` file and a corresponding `.venv` directory.
2.  **Poetry**: Runs `poetry env info -p` to find the environment path managed by Poetry.
3.  **Standard Virtual Environments**: Looks for common `.venv` or `venv` directories. It checks for both `bin/python` (Linux/macOS) and `Scripts/python.exe` (Windows).
4.  **Virtualenvwrapper**: Checks for an environment in the `$WORKON_HOME` directory that matches the project's folder name.

If a valid Python executable is found, it is set, and a notification is shown. If not, the plugin does nothing and falls back to your global Python configuration.

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

## 🙏 Contributing

This project is open to contributions! Feel free to open an issue or submit a pull request if you have suggestions for improvements, find a bug, or want to add support for another environment manager.

## 📄 License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
