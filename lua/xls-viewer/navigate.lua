local M = {}

local state = require("xls-viewer.state")
local layout = require("xls-viewer.layout")

--- Parse a cell coordinate like "B5" or "AA12" into column and row indices
---@param coord string The coordinate string (e.g., "B5", "AA12")
---@return number|nil col 1-based column index
---@return number|nil row 1-based row index
function M._parse_coordinate(coord)
	coord = coord:upper():gsub("%s+", "")

	local col_str, row_str = coord:match("^([A-Z]+)(%d+)$")
	if not col_str then
		return nil, nil
	end

	-- Convert column letters to number (A=1, B=2, ..., Z=26, AA=27, etc.)
	local col = 0
	for i = 1, #col_str do
		col = col * 26 + (string.byte(col_str, i) - string.byte("A") + 1)
	end

	local row = tonumber(row_str)
	if row < 1 then
		return nil, nil
	end
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

--- Jump to a cell. Row numbers refer to the current view (after filter/sort).
---@param buf number
---@param coord string e.g. "B5"
---@return boolean ok
function M.jump(buf, coord)
	local st = state.get(buf)
	if not st then
		return false
	end

	local col, row = M._parse_coordinate(coord)
	if not col or not row then
		vim.notify("Invalid cell coordinate: " .. coord, vim.log.levels.WARN)
		return false
	end

	if col > #st.col_widths then
		vim.notify(
			string.format("Column %s exceeds table width (%d columns)", M._col_to_letters(col), #st.col_widths),
			vim.log.levels.WARN
		)
		return false
	end

	local total = state.get_total_visible_rows(st)
	if row > total then
		vim.notify(string.format("Row %d exceeds table length (%d rows)", row, total), vim.log.levels.WARN)
		return false
	end

	local target_page = math.ceil(row / st.page_size)
	if target_page ~= st.current_page then
		st.current_page = target_page
		require("xls-viewer.render").render(buf)
	end

	local row_in_page = row - (st.current_page - 1) * st.page_size
	layout.set_cursor(st, layout.DATA_START + row_in_page - 1, col)
	return true
end

--- Prompt for a cell and jump to it
---@param buf number Buffer number
function M.goto_cell(buf)
	if not state.get(buf) then
		return
	end

	vim.ui.input({
		prompt = "Go to cell (e.g., B5): ",
	}, function(input)
		if not input or input == "" then
			return
		end
		M.jump(buf, input)
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

	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local n_rows = #state.get_page_rows(st)
	if lnum < layout.DATA_START or lnum >= layout.DATA_START + n_rows then
		return nil
	end

	local col = layout.col_at_cursor(st)
	if not col then
		return nil
	end
	local row = (st.current_page - 1) * st.page_size + (lnum - layout.DATA_START + 1)
	return M._col_to_letters(col) .. tostring(row)
end

return M
