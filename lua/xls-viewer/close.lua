-- Closing the viewer without leaving an empty buffer behind
local M = {}

local config = require("xls-viewer.config")

--- Buffer to show after the viewer goes away, if any
---@param buf number Viewer buffer
---@return number|nil
function M.return_target(buf)
	local alt = vim.fn.bufnr("#")
	if alt > 0 and alt ~= buf and vim.api.nvim_buf_is_valid(alt) and vim.api.nvim_buf_is_loaded(alt) then
		return alt
	end

	local best, best_used = nil, -1
	for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
		if info.bufnr ~= buf and info.lastused > best_used then
			best, best_used = info.bufnr, info.lastused
		end
	end
	return best
end

--- Decide what closing does
---@param buf number Viewer buffer
---@return string action "switch" | "close_window" | "quit" | "delete"
---@return number|nil target Buffer for "switch"
function M.plan(buf)
	local target = M.return_target(buf)
	if target then
		return "switch", target
	end
	if not config.config.quit_on_close then
		return "delete", nil
	end
	local wins = vim.tbl_filter(function(w)
		return vim.api.nvim_win_get_config(w).relative == ""
	end, vim.api.nvim_tabpage_list_wins(0))
	if #wins > 1 then
		return "close_window", nil
	end
	return "quit", nil
end

--- Close the viewer in the current window
---@param buf number Viewer buffer
function M.close(buf)
	require("xls-viewer.help").close(buf)
	local action, target = M.plan(buf)
	local win = vim.api.nvim_get_current_win()

	if action == "switch" then
		vim.api.nvim_win_set_buf(win, target)
	elseif action == "close_window" then
		vim.api.nvim_win_close(win, false)
	elseif action == "quit" then
		-- Closes the tab if there are others, otherwise exits Neovim
		if pcall(vim.cmd.quit) then
			return
		end
	end

	-- bufhidden=wipe usually removes it already; make sure unless shown elsewhere
	if vim.api.nvim_buf_is_valid(buf) and #vim.fn.win_findbuf(buf) == 0 then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	elseif action == "delete" or action == "quit" then
		pcall(vim.cmd.bdelete, buf)
	end
end

return M
