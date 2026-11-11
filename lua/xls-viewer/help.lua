-- Floating help window listing keymaps and commands
local M = {}

local ns = vim.api.nvim_create_namespace("xls_viewer_help")

-- Help window per viewer buffer
M.wins = {}

--- Build help lines and highlight ranges
---@return string[] lines
---@return table hls { {line, start_col, end_col, group}, ... } (0-based)
function M.build()
	local keymaps = require("xls-viewer.keymaps")
	local leader = vim.g.mapleader or "\\"
	local lines, hls = {}, {}

	local function display_key(lhs)
		return (lhs:gsub("<leader>", leader == " " and "<Space>" or leader))
	end

	local key_w = 0
	for _, s in ipairs(keymaps.SECTIONS) do
		for _, km in ipairs(s.keys) do
			key_w = math.max(key_w, vim.fn.strdisplaywidth(display_key(km[1])))
		end
	end
	for _, c in ipairs(keymaps.COMMANDS) do
		key_w = math.max(key_w, vim.fn.strdisplaywidth(c[1]))
	end

	local function heading(text)
		if #lines > 0 then
			lines[#lines + 1] = ""
		end
		lines[#lines + 1] = " " .. text
		hls[#hls + 1] = { #lines - 1, 0, #lines[#lines], "Title" }
	end

	local function entry(key, desc)
		local pad = string.rep(" ", key_w - vim.fn.strdisplaywidth(key))
		lines[#lines + 1] = "   " .. key .. pad .. "   " .. desc
		hls[#hls + 1] = { #lines - 1, 3, 3 + #key, "Special" }
	end

	for _, s in ipairs(keymaps.SECTIONS) do
		heading(s.section)
		for _, km in ipairs(s.keys) do
			entry(display_key(km[1]), km[3])
		end
	end
	heading("Commands")
	for _, c in ipairs(keymaps.COMMANDS) do
		entry(c[1], c[2])
	end

	lines[#lines + 1] = ""
	lines[#lines + 1] = " Press q, ? or <Esc> to close"
	hls[#hls + 1] = { #lines - 1, 0, #lines[#lines], "Comment" }
	return lines, hls
end

--- Close the help window for a viewer buffer
---@param buf number
function M.close(buf)
	local win = M.wins[buf]
	M.wins[buf] = nil
	if win and vim.api.nvim_win_is_valid(win) then
		vim.api.nvim_win_close(win, true)
	end
end

--- Open the help window
---@param buf number Viewer buffer
---@return number win
function M.open(buf)
	M.close(buf)
	local lines, hls = M.build()

	local width = 0
	for _, l in ipairs(lines) do
		width = math.max(width, vim.fn.strdisplaywidth(l))
	end
	width = math.min(width + 2, vim.o.columns - 4)
	local height = math.min(#lines, vim.o.lines - 4)

	local hbuf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(hbuf, 0, -1, false, lines)
	for _, h in ipairs(hls) do
		vim.api.nvim_buf_set_extmark(hbuf, ns, h[1], h[2], { end_row = h[1], end_col = h[3], hl_group = h[4] })
	end
	vim.bo[hbuf].modifiable = false
	vim.bo[hbuf].bufhidden = "wipe"
	vim.bo[hbuf].filetype = "xls-viewer-help"

	local win = vim.api.nvim_open_win(hbuf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
		title = " xls-viewer help ",
		title_pos = "center",
	})
	vim.wo[win].cursorline = false
	M.wins[buf] = win

	for _, lhs in ipairs({ "q", "?", "<Esc>" }) do
		vim.keymap.set("n", lhs, function()
			M.close(buf)
		end, { buffer = hbuf, nowait = true, silent = true })
	end
	-- Close when focus leaves the help window
	vim.api.nvim_create_autocmd("WinLeave", {
		buffer = hbuf,
		once = true,
		callback = function()
			vim.schedule(function()
				M.close(buf)
			end)
		end,
	})
	return win
end

--- Toggle the help window
---@param buf number
function M.toggle(buf)
	local win = M.wins[buf]
	if win and vim.api.nvim_win_is_valid(win) then
		M.close(buf)
	else
		M.open(buf)
	end
end

return M
