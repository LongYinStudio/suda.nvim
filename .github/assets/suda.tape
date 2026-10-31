# vhs 录制脚本
Output suda.gif

Set FontSize 16
Set Width 1000
Set Height 450
Set Padding 20
Set Theme "Catppuccin Mocha"

Type "nvim /etc/hostname"
Enter
Sleep 1s

Type "Go# suda.nvim transparent save"
Escape
Sleep 1s

Type ":w"
Enter
Sleep 1s

# 密码
Type "password"
Enter
Sleep 3s
