-- Interactive column resizing
local M = {}

local state = require("xls-viewer.state")
local render = require("xls-viewer.render")
local layout = require("xls-viewer.layout")

-- Display cells per keypress
M.STEP = 2

--- Re-render and keep the cursor on the same cell
---@param buf number
---@param st table
---@param lnum number
---@param col number
local function rerender(buf, st, lnum, col)
	render.render(buf)
	layout.set_cursor(st, lnum, col)
end

--- Widen (delta > 0) or narrow (delta < 0) the column under the cursor
---@param buf number
---@param delta number Display cells
function M.resize(buf, delta)
	local st = state.get(buf)
	if not st then
		return
	end
	local col = layout.col_at_cursor(st)
	if not col then
		return
	end
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local current = st.col_widths[col] or 1
	st.width_overrides[col] = math.max(1, current + delta)
	rerender(buf, st, lnum, col)
end

--- Reset the width of the column under the cursor (or all columns)
---@param buf number
---@param all boolean|nil
function M.reset(buf, all)
	local st = state.get(buf)
	if not st then
		return
	end
	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local col = layout.col_at_cursor(st) or 1
	if all then
		st.width_overrides = {}
	else
		st.width_overrides[col] = nil
	end
	rerender(buf, st, lnum, col)
end

return M
