-- Maps between rendered buffer positions and table cells.
-- Render records, for every table line, the byte range of each cell's slot
-- (content + padding). All cursor <-> cell conversions go through here so
-- multibyte content never desyncs columns.
local M = {}

--- Line number (1-based) of the first data row
M.DATA_START = 3

--- Find the column under a byte position on a rendered line
---@param st table Buffer state
---@param lnum number 1-based line number
---@param byte number 0-based byte column
---@return number|nil col 1-based column index
function M.col_at(st, lnum, byte)
	local slots = st.line_slots and st.line_slots[lnum]
	if not slots or #slots == 0 then
		return nil
	end
	for i, slot in ipairs(slots) do
		if byte < slot[2] then
			return i
		end
	end
	return #slots
end

--- Column under the cursor of the current window
---@param st table Buffer state
---@return number|nil col
function M.col_at_cursor(st)
	local cursor = vim.api.nvim_win_get_cursor(0)
	return M.col_at(st, cursor[1], cursor[2])
end

--- Byte offset where a column starts on a rendered line
---@param st table Buffer state
---@param lnum number 1-based line number
---@param col number 1-based column index
---@return number|nil byte 0-based byte column
function M.byte_for_col(st, lnum, col)
	local slots = st.line_slots and st.line_slots[lnum]
	if not slots or not slots[col] then
		return nil
	end
	return slots[col][1]
end

--- Move the cursor to a cell on the current page
---@param st table Buffer state
---@param lnum number 1-based line number
---@param col number 1-based column index
function M.set_cursor(st, lnum, col)
	local byte = M.byte_for_col(st, lnum, col) or 0
	if lnum <= vim.api.nvim_buf_line_count(st.buf) then
		vim.api.nvim_win_set_cursor(0, { lnum, byte })
	end
end

return M
