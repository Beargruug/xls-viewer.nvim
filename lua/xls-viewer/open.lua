local M = {}

local align = require("xls-viewer.align")
local config = require("xls-viewer.config")

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
	local cmd = string.format('%s -c "%s"', config.config.python_cmd, python_script:gsub('"', '\\"'))
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
	local aligned_lines = align.align_table(filtered_lines)

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
