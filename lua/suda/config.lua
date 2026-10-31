local M = {}

---@class SudaConfig
---@field cmd? string The command to use for privilege elevation (default: "sudo")
---@field auto_save? boolean Automatically elevate on :w when file is read-only (default: true)
---@field auto_read? boolean Automatically read with sudo when opening unreadable files (default: true)
---@field prompt? string Password prompt text (default: "[sudo] password: ")
---@field silent? boolean Mute success notifications (default: false)
M.defaults = {
	cmd = "sudo",
	auto_save = true,
	auto_read = true,
	prompt = "[sudo] password: ",
	silent = false,
}

---@type SudaConfig
M.options = {}

--- Setup and merge user options
---@param opts? SudaConfig
---@return SudaConfig
function M.setup(opts)
	M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
	return M.options
end

return M
