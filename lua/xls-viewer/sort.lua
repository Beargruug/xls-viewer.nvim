local M = {}

local state = require("xls-viewer.state")
local render = require("xls-viewer.render")

--- Determine which column the cursor is on (based on header row)
---@param buf number Buffer number
---@return number|nil col_index 1-based column index
function M._get_cursor_column(buf)
	local st = state.get(buf)
	if not st then
		return nil
	end

	local cursor = vim.api.nvim_win_get_cursor(0)
	local cursor_col = cursor[2] -- 0-indexed byte position

	local col_widths = st.col_widths
	if not col_widths or #col_widths == 0 then
		return nil
	end

	-- Walk through columns to find which one the cursor is in
	local byte_offset = 0
	local cfg = require("xls-viewer.config").config

	for i = 1, #col_widths do
		local col_total_width = col_widths[i] + cfg.padding
		-- Account for separator (│ = 3 bytes) except after last column
		local separator_width = (i < #col_widths) and 3 or 0
		local next_offset = byte_offset + col_total_width + separator_width

		if cursor_col < next_offset or i == #col_widths then
			return i
		end

		byte_offset = next_offset
	end

	return #col_widths
end

--- Sort by the column under the cursor (cycle: none -> asc -> desc -> none)
---@param buf number Buffer number
function M.sort_by_cursor(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	local col = M._get_cursor_column(buf)
	if not col then
		vim.notify("Could not determine column", vim.log.levels.WARN)
		return
	end

	-- Cycle sort state
	if st.sort_col == col then
		if st.sort_dir == "asc" then
			st.sort_dir = "desc"
		elseif st.sort_dir == "desc" then
			st.sort_col = nil
			st.sort_dir = nil
		end
	else
		st.sort_col = col
		st.sort_dir = "asc"
	end

	-- Invalidate filter cache since sorted order changes
	state.invalidate_filter(st)

	-- Show sort status
	if st.sort_col then
		local header = st.headers[st.sort_col] or tostring(st.sort_col)
		local arrow = st.sort_dir == "asc" and "▲" or "▼"
		vim.notify(string.format("Sort: %s %s", header, arrow), vim.log.levels.INFO)
	else
		vim.notify("Sort cleared", vim.log.levels.INFO)
	end

	-- Re-render
	render.render(buf)
end

return M
