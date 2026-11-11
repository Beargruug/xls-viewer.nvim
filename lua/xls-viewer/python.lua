-- Runs Python scripts without a shell. Arguments go through argv and bulk
-- data through stdin, so file paths never get interpolated into code.
local M = {}

local config = require("xls-viewer.config")

-- Exit code our scripts use when pandas/openpyxl is missing
M.EXIT_MISSING_MODULE = 3

-- Interpreter found to work (cached for the session)
M.resolved = nil

--- Interpreters to try, in order
---@return string[]
function M.candidates()
	local configured = config.config.python_cmd
	if configured and configured ~= "" then
		return { configured }
	end
	if M.resolved then
		return { M.resolved }
	end

	local list, seen = {}, {}
	local function add(p)
		if type(p) == "string" and p ~= "" and not seen[p] and vim.fn.executable(p) == 1 then
			seen[p] = true
			table.insert(list, p)
		end
	end
	add(vim.g.python3_host_prog and vim.fn.expand(vim.g.python3_host_prog))
	add(vim.fn.exepath("python3"))
	add("/usr/bin/python3")
	add("/opt/homebrew/bin/python3")
	add("/usr/local/bin/python3")
	add(vim.fn.exepath("python"))
	return list
end

--- Run one interpreter
---@param python string
---@param script string
---@param args string[]
---@param input string|nil stdin
---@param callback fun(code: number, stdout: string, stderr: string)
local function run_once(python, script, args, input, callback)
	local cmd = { python, "-c", script }
	vim.list_extend(cmd, args)

	if not config.config.async then
		local stdout = vim.fn.system(cmd, input)
		local code = vim.v.shell_error
		-- system() merges stderr into the output
		callback(code, code == 0 and stdout or "", code ~= 0 and stdout or "")
		return
	end

	local out, err = {}, {}
	local ok, job = pcall(vim.fn.jobstart, cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			out = data or {}
		end,
		on_stderr = function(_, data)
			err = data or {}
		end,
		on_exit = function(_, code)
			vim.schedule(function()
				callback(code, table.concat(out, "\n"), table.concat(err, "\n"))
			end)
		end,
	})
	if not ok or job <= 0 then
		callback(127, "", "Failed to start " .. python)
		return
	end
	if input then
		vim.fn.chansend(job, input)
	end
	vim.fn.chanclose(job, "stdin")
end

--- Run a Python script, trying interpreters until one has the needed modules
---@param script string Python source
---@param args string[] argv passed to the script
---@param input string|nil Data for stdin
---@param callback fun(stdout: string|nil, err: string|nil)
function M.run(script, args, input, callback)
	local candidates = M.candidates()
	if #candidates == 0 then
		callback(nil, "No python3 executable found. Set `python_cmd` in setup().")
		return
	end

	local errors = {}
	local function try(i)
		local python = candidates[i]
		run_once(python, script, args, input, function(code, stdout, stderr)
			if code == 0 then
				if not config.config.python_cmd then
					M.resolved = python
				end
				callback(stdout, nil)
				return
			end
			table.insert(errors, string.format("[%s] %s", python, vim.trim(stderr)))
			if code == M.EXIT_MISSING_MODULE and candidates[i + 1] then
				try(i + 1)
				return
			end
			local msg = table.concat(errors, "\n")
			if code == M.EXIT_MISSING_MODULE then
				msg = msg
					.. "\n\nInstall the dependencies with `<python> -m pip install pandas openpyxl xlrd`"
					.. "\nor point `python_cmd` in setup() at an interpreter that has them."
			end
			callback(nil, msg)
		end)
	end
	try(1)
end

return M
