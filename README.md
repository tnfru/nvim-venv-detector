# nvim-venv-detector

A lightweight Neovim plugin that automatically detects and configures the Python virtual environment for your projects.

## Why?

As a Software and AI Engineer, you frequently switch between projects, each with its own Python virtual environment. Manually updating your Neovim configuration to point to the correct Python executable for tools like `basedpyright` or `ruff` is tedious and error-prone.

This plugin solves that problem. It runs automatically when you launch Neovim and detects the project's virtual environment, setting the Python path for you. No more manual configuration.

## Features

- Zero-configuration needed after installation.
- Detects environments from **uv**, **Poetry**, and standard **venv**.
- Lightweight and fast, with no impact on startup time.
- Sets `vim.g.python3_host_prog` for easy integration with other plugins and LSP clients.

## Detection Order

The plugin searches for a virtual environment in the current working directory in the following order:

1.  **uv**: Checks for a `uv.lock` file and a corresponding `.venv` directory.
2.  **Poetry**: Detects the environment managed by Poetry via `poetry env info -p`.
3.  **Standard Virtual Environments**: Looks for common `.venv` or `venv` directories.
4.  **Virtualenvwrapper**: Checks for environments in the `$WORKON_HOME` directory.

## Installation

Choose your favorite plugin manager and add the following line.

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
-- lua/plugins/venv.lua
return {
  "tnfru/nvim-venv-detector",
  lazy = false,
}
```

### [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "tnfru/nvim-venv-detector",
}
```

### [vim-plug](https://github.com/junegunn/vim-plug)

```vim
Plug 'tnfru/nvim-venv-detector'
```

The plugin's `setup` function is called automatically, so no extra configuration is required.

## Usage with LSP

Once installed, `nvim-venv-detector` sets the `vim.g.python3_host_prog` variable. You can use this variable in your LSP configurations to ensure they use the project's virtual environment.

Here is an example for `nvim-lspconfig` and the `basedpyright` language server and `ruff` linter:

```lua
-- lua/configs/lspconfig.lua
local lspconfig = require("lspconfig")

lspconfig.basedpyright.setup {
  settings = {
    python = {
      pythonPath = vim.g.python3_host_prog,
    },
  },
}

lspconfig.ruff.setup {
  settings = {
    python = {
      pythonPath = vim.g.python3_host_prog,
    },
  },
}
```

And that's it! The correct Python interpreter will now be used automatically for linting, formatting, and type-checking in all your projects.

## Contributing

Feel free to open an issue or submit a pull request if you have suggestions for improvements or find any bugs.

## License

MIT
