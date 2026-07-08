local M = {}

local config = require("xls-viewer.config")
local state = require("xls-viewer.state")

local ns_id = vim.api.nvim_create_namespace("xls_viewer_hl")

--- Render the current state into the buffer
---@param buf number Buffer number
function M.render(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	local visible_rows = state.get_visible_rows(st)
	local headers = st.headers
	local col_widths = M._compute_col_widths(headers, visible_rows)
	st.col_widths = col_widths

	-- Build lines
	local lines = {}

	-- Header line
	local header_line = M._format_row(headers, col_widths)
	table.insert(lines, header_line)

	-- Separator line
	local separator = M._build_separator(col_widths)
	table.insert(lines, separator)

	-- Data rows
	for _, row in ipairs(visible_rows) do
		table.insert(lines, M._format_row(row, col_widths))
	end

	-- Footer (pagination info)
	local total_visible = state.get_total_visible_rows(st)
	local total_pages = state.get_total_pages(st)
	local footer_parts = {}

	-- Sheet info
	if st.current_sheet then
		table.insert(footer_parts, string.format("Sheet: %s", st.current_sheet))
	end

	-- Sort info
	if st.sort_col and st.sort_dir then
		local sort_header = headers[st.sort_col] or tostring(st.sort_col)
		local arrow = st.sort_dir == "asc" and "▲" or "▼"
		table.insert(footer_parts, string.format("Sort: %s %s", sort_header, arrow))
	end

	-- Filter info
	if st.filter_pattern and st.filter_pattern ~= "" then
		table.insert(footer_parts, string.format("Filter: \"%s\" (%d/%d rows)", st.filter_pattern, total_visible, #st.rows))
	end

	-- Page info
	if total_pages > 1 then
		local start_row = (st.current_page - 1) * st.page_size + 1
		local end_row = math.min(st.current_page * st.page_size, total_visible)
		table.insert(footer_parts, string.format("Page %d/%d (rows %d-%d of %d)", st.current_page, total_pages, start_row, end_row, total_visible))
	else
		table.insert(footer_parts, string.format("%d rows", total_visible))
	end

	-- Add empty line + footer
	table.insert(lines, "")
	table.insert(lines, table.concat(footer_parts, " │ "))

	-- Write to buffer
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })

	-- Apply highlights
	M._apply_highlights(buf, st, lines, col_widths)
end

--- Compute column widths from headers and rows
---@param headers table Header cells
---@param rows table Data rows
---@return table col_widths
function M._compute_col_widths(headers, rows)
	local cfg = config.config
	local col_widths = {}

	-- Start with header widths
	for i, header in ipairs(headers) do
		col_widths[i] = math.min(vim.fn.strdisplaywidth(header), cfg.max_column_width)
		col_widths[i] = math.max(col_widths[i], cfg.min_column_width)
	end

	-- Check data rows
	for _, row in ipairs(rows) do
		for i, cell in ipairs(row) do
			local width = vim.fn.strdisplaywidth(cell)
			local clamped = math.min(width, cfg.max_column_width)
			clamped = math.max(clamped, cfg.min_column_width)
			if not col_widths[i] or clamped > col_widths[i] then
				col_widths[i] = clamped
			end
		end
	end

	return col_widths
end

--- Format a single row with aligned cells
---@param cells table Array of cell strings
---@param col_widths table Column widths
---@return string formatted line
function M._format_row(cells, col_widths)
	local cfg = config.config
	local formatted = {}

	for j = 1, #col_widths do
		local cell = cells[j] or ""

		-- Truncate if too long
		if vim.fn.strdisplaywidth(cell) > cfg.max_column_width then
			cell = string.sub(cell, 1, cfg.max_column_width - 3) .. "..."
		end

		local padding = col_widths[j] - vim.fn.strdisplaywidth(cell)
		local padded_cell = cell .. string.rep(" ", padding + cfg.padding)
		table.insert(formatted, padded_cell)
	end

	return table.concat(formatted, "│")
end

--- Build separator line
---@param col_widths table Column widths
---@return string separator
function M._build_separator(col_widths)
	local cfg = config.config
	local parts = {}
	for j = 1, #col_widths do
		table.insert(parts, string.rep("─", col_widths[j] + cfg.padding))
	end
	return table.concat(parts, "┼")
end

--- Apply syntax highlights via extmarks
---@param buf number Buffer number
---@param st table Buffer state
---@param lines table Rendered lines
---@param col_widths table Column widths
function M._apply_highlights(buf, st, lines, col_widths)
	-- Clear existing highlights
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)

	local cfg = config.config
	local hl_config = cfg.highlights

	-- Highlight header (line 0)
	if #lines > 0 then
		vim.api.nvim_buf_add_highlight(buf, ns_id, hl_config.header, 0, 0, -1)
	end

	-- Highlight separator (line 1)
	if #lines > 1 then
		vim.api.nvim_buf_add_highlight(buf, ns_id, hl_config.separator, 1, 0, -1)
	end

	-- Highlight data cells by type
	local data_start_line = 2 -- 0-indexed: header=0, sep=1, data starts at 2
	local visible_rows = state.get_visible_rows(st)

	for row_idx, row in ipairs(visible_rows) do
		local line_idx = data_start_line + row_idx - 1
		if line_idx >= #lines - 2 then
			break -- Don't highlight footer
		end

		local byte_offset = 0
		for col_idx = 1, #col_widths do
			local cell = row[col_idx] or ""
			local col_type = st.col_types[col_idx] or "string"

			-- Determine cell type for this specific cell
			local cell_hl = nil
			if cell == "" or cell:lower() == "nan" or cell:lower() == "none" or cell:lower() == "null" then
				cell_hl = hl_config.null
			elseif col_type == "number" and tonumber(cell) then
				cell_hl = hl_config.number
			elseif col_type == "boolean" or cell:lower() == "true" or cell:lower() == "false" then
				cell_hl = hl_config.boolean
			elseif col_type == "date" or cell:match("^%d%d%d%d[%-/]%d%d[%-/]%d%d") then
				cell_hl = hl_config.date
			else
				cell_hl = hl_config.string
			end

			-- Apply highlight to the cell content (not padding)
			if cell_hl and cell ~= "" then
				local cell_width = math.min(vim.fn.strdisplaywidth(cell), cfg.max_column_width)
				vim.api.nvim_buf_add_highlight(buf, ns_id, cell_hl, line_idx, byte_offset, byte_offset + #cell)
			end

			-- Advance byte offset: cell content + padding + separator (│ is 3 bytes in UTF-8)
			byte_offset = byte_offset + col_widths[col_idx] + cfg.padding + 3 -- "│" = 3 bytes
		end
	end

	-- Highlight footer line
	if #lines >= 2 then
		vim.api.nvim_buf_add_highlight(buf, ns_id, hl_config.separator, #lines - 1, 0, -1)
	end
end

return M
