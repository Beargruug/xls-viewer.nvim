local M = {}

-- Default configuration
M.config = {
	python_cmd = "/usr/bin/python3",
	max_column_width = 50,
	min_column_width = 3,
	padding = 2,
}

-- Setup function
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})

	-- Create autocmd for XLS/XLSX files
	vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
		pattern = { "*.xls", "*.xlsx" },
		callback = function()
			M.open_xls()
		end,
		group = vim.api.nvim_create_augroup("XLSViewer", { clear = true }),
	})
end

-- Function to align columns
local function align_table(lines)
	if #lines == 0 then
		return lines
	end

	-- Split lines into cells
	local rows = {}
	for _, line in ipairs(lines) do
		local cells = vim.split(line, "\t", { plain = true })
		table.insert(rows, cells)
	end

	-- Calculate max width for each column
	local col_widths = {}
	for _, row in ipairs(rows) do
		for i, cell in ipairs(row) do
			local width = vim.fn.strdisplaywidth(cell)
			if not col_widths[i] or width > col_widths[i] then
				col_widths[i] = math.min(width, M.config.max_column_width)
			end
			col_widths[i] = math.max(col_widths[i] or 0, M.config.min_column_width)
		end
	end

	-- Format rows with aligned columns
	local aligned = {}
	for i, row in ipairs(rows) do
		local formatted_cells = {}
		for j, cell in ipairs(row) do
			-- Truncate if too long
			if vim.fn.strdisplaywidth(cell) > M.config.max_column_width then
				cell = string.sub(cell, 1, M.config.max_column_width - 3) .. "..."
			end

			local padding = col_widths[j] - vim.fn.strdisplaywidth(cell)
			local padded_cell = cell .. string.rep(" ", padding + M.config.padding)
			table.insert(formatted_cells, padded_cell)
		end

		local line = table.concat(formatted_cells, "│")
		table.insert(aligned, line)

		-- Add separator after header (first row)
		if i == 1 then
			local separator_parts = {}
			for j = 1, #col_widths do
				table.insert(separator_parts, string.rep("─", col_widths[j] + M.config.padding))
			end
			table.insert(aligned, table.concat(separator_parts, "┼"))
		end
	end

	return aligned
end

-- Main function to open and display XLS file
function M.open_xls()
	local filepath = vim.fn.expand("<afile>:p")

	-- Python script to convert XLS to TSV
	local python_script = string.format(
		[[
import pandas as pd
import sys

try:
    df = pd.read_excel('%s')
    # Convert to TSV for easier parsing
    print(df.to_csv(sep='\t', index=False))
except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
]],
		filepath:gsub("\\", "\\\\"):gsub("'", "\\'")
	)

	-- Execute Python command
	local cmd = string.format('%s -c "%s"', M.config.python_cmd, python_script:gsub('"', '\\"'))
	local output = vim.fn.system(cmd)

	-- Check for errors
	if vim.v.shell_error ~= 0 then
		vim.notify("Error reading XLS file: " .. output, vim.log.levels.ERROR)
		return
	end

	-- Split output into lines
	local lines = vim.split(output, "\n", { plain = true })

	-- Remove empty lines
	local filtered_lines = {}
	for _, line in ipairs(lines) do
		if line ~= "" then
			table.insert(filtered_lines, line)
		end
	end

	-- Align columns
	local aligned_lines = align_table(filtered_lines)

	-- Create new buffer
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, aligned_lines)

	-- Set buffer options
	vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
	vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
	vim.api.nvim_buf_set_option(buf, "swapfile", false)
	vim.api.nvim_buf_set_option(buf, "modifiable", false)
	vim.api.nvim_buf_set_option(buf, "filetype", "xls-viewer")

	-- Set buffer name
	vim.api.nvim_buf_set_name(buf, filepath .. " [XLS Viewer]")

	-- Switch to the buffer
	vim.api.nvim_set_current_buf(buf)

	-- Add some helpful keymaps
	local opts = { buffer = buf, noremap = true, silent = true }
	vim.keymap.set("n", "q", ":bd<CR>", opts)
end

return M
