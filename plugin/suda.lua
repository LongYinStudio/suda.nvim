-- Auto-load suda.nvim commands when added to runtimepath
if vim.g.loaded_suda == 1 then
	return
end
vim.g.loaded_suda = 1

-- Load suda defaults
require("suda").setup()
