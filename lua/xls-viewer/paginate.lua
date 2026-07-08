local M = {}

local state = require("xls-viewer.state")
local render = require("xls-viewer.render")

--- Go to the next page
---@param buf number Buffer number
function M.next_page(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	local total_pages = state.get_total_pages(st)
	if st.current_page >= total_pages then
		vim.notify("Already on last page", vim.log.levels.INFO)
		return
	end

	st.current_page = st.current_page + 1
	render.render(buf)
	vim.notify(string.format("Page %d/%d", st.current_page, total_pages), vim.log.levels.INFO)
end

--- Go to the previous page
---@param buf number Buffer number
function M.prev_page(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	if st.current_page <= 1 then
		vim.notify("Already on first page", vim.log.levels.INFO)
		return
	end

	st.current_page = st.current_page - 1
	local total_pages = state.get_total_pages(st)
	render.render(buf)
	vim.notify(string.format("Page %d/%d", st.current_page, total_pages), vim.log.levels.INFO)
end

--- Prompt to go to a specific page
---@param buf number Buffer number
function M.goto_page(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	local total_pages = state.get_total_pages(st)

	vim.ui.input({
		prompt = string.format("Go to page (1-%d): ", total_pages),
	}, function(input)
		if not input or input == "" then
			return
		end

		local page = tonumber(input)
		if not page or page < 1 or page > total_pages then
			vim.notify(string.format("Invalid page number. Must be 1-%d", total_pages), vim.log.levels.WARN)
			return
		end

		st.current_page = math.floor(page)
		render.render(buf)
		vim.notify(string.format("Page %d/%d", st.current_page, total_pages), vim.log.levels.INFO)
	end)
end

return M
