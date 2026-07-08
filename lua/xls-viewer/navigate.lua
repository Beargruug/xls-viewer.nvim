local M = {}

local state = require("xls-viewer.state")

--- Parse a cell coordinate like "B5" or "AA12" into column and row indices
---@param coord string The coordinate string (e.g., "B5", "AA12")
---@return number|nil col 1-based column index
---@return number|nil row 1-based row index
function M._parse_coordinate(coord)
	coord = coord:upper():gsub("%s+", "")

	local col_str = coord:match("^([A-Z]+)")
	local row_str = coord:match("(%d+)$")

	if not col_str or not row_str then
		return nil, nil
	end

	-- Convert column letters to number (A=1, B=2, ..., Z=26, AA=27, etc.)
	local col = 0
	for i = 1, #col_str do
		col = col * 26 + (string.byte(col_str, i) - string.byte("A") + 1)
	end

	local row = tonumber(row_str)
	return col, row
end

--- Convert a column index to letter(s) (1=A, 2=B, ..., 26=Z, 27=AA)
---@param col number 1-based column index
---@return string letters
function M._col_to_letters(col)
	local result = ""
	while col > 0 do
		col = col - 1
		result = string.char(string.byte("A") + (col % 26)) .. result
		col = math.floor(col / 26)
	end
	return result
end

--- Jump cursor to a specific cell by coordinate
---@param buf number Buffer number
function M.goto_cell(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	vim.ui.input({
		prompt = "Go to cell (e.g., B5): ",
	}, function(input)
		if not input or input == "" then
			return
		end

		local col, row = M._parse_coordinate(input)
		if not col or not row then
			vim.notify("Invalid cell coordinate: " .. input, vim.log.levels.WARN)
			return
		end

		-- Validate bounds
		if col > #st.headers then
			vim.notify(
				string.format("Column %s exceeds table width (%d columns)", M._col_to_letters(col), #st.headers),
				vim.log.levels.WARN
			)
			return
		end

		if row > #st.rows then
			vim.notify(
				string.format("Row %d exceeds table length (%d rows)", row, #st.rows),
				vim.log.levels.WARN
			)
			return
		end

		-- Calculate the page this row is on
		local target_page = math.ceil(row / st.page_size)
		if target_page ~= st.current_page then
			st.current_page = target_page
			require("xls-viewer.render").render(buf)
		end

		-- Calculate buffer line position
		-- Line 0: header, Line 1: separator, Line 2+: data rows
		local row_in_page = row - (st.current_page - 1) * st.page_size
		local buf_line = row_in_page + 1 -- +2 for header+sep, but 0-indexed so +1

		-- Calculate byte column position
		local cfg = require("xls-viewer.config").config
		local byte_col = 0
		for i = 1, col - 1 do
			byte_col = byte_col + (st.col_widths[i] or 0) + cfg.padding + 3 -- separator bytes
		end

		-- Set cursor
		local win = vim.api.nvim_get_current_win()
		local line_count = vim.api.nvim_buf_line_count(buf)
		if buf_line + 1 <= line_count then
			vim.api.nvim_win_set_cursor(win, { buf_line + 1, byte_col })
			vim.notify(string.format("Jumped to %s (row %d, col %s)", input:upper(), row, M._col_to_letters(col)), vim.log.levels.INFO)
		else
			vim.notify("Cell position is out of visible range", vim.log.levels.WARN)
		end
	end)
end

--- Get the current cell coordinate based on cursor position
---@param buf number Buffer number
---@return string|nil coordinate e.g., "B5"
function M.get_current_cell(buf)
	local st = state.get(buf)
	if not st then
		return nil
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_line = cursor[1] -- 1-indexed
	local cursor_col = cursor[2] -- 0-indexed byte

	-- Determine row: line 1 = header, line 2 = separator, line 3+ = data
	if cursor_line <= 2 then
		return nil -- On header or separator
	end

	local row_in_page = cursor_line - 2
	local row = (st.current_page - 1) * st.page_size + row_in_page

	-- Determine column from cursor byte position
	local cfg = require("xls-viewer.config").config
	local byte_offset = 0
	local col = 1

	for i = 1, #st.col_widths do
		local col_total = st.col_widths[i] + cfg.padding + 3
		if cursor_col < byte_offset + col_total or i == #st.col_widths then
			col = i
			break
		end
		byte_offset = byte_offset + col_total
	end

	return M._col_to_letters(col) .. tostring(row)
end

return M
