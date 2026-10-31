# suda.nvim

[English](README.md) | [中文](README_zh.md)

Transparent privilege elevation for Neovim without virtual URI hacks.

Unlike `suda.vim`, `suda.nvim` preserves the original file path instead of prefixing `suda://`, ensuring that LSP servers, Treesitter, formatters, and diagnostics continue to function normally.

## Features

- **Zero-URI overhead**: Buffers keep their actual paths (`/etc/hosts`).
- **Native `:w` and `:wq`**: Intercepts writes on protected files automatically without requiring special commands.
- **Synchronous locked-in password prompt**: Direct password input in the command-line without floating window focus loss.
- **Credential caching**: Reuses cached `sudo` credentials, avoiding repeated password prompts.
- **Safe write**: Streams content via `sudo tee`, preserving file modes, ownership, and symlinks.

## Requirements

- Neovim >= 0.10
- `sudo` (or `doas`)

## Installation

### lazy.nvim

```lua
{
  "LongYinStudio/suda.nvim",
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "SudaWrite", "SudaRead", "SudaEdit", "SudoWrite", "SudoRead", "SudoEdit" },
  opts = {},
}
```

## Configuration

Default options:

```lua
require("suda").setup({
  -- Command used for privilege elevation
  cmd = "sudo",

  -- Automatically elevate on :w for read-only / protected files
  auto_save = true,

  -- Automatically elevate when opening unreadable files (e.g. /etc/shadow)
  auto_read = true,

  -- Password prompt string
  prompt = "[sudo] password: ",

  -- Suppress write/read notifications
  silent = false,
})
```

## Commands

- `:SudaWrite [file]` (alias `:SudoWrite`): Write buffer (or range) with sudo.
- `:SudaRead [file]` (alias `:SudoRead`): Read file into buffer with sudo.
- `:SudaEdit <file>` (alias `:SudoEdit`): Open and edit file with sudo.

Supports range writes:
```vim
:'<,'>SudaWrite
```

## License

MIT
