local M = {}
local health = vim.health or require("health")

function M.check()
	health.start("suda.nvim")

	-- 1. Check Neovim version
	if vim.fn.has("nvim-0.10") == 1 then
		health.ok("Neovim version >= 0.10 (vim.system is supported)")
	else
		health.error("Neovim version < 0.10. suda.nvim requires Neovim 0.10 or later.")
	end

	-- 2. Check elevation executable
	local config = require("suda.config").options
	local cmd = config.cmd or "sudo"
	if vim.fn.executable(cmd) == 1 then
		health.ok(string.format("Elevation command '%s' is executable", cmd))
	else
		health.error(string.format("Elevation command '%s' not found in PATH", cmd))
	end

	-- 3. Check sudo cache status
	if cmd == "sudo" then
		local res = vim.system({ "sudo", "-n", "true" }, {}):wait()
		if res.code == 0 then
			health.ok("sudo credentials currently cached (non-interactive sudo is active)")
		else
			health.info("sudo credentials not currently cached (password will be prompted when needed)")
		end
	end
end

return M
