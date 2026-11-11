local M = {}

local state = require("xls-viewer.state")
local render = require("xls-viewer.render")
local layout = require("xls-viewer.layout")

--- Resolve a column given as number or header name
---@param st table
---@param arg string
---@return number|nil
function M.resolve_column(st, arg)
	local col = tonumber(arg)
	if col then
		return (col >= 1 and col <= #st.col_widths) and math.floor(col) or nil
	end
	for i, h in ipairs(st.headers) do
		if h:lower() == arg:lower() then
			return i
		end
	end
	return nil
end

--- Set sort state and re-render
---@param buf number
---@param col number|nil Column index (nil clears sort)
---@param dir string|nil "asc" | "desc"
function M.set(buf, col, dir)
	local st = state.get(buf)
	if not st then
		return
	end

	st.sort_col = col
	st.sort_dir = col and (dir or "asc") or nil
	st.current_page = 1
	state.invalidate(st)
	render.render(buf)

	if st.sort_col then
		local header = st.headers[st.sort_col] or tostring(st.sort_col)
		local arrow = st.sort_dir == "asc" and "▲" or "▼"
		vim.notify(string.format("Sort: %s %s", header, arrow), vim.log.levels.INFO)
	else
		vim.notify("Sort cleared", vim.log.levels.INFO)
	end
end

--- Next sort direction for a column (cycle: none -> asc -> desc -> none)
---@param st table
---@param col number
---@return string|nil
function M.next_dir(st, col)
	if st.sort_col ~= col then
		return "asc"
	end
	if st.sort_dir == "asc" then
		return "desc"
	end
	return nil
end

--- Sort by the column under the cursor
---@param buf number Buffer number
function M.sort_by_cursor(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	local col = layout.col_at_cursor(st)
	if not col then
		vim.notify("Could not determine column", vim.log.levels.WARN)
		return
	end

	local lnum = vim.api.nvim_win_get_cursor(0)[1]
	local dir = M.next_dir(st, col)
	M.set(buf, dir and col or nil, dir)
	layout.set_cursor(st, lnum, col)
end

--- :XlsSort [column]
---@param buf number
---@param arg string
function M.command(buf, arg)
	local st = state.get(buf)
	if not st then
		return
	end
	if arg == "" then
		M.sort_by_cursor(buf)
		return
	end
	local col = M.resolve_column(st, arg)
	if not col then
		vim.notify("Column not found: " .. arg, vim.log.levels.WARN)
		return
	end
	local dir = M.next_dir(st, col)
	M.set(buf, dir and col or nil, dir)
end

return M
