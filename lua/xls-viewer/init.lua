local M = {}

M.config = require("xls-viewer.config")
M.open = require("xls-viewer.open")

--- Run fn(buf, args) only if the current buffer is a viewer buffer
local function in_viewer(fn)
	return function(args)
		local buf = vim.api.nvim_get_current_buf()
		if not require("xls-viewer.state").get(buf) then
			vim.notify("Not an xls-viewer buffer", vim.log.levels.WARN)
			return
		end
		fn(buf, vim.trim(args.args or ""))
	end
end

-- Setup function
function M.setup(opts)
	M.config.set(opts)
	M.config.setup_highlights()

	local group = vim.api.nvim_create_augroup("XLSViewer", { clear = true })

	local patterns = {}
	for _, ext in ipairs(M.config.config.filetypes) do
		table.insert(patterns, "*." .. ext)
		-- With 'fileignorecase' (macOS default) one pattern already matches both cases
		if not vim.o.fileignorecase and ext:upper() ~= ext then
			table.insert(patterns, "*." .. ext:upper())
		end
	end

	vim.api.nvim_create_autocmd("BufReadCmd", {
		group = group,
		pattern = patterns,
		callback = function()
			M.open.open_xls()
		end,
	})

	-- Re-apply default links after a colorscheme change clears them
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = group,
		callback = M.config.setup_highlights,
	})

	local cmd = vim.api.nvim_create_user_command

	cmd(
		"XlsSheet",
		in_viewer(function(buf)
			require("xls-viewer.sheets").select_sheet(buf)
		end),
		{ desc = "Select sheet in XLS viewer" }
	)

	cmd(
		"XlsSort",
		in_viewer(function(buf, arg)
			require("xls-viewer.sort").command(buf, arg)
		end),
		{ nargs = "?", desc = "Sort by column in XLS viewer" }
	)

	cmd(
		"XlsFilter",
		in_viewer(function(buf, arg)
			if arg ~= "" then
				require("xls-viewer.filter").apply(buf, arg, nil)
			else
				require("xls-viewer.filter").prompt_filter(buf)
			end
		end),
		{ nargs = "?", desc = "Filter rows in XLS viewer" }
	)

	cmd(
		"XlsFilterClear",
		in_viewer(function(buf)
			require("xls-viewer.filter").clear_filter(buf)
		end),
		{ desc = "Clear filter in XLS viewer" }
	)

	cmd(
		"XlsGoto",
		in_viewer(function(buf, arg)
			if arg ~= "" then
				require("xls-viewer.navigate").jump(buf, arg)
			else
				require("xls-viewer.navigate").goto_cell(buf)
			end
		end),
		{ nargs = "?", desc = "Jump to cell in XLS viewer" }
	)

	cmd(
		"XlsPage",
		in_viewer(function(buf, arg)
			local paginate = require("xls-viewer.paginate")
			if arg == "next" or arg == "+" then
				paginate.next_page(buf)
			elseif arg == "prev" or arg == "-" then
				paginate.prev_page(buf)
			elseif tonumber(arg) then
				paginate.set_page(buf, tonumber(arg))
			else
				paginate.goto_page(buf)
			end
		end),
		{ nargs = "?", desc = "Navigate pages in XLS viewer" }
	)
end

return M
