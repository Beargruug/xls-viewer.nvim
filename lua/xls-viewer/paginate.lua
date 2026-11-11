local M = {}

local state = require("xls-viewer.state")
local render = require("xls-viewer.render")

--- Go to a page (1-based) and re-render
---@param buf number
---@param page number
---@return boolean ok
function M.set_page(buf, page)
	local st = state.get(buf)
	if not st then
		return false
	end

	local total_pages = state.get_total_pages(st)
	page = math.floor(page)
	if page < 1 or page > total_pages then
		vim.notify(string.format("Invalid page. Range: 1-%d", total_pages), vim.log.levels.WARN)
		return false
	end

	st.current_page = page
	render.render(buf)
	pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
	vim.notify(string.format("Page %d/%d", page, total_pages), vim.log.levels.INFO)
	return true
end

--- Go to the next page
---@param buf number Buffer number
function M.next_page(buf)
	local st = state.get(buf)
	if not st then
		return
	end
	if st.current_page >= state.get_total_pages(st) then
		vim.notify("Already on last page", vim.log.levels.INFO)
		return
	end
	M.set_page(buf, st.current_page + 1)
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
	M.set_page(buf, st.current_page - 1)
end

--- Prompt to go to a specific page
---@param buf number Buffer number
function M.goto_page(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	vim.ui.input({
		prompt = string.format("Go to page (1-%d): ", state.get_total_pages(st)),
	}, function(input)
		if not input or input == "" then
			return
		end
		local page = tonumber(input)
		if not page then
			vim.notify("Not a number: " .. input, vim.log.levels.WARN)
			return
		end
		M.set_page(buf, page)
	end)
end

return M
