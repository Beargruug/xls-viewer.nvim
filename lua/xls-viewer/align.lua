local M = {}

local config = require("xls-viewer.config")

-- Function to align columns
function M.align_table(lines)
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
				col_widths[i] = math.min(width, config.config.max_column_width)
			end
			col_widths[i] = math.max(col_widths[i] or 0, config.config.min_column_width)
		end
	end

	-- Format rows with aligned columns
	local aligned = {}
	for i, row in ipairs(rows) do
		local formatted_cells = {}
		for j, cell in ipairs(row) do
			-- Truncate if too long
			if vim.fn.strdisplaywidth(cell) > config.config.max_column_width then
				cell = string.sub(cell, 1, config.config.max_column_width - 3) .. "..."
			end

			local padding = col_widths[j] - vim.fn.strdisplaywidth(cell)
			local padded_cell = cell .. string.rep(" ", padding + config.config.padding)
			table.insert(formatted_cells, padded_cell)
		end

		local line = table.concat(formatted_cells, "│")
		table.insert(aligned, line)

		-- Add separator after header (first row)
		if i == 1 then
			local separator_parts = {}
			for j = 1, #col_widths do
				table.insert(separator_parts, string.rep("─", col_widths[j] + config.config.padding))
			end
			table.insert(aligned, table.concat(separator_parts, "┼"))
		end
	end

	return aligned
end

return M
