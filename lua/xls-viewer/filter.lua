local M = {}

local state = require("xls-viewer.state")
local render = require("xls-viewer.render")

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
			return -- User cancelled
		end

		if input == "" then
			M.clear_filter(buf)
			return
		end

		st.filter_pattern = input
		st.filter_column = nil -- Search all columns
		st.current_page = 1 -- Reset to first page
		state.invalidate_filter(st)

		-- Re-render
		render.render(buf)

		-- Show result count
		local total_visible = state.get_total_visible_rows(st)
		vim.notify(
			string.format("Filter: \"%s\" — %d/%d rows match", input, total_visible, #st.rows),
			vim.log.levels.INFO
		)
	end)
end

--- Prompt user for a column-specific filter
---@param buf number Buffer number
function M.prompt_column_filter(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	-- First select column
	vim.ui.select(st.headers, {
		prompt = "Filter column:",
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		vim.ui.input({
			prompt = string.format("Filter '%s': ", choice),
			default = "",
		}, function(input)
			if input == nil or input == "" then
				return
			end

			st.filter_pattern = input
			st.filter_column = idx
			st.current_page = 1
			state.invalidate_filter(st)

			render.render(buf)

			local total_visible = state.get_total_visible_rows(st)
			vim.notify(
				string.format("Filter: \"%s\" in %s — %d/%d rows", input, choice, total_visible, #st.rows),
				vim.log.levels.INFO
			)
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
	state.invalidate_filter(st)

	render.render(buf)
	vim.notify("Filter cleared", vim.log.levels.INFO)
end

return M
