local config = require("suda.config")

local M = {}

M.augroup = vim.api.nvim_create_augroup("SudaAutoElevate", { clear = true })

--- Clear the bottom commandline message completely
local function clear_cmdline()
	vim.cmd("redraw")
	vim.cmd("echo ''")
end

--- Check if file or its parent directory is writable by the current user
---@param filepath string
---@return boolean
function M.is_writable(filepath)
	if filepath == nil or filepath == "" then
		return true
	end
	filepath = vim.fn.expand(filepath)
	if vim.fn.filereadable(filepath) == 1 then
		return vim.fn.filewritable(filepath) == 1
	else
		local parent = vim.fs.dirname(filepath)
		if parent == "" or parent == "." then
			parent = vim.fn.getcwd()
		end
		return vim.fn.filewritable(parent) == 2
	end
end

--- Check if file is readable
---@param filepath string
---@return boolean
function M.is_readable(filepath)
	if filepath == nil or filepath == "" then
		return true
	end
	filepath = vim.fn.expand(filepath)
	return vim.fn.filereadable(filepath) == 1
end

--- Check if file exists on disk
---@param filepath string
---@return boolean
function M.exists(filepath)
	if filepath == nil or filepath == "" then
		return false
	end
	filepath = vim.fn.expand(filepath)
	return vim.uv.fs_stat(filepath) ~= nil
end

--- Ensure privilege elevation validity synchronously.
--- 1. Checks if sudo timestamp is already cached (sudo -n true). Takes ~2ms.
--- 2. If not, synchronously prompts for password in commandline using vim.fn.inputsecret.
--- Focus is guaranteed to remain 100% locked to the prompt without window blur issues.
---@return boolean
function M.ensure_auth()
	local opts = config.options
	if opts.cmd ~= "sudo" then
		return true
	end

	-- Check if sudo credentials are still cached in kernel/system
	local check = vim.system({ "sudo", "-n", "true" }, {}):wait()
	if check.code == 0 then
		return true
	end

	-- Synchronous password prompt in Neovim commandline
	local password = vim.fn.inputsecret(opts.prompt or "[sudo] password: ")
	clear_cmdline()

	if not password or password == "" then
		vim.notify("Sudo operation cancelled", vim.log.levels.WARN, { title = "suda.nvim" })
		return false
	end

	-- Validate password synchronously using sudo -S -p "" -v
	local auth = vim.system({ "sudo", "-S", "-p", "", "-v" }, {
		stdin = password .. "\n",
	}):wait()

	if auth.code == 0 then
		return true
	else
		local err = (auth.stderr and auth.stderr ~= "") and vim.trim(auth.stderr) or "Authentication failed"
		vim.notify("Sudo authentication failed:\n" .. err, vim.log.levels.ERROR, { title = "suda.nvim" })
		return false
	end
end

--- Extract formatted buffer content
---@param bufnr number
---@param line1? number
---@param line2? number
---@return string
local function get_buffer_content(bufnr, line1, line2)
	local start_line = (line1 and line1 > 0) and (line1 - 1) or 0
	local end_line = (line2 and line2 > 0) and line2 or -1
	local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
	local ff = vim.bo[bufnr].fileformat
	local eol = "\n"
	if ff == "dos" then
		eol = "\r\n"
	elseif ff == "mac" then
		eol = "\r"
	end

	local content = table.concat(lines, eol)
	if (#lines > 0 or content ~= "") and (vim.bo[bufnr].endofline or vim.bo[bufnr].fixendofline) then
		content = content .. eol
	end
	return content
end

--- Write buffer content using sudo
---@param filepath? string Target filepath (defaults to current buffer's file)
---@param bufnr? number Target buffer (defaults to current buffer)
---@param line1? number Start line for range writes
---@param line2? number End line for range writes
---@return boolean
function M.write(filepath, bufnr, line1, line2)
	local opts = config.options
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	filepath = (filepath and filepath ~= "") and filepath or vim.api.nvim_buf_get_name(bufnr)

	if filepath == "" then
		vim.notify("E32: No file name", vim.log.levels.ERROR, { title = "suda.nvim" })
		return false
	end

	filepath = vim.fn.fnamemodify(filepath, ":p")
	local content = get_buffer_content(bufnr, line1, line2)

	if not M.ensure_auth() then
		return false
	end

	-- Write directly using sudo tee synchronously
	local res = vim.system({ opts.cmd, "tee", filepath }, { stdin = content }):wait()
	if res.code == 0 then
		if vim.api.nvim_buf_is_valid(bufnr) then
			-- Only reset modified flag if entire buffer was written
			if not line1 or (line1 == 1 and line2 == vim.api.nvim_buf_line_count(bufnr)) then
				vim.bo[bufnr].modified = false
			end
			vim.bo[bufnr].readonly = false
			vim.b[bufnr].sudo_elevated = true
			-- Trigger BufWritePost for formatters, linter, git gutter
			vim.api.nvim_exec_autocmds("BufWritePost", { buffer = bufnr, modeline = false })
		end
		if not opts.silent then
			vim.notify(
				string.format('"%s" written with %s', filepath, opts.cmd),
				vim.log.levels.INFO,
				{ title = "suda.nvim" }
			)
		end
		-- Clear any leftover prompt on the commandline area
		vim.schedule(clear_cmdline)
		return true
	else
		local err = (res.stderr and res.stderr ~= "") and res.stderr or ("Exit code " .. tostring(res.code))
		vim.notify(
			string.format("Failed to write %s:\n%s", filepath, err),
			vim.log.levels.ERROR,
			{ title = "suda.nvim" }
		)
		return false
	end
end

--- Read file content using sudo
---@param filepath? string Target filepath (defaults to current buffer's file)
---@param bufnr? number Target buffer (defaults to current buffer)
---@return boolean
function M.read(filepath, bufnr)
	local opts = config.options
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	filepath = (filepath and filepath ~= "") and filepath or vim.api.nvim_buf_get_name(bufnr)

	if filepath == "" then
		vim.notify("E32: No file name", vim.log.levels.ERROR, { title = "suda.nvim" })
		return false
	end

	filepath = vim.fn.fnamemodify(filepath, ":p")

	if not M.ensure_auth() then
		return false
	end

	local res = vim.system({ opts.cmd, "cat", filepath }, {}):wait()
	if res.code == 0 then
		local lines = vim.split(res.stdout, "\n", { plain = true })
		if #lines > 0 and lines[#lines] == "" then
			table.remove(lines)
		end

		-- Detect CRLF
		local has_cr = false
		for i, line in ipairs(lines) do
			if line:sub(-1) == "\r" then
				lines[i] = line:sub(1, -2)
				has_cr = true
			end
		end

		if vim.api.nvim_buf_is_valid(bufnr) then
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
			vim.bo[bufnr].modified = false
			vim.bo[bufnr].readonly = false
			vim.bo[bufnr].fileformat = has_cr and "dos" or "unix"
			vim.b[bufnr].sudo_elevated = true

			-- Trigger filetype detection and buffer read event
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("filetype detect")
			end)
			vim.api.nvim_exec_autocmds("BufReadPost", { buffer = bufnr, modeline = true })

			-- Ensure this buffer can also be saved with sudo later
			M.attach_write_hook(bufnr, filepath)
		end

		if not opts.silent then
			vim.notify(
				string.format('"%s" read with %s', filepath, opts.cmd),
				vim.log.levels.INFO,
				{ title = "suda.nvim" }
			)
		end
		-- Clear any leftover prompt on the commandline area
		vim.schedule(clear_cmdline)
		return true
	else
		local err = (res.stderr and res.stderr ~= "") and res.stderr or ("Exit code " .. tostring(res.code))
		vim.notify(
			string.format("Failed to read %s:\n%s", filepath, err),
			vim.log.levels.ERROR,
			{ title = "suda.nvim" }
		)
		return false
	end
end

--- Attach write interception hook for buffers that lack write permissions
---@param bufnr number
---@param filepath string
function M.attach_write_hook(bufnr, filepath)
	if vim.b[bufnr].sudo_hooked then
		return
	end
	vim.b[bufnr].sudo_hooked = true
	-- Allow editing smoothly without readonly warnings
	vim.bo[bufnr].readonly = false

	-- Intercept BufWriteCmd on this specific buffer
	vim.api.nvim_create_autocmd("BufWriteCmd", {
		buffer = bufnr,
		group = M.augroup,
		callback = function(ev)
			local target = (ev.file and ev.file ~= "") and ev.file or filepath
			M.write(target, bufnr)
		end,
	})

	-- Buffer-local shortcut for <C-s> to save via sudo
	vim.keymap.set({ "i", "x", "n", "s" }, "<C-s>", function()
		M.write(filepath, bufnr)
	end, {
		buffer = bufnr,
		desc = "Save file with sudo",
	})
end

--- Intercept command line :w, :write, :wq, :x for sudo-hooked buffers
--- Rewrites them to include '!' so Vim bypasses disk read-only checks and delegates to BufWriteCmd
local function setup_cmdline_rewrite()
	vim.api.nvim_create_autocmd("CmdlineLeave", {
		group = M.augroup,
		callback = function()
			if vim.fn.getcmdtype() ~= ":" then
				return
			end
			local bufnr = vim.api.nvim_get_current_buf()
			if not vim.b[bufnr] or not vim.b[bufnr].sudo_hooked then
				return
			end

			local cmd = vim.fn.getcmdline()
			local trimmed = vim.trim(cmd)
			local first_word = trimmed:match("^(%S+)")
			if not first_word then
				return
			end

			local rest = trimmed:sub(#first_word + 1)
			local rewrite_map = {
				["w"] = "w!",
				["write"] = "write!",
				["wq"] = "wq!",
				["x"] = "x!",
				["up"] = "up!",
				["update"] = "update!",
			}

			if rewrite_map[first_word] then
				local lead_space = cmd:match("^(%s*)")
				vim.fn.setcmdline(lead_space .. rewrite_map[first_word] .. rest)
			end
		end,
	})
end

--- Scan buffer on open and configure auto elevation if needed
---@param bufnr number
local function check_and_hook_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	if vim.bo[bufnr].buftype ~= "" then
		return
	end

	local filepath = vim.api.nvim_buf_get_name(bufnr)
	if filepath == "" then
		return
	end

	local opts = config.options

	-- Check auto_read: unreadable file that exists on disk
	if opts.auto_read and M.exists(filepath) and not M.is_readable(filepath) then
		M.read(filepath, bufnr)
		return
	end

	-- Check auto_save: un-writable file or un-writable directory for new file
	if opts.auto_save and not M.is_writable(filepath) then
		M.attach_write_hook(bufnr, filepath)
	end
end

--- Register user commands
local function register_commands()
	local function cmd_write(args)
		local target = args.args ~= "" and args.args or nil
		local l1 = args.range == 2 and args.line1 or nil
		local l2 = args.range == 2 and args.line2 or nil
		M.write(target, nil, l1, l2)
	end

	local function cmd_read(args)
		local target = args.args ~= "" and args.args or nil
		M.read(target)
	end

	local function cmd_edit(args)
		local target = args.args ~= "" and args.args or nil
		if target then
			vim.cmd("edit " .. vim.fn.fnameescape(target))
			local bufnr = vim.api.nvim_get_current_buf()
			if not M.is_readable(target) then
				M.read(target, bufnr)
			end
		else
			M.read()
		end
	end

	for _, name in ipairs({ "SudaWrite", "SudoWrite" }) do
		vim.api.nvim_create_user_command(name, cmd_write, {
			nargs = "?",
			range = true,
			complete = "file",
			desc = "Write buffer to file with sudo",
		})
	end

	for _, name in ipairs({ "SudaRead", "SudoRead" }) do
		vim.api.nvim_create_user_command(name, cmd_read, {
			nargs = "?",
			complete = "file",
			desc = "Read file with sudo",
		})
	end

	for _, name in ipairs({ "SudaEdit", "SudoEdit" }) do
		vim.api.nvim_create_user_command(name, cmd_edit, {
			nargs = "?",
			complete = "file",
			desc = "Edit file with sudo",
		})
	end
end

--- Setup suda.nvim
---@param opts? SudaConfig
function M.setup(opts)
	config.setup(opts)
	local options = config.options

	-- Register user commands
	register_commands()

	-- Enable command line rewrite for native :w / :wq
	setup_cmdline_rewrite()

	-- Autocmds for auto-detecting files requiring sudo
	if options.auto_save or options.auto_read then
		vim.api.nvim_create_autocmd({ "BufReadPost", "BufNewFile" }, {
			group = M.augroup,
			callback = function(ev)
				check_and_hook_buffer(ev.buf)
			end,
		})

		-- Scan any already loaded buffers (e.g., opened via CLI args on startup)
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(bufnr) then
				check_and_hook_buffer(bufnr)
			end
		end
	end
end

return M
