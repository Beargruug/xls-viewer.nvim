local M = {}

local config = require("xls-viewer.config")
local state = require("xls-viewer.state")
local layout = require("xls-viewer.layout")

local ns_id = vim.api.nvim_create_namespace("xls_viewer_hl")
M.ns_id = ns_id

local SEP = "│"
local SEP_BYTES = #SEP
local ELLIPSIS = "…"

--- Text shown for a cell: single line, tabs flattened (stored data stays raw)
---@param cell string
---@return string
function M.display(cell)
	if cell:find("[\r\n\t]") then
		cell = cell:gsub("\r\n", "↵"):gsub("[\r\n]", "↵"):gsub("\t", " ")
	end
	return cell
end

--- Truncate a string to a maximum display width (multibyte safe)
---@param cell string
---@param width number
---@return string
function M.truncate(cell, width)
	if vim.fn.strdisplaywidth(cell) <= width then
		return cell
	end
	if width <= 1 then
		return width == 1 and ELLIPSIS or ""
	end
	local n = width - 1
	local part = vim.fn.strcharpart(cell, 0, n)
	while n > 0 and vim.fn.strdisplaywidth(part) > width - 1 do
		n = n - 1
		part = vim.fn.strcharpart(cell, 0, n)
	end
	return part .. ELLIPSIS
end

--- Render the current state into the buffer
---@param buf number Buffer number
function M.render(buf)
	local st = state.get(buf)
	if not st or not vim.api.nvim_buf_is_valid(buf) then
		return
	end

	local page_rows = state.get_page_rows(st)
	local headers = st.headers
	local col_widths = M._compute_col_widths(headers, page_rows, st.width_overrides)
	st.col_widths = col_widths

	local lines = {}
	local cells_by_line = {} -- [lnum] = displayed (truncated) cells, for highlighting
	st.line_slots = {}

	-- Header line
	local header_line, header_slots, header_cells = M._format_row(headers, col_widths)
	lines[1] = header_line
	st.line_slots[1] = header_slots
	cells_by_line[1] = header_cells

	-- Separator line
	lines[2] = M._build_separator(col_widths)

	-- Data rows
	for i, row in ipairs(page_rows) do
		local lnum = layout.DATA_START + i - 1
		local line, slots, cells = M._format_row(row, col_widths)
		lines[lnum] = line
		st.line_slots[lnum] = slots
		cells_by_line[lnum] = cells
	end

	-- Footer
	lines[#lines + 1] = ""
	lines[#lines + 1] = M._build_footer(st)

	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("modified", false, { buf = buf })

	M._apply_highlights(buf, st, lines, cells_by_line, #page_rows)
end

--- Render a plain message (loading / error) into the buffer
---@param buf number
---@param msg_lines string[]
---@param hl string|nil highlight group for all lines
function M.message(buf, msg_lines, hl)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local flat = {}
	for _, l in ipairs(msg_lines) do
		vim.list_extend(flat, vim.split(l, "\n", { plain = true }))
	end
	vim.api.nvim_set_option_value("modifiable", true, { buf = buf })
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, flat)
	vim.api.nvim_set_option_value("modifiable", false, { buf = buf })
	vim.api.nvim_set_option_value("modified", false, { buf = buf })
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	if hl then
		for i = 0, #flat - 1 do
			vim.api.nvim_buf_set_extmark(buf, ns_id, i, 0, { end_row = i, end_col = #flat[i + 1], hl_group = hl })
		end
	end
end

--- Build the footer line
---@param st table
---@return string
function M._build_footer(st)
	local total_visible = state.get_total_visible_rows(st)
	local total_pages = state.get_total_pages(st)
	local parts = {}

	if st.current_sheet then
		table.insert(parts, string.format("Sheet: %s", st.current_sheet))
	end

	if st.sort_col and st.sort_dir then
		local sort_header = st.headers[st.sort_col] or tostring(st.sort_col)
		local arrow = st.sort_dir == "asc" and "▲" or "▼"
		table.insert(parts, string.format("Sort: %s %s", sort_header, arrow))
	end

	if st.filter_pattern and st.filter_pattern ~= "" then
		local where = st.filter_column and (" in " .. (st.headers[st.filter_column] or st.filter_column)) or ""
		table.insert(
			parts,
			string.format('Filter: "%s"%s (%d/%d rows)', st.filter_pattern, where, total_visible, #st.rows)
		)
	end

	if total_pages > 1 then
		local start_row = (st.current_page - 1) * st.page_size + 1
		local end_row = math.min(st.current_page * st.page_size, total_visible)
		table.insert(
			parts,
			string.format(
				"Page %d/%d (rows %d-%d of %d)",
				st.current_page,
				total_pages,
				start_row,
				end_row,
				total_visible
			)
		)
	else
		table.insert(parts, string.format("%d rows", total_visible))
	end

	return table.concat(parts, " │ ")
end

--- Compute column widths from headers and rows
---@param headers table Header cells
---@param rows table Data rows
---@param overrides table|nil Per-column width overrides
---@return table col_widths
function M._compute_col_widths(headers, rows, overrides)
	local cfg = config.config
	local col_widths = {}

	local function consider(i, cell)
		local width =
			math.max(math.min(vim.fn.strdisplaywidth(M.display(cell)), cfg.max_column_width), cfg.min_column_width)
		if not col_widths[i] or width > col_widths[i] then
			col_widths[i] = width
		end
	end

	for i, header in ipairs(headers) do
		consider(i, header)
	end
	for _, row in ipairs(rows) do
		for i, cell in ipairs(row) do
			consider(i, cell)
		end
	end

	if overrides then
		for i, w in pairs(overrides) do
			if col_widths[i] then
				col_widths[i] = math.max(1, w)
			end
		end
	end

	return col_widths
end

--- Format a single row with aligned cells
---@param cells table Array of cell strings
---@param col_widths table Column widths (display cells)
---@return string line
---@return table slots { {start_byte, slot_end_byte, content_end_byte}, ... } (0-based, end exclusive)
---@return table shown Displayed (possibly truncated) cell strings
function M._format_row(cells, col_widths)
	local pad = config.config.padding
	local parts = {}
	local slots = {}
	local shown = {}
	local byte = 0

	for j = 1, #col_widths do
		local cell = M.truncate(M.display(cells[j] or ""), col_widths[j])
		local fill = col_widths[j] - vim.fn.strdisplaywidth(cell) + pad
		local slot = cell .. string.rep(" ", fill)

		slots[j] = { byte, byte + #slot, byte + #cell }
		shown[j] = cell
		parts[j] = slot
		byte = byte + #slot + SEP_BYTES
	end

	return table.concat(parts, SEP), slots, shown
end

--- Build separator line
---@param col_widths table Column widths
---@return string separator
function M._build_separator(col_widths)
	local pad = config.config.padding
	local parts = {}
	for j = 1, #col_widths do
		parts[j] = string.rep("─", col_widths[j] + pad)
	end
	return table.concat(parts, "┼")
end

--- Pick the highlight group for a single cell
---@param cell string
---@param col_type string
---@param hl table highlight config
---@return string
function M._cell_hl(cell, col_type, hl)
	if state.is_null(cell) then
		return hl.null
	end
	local l = cell:lower()
	if col_type == "number" and tonumber(cell) then
		return hl.number
	elseif l == "true" or l == "false" then
		return hl.boolean
	elseif col_type == "date" or cell:match("^%d%d%d%d[%-/]%d%d[%-/]%d%d") then
		return hl.date
	end
	return hl.string
end

local function hl_range(buf, line, start_col, end_col, group)
	if end_col > start_col then
		vim.api.nvim_buf_set_extmark(
			buf,
			ns_id,
			line,
			start_col,
			{ end_row = line, end_col = end_col, hl_group = group }
		)
	end
end

--- Apply syntax highlights via extmarks
---@param buf number Buffer number
---@param st table Buffer state
---@param lines table Rendered lines
---@param cells_by_line table Displayed cells per line
---@param n_rows number Number of data rows on this page
function M._apply_highlights(buf, st, lines, cells_by_line, n_rows)
	vim.api.nvim_buf_clear_namespace(buf, ns_id, 0, -1)
	local hl = config.config.highlights

	hl_range(buf, 0, 0, #lines[1], hl.header)
	hl_range(buf, 1, 0, #lines[2], hl.separator)

	for i = 1, n_rows do
		local lnum = layout.DATA_START + i - 1
		local slots = st.line_slots[lnum]
		local cells = cells_by_line[lnum]
		for col, slot in ipairs(slots) do
			local cell = cells[col]
			if cell ~= "" then
				local group = M._cell_hl(cell, st.col_types[col] or "string", hl)
				hl_range(buf, lnum - 1, slot[1], slot[3], group)
			end
		end
	end

	-- Footer line
	hl_range(buf, #lines - 1, 0, #lines[#lines], hl.separator)
end

return M
