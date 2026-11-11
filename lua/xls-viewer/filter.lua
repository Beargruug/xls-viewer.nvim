local M = {}

local state = require("xls-viewer.state")
local render = require("xls-viewer.render")

--- Apply a filter and re-render
---@param buf number
---@param pattern string
---@param col number|nil Column index (nil = all columns)
function M.apply(buf, pattern, col)
	local st = state.get(buf)
	if not st then
		return
	end

	st.filter_pattern = pattern
	st.filter_column = col
	st.current_page = 1
	state.invalidate(st)
	render.render(buf)

	local where = col and (" in " .. (st.headers[col] or col)) or ""
	vim.notify(
		string.format('Filter: "%s"%s — %d/%d rows match', pattern, where, state.get_total_visible_rows(st), #st.rows),
		vim.log.levels.INFO
	)
end

--- Prompt user for a search/filter pattern
---@param buf number Buffer number
function M.prompt_filter(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	vim.ui.input({
		prompt = "Filter rows: ",
		default = st.filter_pattern or "",
	}, function(input)
		if input == nil then
			return
		end
		if input == "" then
			M.clear_filter(buf)
			return
		end
		M.apply(buf, input, nil)
	end)
end

--- Prompt user for a column-specific filter
---@param buf number Buffer number
function M.prompt_column_filter(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	vim.ui.select(st.headers, {
		prompt = "Filter column:",
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		vim.ui.input({
			prompt = string.format("Filter '%s': ", choice),
			default = st.filter_column == idx and st.filter_pattern or "",
		}, function(input)
			if input == nil then
				return
			end
			if input == "" then
				M.clear_filter(buf)
				return
			end
			M.apply(buf, input, idx)
		end)
	end)
end

--- Clear the current filter
---@param buf number Buffer number
function M.clear_filter(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	if not st.filter_pattern then
		vim.notify("No active filter", vim.log.levels.INFO)
		return
	end

	st.filter_pattern = nil
	st.filter_column = nil
	st.current_page = 1
	state.invalidate(st)

	render.render(buf)
	vim.notify("Filter cleared", vim.log.levels.INFO)
end

return M
