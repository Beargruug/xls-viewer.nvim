local M = {}

local config = require("xls-viewer.config")
local state = require("xls-viewer.state")
local render = require("xls-viewer.render")

--- Run a Python script asynchronously and call callback with output
---@param script string Python script content
---@param callback function(output: string|nil, err: string|nil)
function M.run_python_async(script, callback)
	local stdout_chunks = {}
	local stderr_chunks = {}

	local cmd = { config.config.python_cmd, "-c", script }

	vim.fn.jobstart(cmd, {
		stdout_buffered = true,
		stderr_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stdout_chunks, line)
					end
				end
			end
		end,
		on_stderr = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stderr_chunks, line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			vim.schedule(function()
				if exit_code ~= 0 then
					callback(nil, table.concat(stderr_chunks, "\n"))
				else
					callback(table.concat(stdout_chunks, "\n"), nil)
				end
			end)
		end,
	})
end

--- Run a Python script synchronously
---@param script string Python script content
---@return string|nil output, string|nil error
function M.run_python_sync(script)
	local cmd = string.format('%s -c "%s"', config.config.python_cmd, script:gsub('"', '\\"'))
	local output = vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		return nil, output
	end
	return output, nil
end

--- Get sheet names from an Excel file
---@param filepath string Path to the Excel file
---@param callback function(sheet_names: table|nil, err: string|nil)
function M.get_sheet_names(filepath, callback)
	local escaped = filepath:gsub("\\", "\\\\"):gsub("'", "\\'")
	local script = string.format([[
import pandas as pd
import json
import sys

try:
    xls = pd.ExcelFile('%s')
    print(json.dumps(xls.sheet_names))
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
]], escaped)

	if config.config.async then
		M.run_python_async(script, function(output, err)
			if err then
				callback(nil, err)
			else
				local ok, names = pcall(vim.json.decode, output)
				if ok then
					callback(names, nil)
				else
					callback(nil, "Failed to parse sheet names: " .. output)
				end
			end
		end)
	else
		local output, err = M.run_python_sync(script)
		if err then
			callback(nil, err)
		else
			local ok, names = pcall(vim.json.decode, output)
			if ok then
				callback(names, nil)
			else
				callback(nil, "Failed to parse sheet names: " .. output)
			end
		end
	end
end

--- Load sheet data from an Excel file
---@param filepath string Path to the Excel file
---@param sheet_name string Name of the sheet to load
---@param callback function(headers: table|nil, rows: table|nil, total: number|nil, err: string|nil)
function M.load_sheet(filepath, sheet_name, callback)
	local escaped = filepath:gsub("\\", "\\\\"):gsub("'", "\\'")
	local sheet_escaped = sheet_name:gsub("\\", "\\\\"):gsub("'", "\\'")

	local script = string.format([[
import pandas as pd
import json
import sys

try:
    df = pd.read_excel('%s', sheet_name='%s')
    total = len(df)
    # Output: first line is JSON metadata, rest is TSV
    print(json.dumps({"total_rows": total}))
    print(df.to_csv(sep='\t', index=False))
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
]], escaped, sheet_escaped)

	if config.config.async then
		M.run_python_async(script, function(output, err)
			if err then
				callback(nil, nil, nil, err)
			else
				M._parse_sheet_output(output, callback)
			end
		end)
	else
		local output, err = M.run_python_sync(script)
		if err then
			callback(nil, nil, nil, err)
		else
			M._parse_sheet_output(output, callback)
		end
	end
end

--- Parse the output from the Python sheet loading script
---@param output string Raw output
---@param callback function
function M._parse_sheet_output(output, callback)
	local lines = vim.split(output, "\n", { plain = true })

	-- First line is JSON metadata
	if #lines < 2 then
		callback(nil, nil, nil, "Unexpected output format")
		return
	end

	local ok, meta = pcall(vim.json.decode, lines[1])
	if not ok then
		callback(nil, nil, nil, "Failed to parse metadata: " .. lines[1])
		return
	end

	-- Rest is TSV data
	local tsv_lines = {}
	for i = 2, #lines do
		if lines[i] ~= "" then
			table.insert(tsv_lines, lines[i])
		end
	end

	if #tsv_lines == 0 then
		callback({}, {}, meta.total_rows or 0, nil)
		return
	end

	-- First TSV line is headers
	local headers = vim.split(tsv_lines[1], "\t", { plain = true })

	-- Rest are data rows
	local rows = {}
	for i = 2, #tsv_lines do
		local cells = vim.split(tsv_lines[i], "\t", { plain = true })
		table.insert(rows, cells)
	end

	callback(headers, rows, meta.total_rows or #rows, nil)
end

--- Main entry point: open an XLS/XLSX file
function M.open_xls()
	local filepath = vim.fn.expand("<afile>:p")

	-- Create buffer immediately
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_set_option_value("buftype", "nofile", { buf = buf })
	vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = buf })
	vim.api.nvim_set_option_value("swapfile", false, { buf = buf })
	vim.api.nvim_set_option_value("filetype", "xls-viewer", { buf = buf })
	vim.api.nvim_buf_set_name(buf, filepath .. " [XLS Viewer]")
	vim.api.nvim_set_current_buf(buf)

	-- Show loading message
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "Loading " .. vim.fn.fnamemodify(filepath, ":t") .. "..." })
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Create state
	local st = state.create(buf, filepath)
	st.loading = true

	-- Clean up state when buffer is deleted
	vim.api.nvim_create_autocmd("BufDelete", {
		buffer = buf,
		callback = function()
			state.destroy(buf)
		end,
	})

	-- Step 1: Get sheet names
	M.get_sheet_names(filepath, function(sheet_names, err)
		if err then
			vim.notify("Error reading XLS file: " .. err, vim.log.levels.ERROR)
			return
		end

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		st.sheet_names = sheet_names or {}

		-- Determine which sheet to load
		local target_sheet
		local default = config.config.default_sheet
		if type(default) == "string" then
			target_sheet = default
		elseif type(default) == "number" and sheet_names[default + 1] then
			target_sheet = sheet_names[default + 1]
		else
			target_sheet = sheet_names[1]
		end

		if not target_sheet then
			vim.notify("No sheets found in file", vim.log.levels.ERROR)
			return
		end

		-- Step 2: Load the sheet data
		M._load_and_render(buf, filepath, target_sheet)
	end)
end

--- Load a specific sheet and render it
---@param buf number Buffer number
---@param filepath string File path
---@param sheet_name string Sheet name to load
function M._load_and_render(buf, filepath, sheet_name)
	local st = state.get(buf)
	if not st then
		return
	end

	st.loading = true
	st.current_sheet = sheet_name

	-- Update buffer name
	pcall(vim.api.nvim_buf_set_name, buf, filepath .. " [" .. sheet_name .. "]")

	M.load_sheet(filepath, sheet_name, function(headers, rows, total, err)
		if err then
			vim.notify("Error loading sheet: " .. err, vim.log.levels.ERROR)
			return
		end

		if not vim.api.nvim_buf_is_valid(buf) then
			return
		end

		st.headers = headers or {}
		st.rows = rows or {}
		st.total_rows = total or #st.rows
		st.loading = false

		-- Reset pagination and filter when switching sheets
		st.current_page = 1
		st.filter_pattern = nil
		st.filter_column = nil
		st.filtered_rows = nil
		st.sort_col = nil
		st.sort_dir = nil

		-- Detect column types
		st.col_types = state.detect_types(st.rows)

		-- Render
		render.render(buf)

		-- Setup keymaps (only once per buffer)
		M._setup_keymaps(buf)
	end)
end

--- Setup buffer-local keymaps
---@param buf number Buffer number
function M._setup_keymaps(buf)
	local opts = { buffer = buf, noremap = true, silent = true }

	-- Close buffer
	vim.keymap.set("n", "q", ":bd<CR>", opts)
	vim.keymap.set("n", "<C-c>", ":bd<CR>", opts)

	-- Sheet selection
	vim.keymap.set("n", "gs", function()
		require("xls-viewer.sheets").select_sheet(buf)
	end, opts)

	-- Sorting
	vim.keymap.set("n", "s", function()
		require("xls-viewer.sort").sort_by_cursor(buf)
	end, opts)

	-- Filter/Search
	vim.keymap.set("n", "/", function()
		require("xls-viewer.filter").prompt_filter(buf)
	end, opts)
	vim.keymap.set("n", "<leader>F", function()
		require("xls-viewer.filter").clear_filter(buf)
	end, opts)

	-- Cell navigation
	vim.keymap.set("n", "gc", function()
		require("xls-viewer.navigate").goto_cell(buf)
	end, opts)

	-- Pagination
	vim.keymap.set("n", "]p", function()
		require("xls-viewer.paginate").next_page(buf)
	end, opts)
	vim.keymap.set("n", "[p", function()
		require("xls-viewer.paginate").prev_page(buf)
	end, opts)
	vim.keymap.set("n", "gp", function()
		require("xls-viewer.paginate").goto_page(buf)
	end, opts)
end

return M
