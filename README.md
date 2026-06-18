# nvim-venv-detector

### 🐍 Automatic Python Virtual Environment Detection for Neovim

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg?style=flat-square)](http://makeapullrequest.com)
[![Neovim >= 0.10.0](https://img.shields.io/badge/Neovim-≥%200.10.0-blueviolet.svg)](https://github.com/neovim/neovim)

Stop manually configuring Python virtual environments in Neovim. `nvim-venv-detector` is a lightweight, zero-config plugin that automatically finds and activates the correct virtual environment for your projects.

## ✨ Features

- 🚀 **Zero-Config & Automatic**: Runs on startup without needing any configuration.
- 🐍 **Broad Support**: Detects virtual environments from **uv**, **Poetry**, **standard venv**, and **virtualenvwrapper**.
- ⚡️ **Fast & Lightweight**: Pure Lua with a minimal codebase. Detection is just a few filesystem checks; the only subprocess is a timeout-bounded (2s) `poetry` lookup, and only in Poetry projects.
- 🔄 **Full Environment Activation**: Sets `VIRTUAL_ENV` and prepends the venv's `bin` directory to `PATH`, just like `source .venv/bin/activate`. Switching projects replaces the environment rather than stacking it.
- 🛠️ **Smart LSP Integration**: Restarts the configured Python LSP clients so they relaunch with the new environment.
- 🔁 **Re-detection on Directory Change**: Re-runs detection whenever you switch projects (`DirChanged`), not just once at startup.
- ⚙️ **Configurable**: Fine-tune behavior with optional configuration settings.
- 🔒 **Trust Validation**: Validates that a detected venv is genuine and that its interpreter is safe to run before activating it.
- 🛠️ **Backward Compatible**: Still exposes the detected Python path to `vim.g.venv_detector_python_path` for manual LSP configuration.

## Demo

[https://github.com/user-attachments/assets/9eda0dda-cd3b-406d-aa99-b9d4febe3722](https://github.com/user-attachments/assets/9eda0dda-cd3b-406d-aa99-b9d4febe3722)

_<p align="center">nvim-venv-detector automatically activates the project's UV environment.</p>_

## 💡 Philosophy

As a software engineer, you jump between multiple projects a day. Your editor should adapt to your project, not the other way around. Manually setting the Python path for your LSP, linter, and formatters is a tedious distraction that breaks your flow.

This plugin is built on a simple "fire-and-forget" principle: install it, and it just works. It scans your project on startup, finds the right `python` executable, and configures Neovim for you — and re-scans automatically whenever you change directories.

## ✅ Requirements

Neovim **>= 0.10.0**. The plugin uses `vim.uv`, `vim.system`, and `vim.lsp.get_clients`, which are only available on Neovim 0.10 and later.

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

The plugin works out of the box with zero configuration. The options below are merged over the defaults, so you only need to specify what you want to change (a provided `lsp_client_names` fully replaces the default list):

```lua
require("venv_detector").setup({
  -- Set VIRTUAL_ENV and prepend the venv's bin dir to PATH (default: true)
  auto_activate_venv = true,

  -- Restart matching Python LSP clients so they pick up the new env (default: true)
  auto_restart_lsp = true,

  -- LSP client names that should be restarted on activation (these are the defaults)
  lsp_client_names = {
    "pyright",
    "pylsp",
    "ruff",
    "ruff_lsp",
    "basedpyright",
    "python",
  },

  -- Gate ALL notifications on this flag (default: true)
  notify = true,
})
```

| Option | Default | Description |
| --- | --- | --- |
| `auto_activate_venv` | `true` | Sets `vim.env.VIRTUAL_ENV` and prepends the venv's `bin`/`Scripts` directory to `vim.env.PATH`. |
| `auto_restart_lsp` | `true` | Restarts the Python LSP clients named in `lsp_client_names` so they relaunch with the new environment. Only fires when at least one matching client is running. |
| `lsp_client_names` | `{ "pyright", "pylsp", "ruff", "ruff_lsp", "basedpyright", "python" }` | The LSP client names eligible for restart. |
| `notify` | `true` | When `false`, the plugin runs completely silently (no `vim.notify` calls). |

## 🛠️ Usage with LSP & Tooling

### Automatic Mode (Recommended)

By default, the plugin automatically:

1. **Activates the virtual environment** by setting `VIRTUAL_ENV` and prepending the venv's `bin` directory to `PATH`. The original environment is captured once at load, so switching between projects **replaces** the active venv rather than stacking `PATH` entries.
2. **Restarts the configured Python LSP clients**. It stops the matching clients and re-triggers the `FileType` event so `lspconfig`-style setups relaunch them, inheriting the new `VIRTUAL_ENV` and `PATH`.
3. **Resolves "unknown module" errors** for packages like `torch`, `numpy`, etc.

No additional configuration needed! Your LSP will automatically detect packages installed in the virtual environment.

### Re-detection

Detection runs immediately at `setup()` and re-runs on every `DirChanged` event. When you switch to a project with a different environment, the previous one is deactivated (the original `PATH`/`VIRTUAL_ENV` is restored) and the new one is activated. When you switch to a project with no detectable environment, the original environment is restored and `vim.g.venv_detector_python_path` is cleared.

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

> **Security note:** `vim.g.venv_detector_python_path` points at a project-local interpreter. The same trust caveat described in [Security / Trust](#-security--trust) applies: wiring it into your LSP for an untrusted repo can run that repo's interpreter.

To use manual mode only, disable automatic activation:

```lua
require("venv_detector").setup({
  auto_activate_venv = false,  -- Only detect, don't activate
  auto_restart_lsp = false,    -- Don't restart LSP clients
})
```

## 🔬 Detection Logic

The plugin searches for a virtual environment in the current working directory using the following order of priority:

1.  **uv**: If a `uv.lock` file is present, it looks for the project environment. It honors `UV_PROJECT_ENVIRONMENT` (absolute or cwd-relative) and falls back to `.venv`.
2.  **Poetry**: If a `pyproject.toml` is present and the `poetry` executable is on `PATH`, it runs `poetry env info -p` (spawned directly, argv form, with a 2-second timeout — no shell) to find the managed environment path.
3.  **Standard Virtual Environments**: Looks for common `.venv` or `venv` directories.
4.  **Virtualenvwrapper**: Checks for an environment under `$WORKON_HOME` that matches the project's folder name.

In every branch the interpreter is resolved cross-platform: `bin/python` on POSIX and `Scripts/python.exe` on Windows.

Detection always runs against the restored/original `PATH`, so a previously activated venv's `bin` directory cannot hijack the `poetry` executable lookup.

If a valid, trusted Python interpreter is found, it is set and a notification is shown (unless `notify = false`). If not, the plugin does nothing and falls back to your global Python configuration.

## 🔒 Security / Trust

Because this plugin can run a project-local Python interpreter through your LSP, it validates every candidate before exposing or activating it:

- **Real venv check**: The venv root must contain a `pyvenv.cfg` file. A genuine environment (uv, Poetry, std `venv`, virtualenv) always writes one. This rejects the trivial "bare script named `python`" code-execution vector, where a repo ships `venv/bin/python` without a real environment around it.
- **Canonicalization**: The interpreter path is resolved with `realpath`, rejecting dangling symlinks. It must be a real, executable file.
- **Ownership & permissions (POSIX)**: A world-writable interpreter is rejected, as is an interpreter not owned by the current user or root (system Python).

**Residual risk — read this.** These checks raise the bar, but they do not make opening arbitrary repositories safe. With `auto_activate_venv` enabled (the default), opening an untrusted repository can cause your LSP to launch that repository's project-local interpreter. A repository you do not trust can ship an environment whose interpreter still passes these checks.

If you open untrusted code, **disable `auto_activate_venv`** (and `auto_restart_lsp`), or simply do not open untrusted repositories. Treat a project's interpreter the way you would treat running its `Makefile`.

## 🙏 Contributing

This project is open to contributions! Feel free to open an issue or submit a pull request if you have suggestions for improvements, find a bug, or want to add support for another environment manager.

## 📄 License

This project is licensed under the **MIT License**. See the `LICENSE` file for details.
