# suda.nvim

[English](README.md) | [中文](README_zh.md)

适用于 Neovim 的无感 Sudo 提权读写插件。

与 `suda.vim` 不同，`suda.nvim` 完全保留原生的文件路径，不使用类似 `suda://` 的虚拟协议前缀，确保 LSP 服务器、Treesitter、代码格式化与诊断等工具 100% 正常工作。

![suda.nvim 演示](.github/assets/suda.gif)

## 特性

- **零 URI 污染**：缓冲区始终保持真实文件路径（如 `/etc/hosts`）。
- **原生 `:w` 与 `:wq`**：在只读受保护文件上直接保存，自动拦截提权，无需额外记忆特殊命令。
- **同步绝对锁焦**：命令行原生输入密码，绝无悬浮窗失焦或按键漏击到背景代码的问题。
- **系统凭据缓存**：利用系统 `sudo` 凭据缓存，15 分钟内再次保存仅需数毫秒，且无需重复输入密码。
- **安全无损写入**：通过 `sudo tee` 流式写入，保留原始文件的权限、所有者、inode 以及软链接目标。

## 环境要求

- Neovim >= 0.10
- `sudo`（或 `doas`）

## 安装

### lazy.nvim

```lua
{
  "LongYinStudio/suda.nvim",
  event = { "BufReadPre", "BufNewFile" },
  cmd = { "SudaWrite", "SudaRead", "SudaEdit", "SudoWrite", "SudoRead", "SudoEdit" },
  opts = {},
}
```

## 配置

默认配置：

```lua
require("suda").setup({
  -- 提权使用的命令
  cmd = "sudo",

  -- 遇到只读受保护文件执行 :w 时自动提权保存
  auto_save = true,

  -- 打开无读权限文件（如 /etc/shadow）时自动以提权方式读取
  auto_read = true,

  -- 密码提示符文本
  prompt = "[sudo] password: ",

  -- 是否静默（关闭保存/读取成功通知）
  silent = false,
})
```

## 命令

- `:SudaWrite [file]`（别名 `:SudoWrite`）：以 sudo 保存当前缓冲区（或选区内容）。
- `:SudaRead [file]`（别名 `:SudoRead`）：以 sudo 读取指定文件并载入到当前缓冲区。
- `:SudaEdit <file>`（别名 `:SudoEdit`）：以 sudo 权限打开并编辑文件。

支持可视模式行范围保存：
```vim
:'<,'>SudaWrite
```

## 许可证

MIT
