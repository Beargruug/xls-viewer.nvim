local M = {}

M.config = require("xls-viewer.config")
M.open = require("xls-viewer.open")

-- Setup function
function M.setup(opts)
	M.config.set(opts)

	-- Setup default highlight groups
	M.config.setup_highlights()

	-- Create autocmd for XLS/XLSX files
	vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
		pattern = { "*.xls", "*.xlsx" },
		callback = function()
			M.open.open_xls()
		end,
		group = vim.api.nvim_create_augroup("XLSViewer", { clear = true }),
	})

	-- User commands
	vim.api.nvim_create_user_command("XlsSheet", function()
		local buf = vim.api.nvim_get_current_buf()
		require("xls-viewer.sheets").select_sheet(buf)
	end, { desc = "Select sheet in XLS viewer" })

	vim.api.nvim_create_user_command("XlsSort", function(args)
		local buf = vim.api.nvim_get_current_buf()
		if args.args ~= "" then
			-- Sort by column name/number argument
			local st = require("xls-viewer.state").get(buf)
			if st then
				local col = tonumber(args.args)
				if not col then
					-- Try matching by header name
					for i, h in ipairs(st.headers) do
						if h:lower() == args.args:lower() then
							col = i
							break
						end
					end
				end
				if col then
					st.sort_col = col
					st.sort_dir = st.sort_dir == "asc" and "desc" or "asc"
					require("xls-viewer.state").invalidate_filter(st)
					require("xls-viewer.render").render(buf)
				else
					vim.notify("Column not found: " .. args.args, vim.log.levels.WARN)
				end
			end
		else
			require("xls-viewer.sort").sort_by_cursor(buf)
		end
	end, { nargs = "?", desc = "Sort by column in XLS viewer" })

	vim.api.nvim_create_user_command("XlsFilter", function(args)
		local buf = vim.api.nvim_get_current_buf()
		if args.args ~= "" then
			local st = require("xls-viewer.state").get(buf)
			if st then
				st.filter_pattern = args.args
				st.filter_column = nil
				st.current_page = 1
				require("xls-viewer.state").invalidate_filter(st)
				require("xls-viewer.render").render(buf)
			end
		else
			require("xls-viewer.filter").prompt_filter(buf)
		end
	end, { nargs = "?", desc = "Filter rows in XLS viewer" })

	vim.api.nvim_create_user_command("XlsFilterClear", function()
		local buf = vim.api.nvim_get_current_buf()
		require("xls-viewer.filter").clear_filter(buf)
	end, { desc = "Clear filter in XLS viewer" })

	vim.api.nvim_create_user_command("XlsGoto", function(args)
		local buf = vim.api.nvim_get_current_buf()
		if args.args ~= "" then
			-- Direct jump without prompt
			local st = require("xls-viewer.state").get(buf)
			if st then
				local nav = require("xls-viewer.navigate")
				local col, row = nav._parse_coordinate(args.args)
				if col and row then
					-- Perform the jump inline
					if col > #st.headers then
						vim.notify("Column out of range", vim.log.levels.WARN)
						return
					end
					if row > #st.rows then
						vim.notify("Row out of range", vim.log.levels.WARN)
						return
					end
					local target_page = math.ceil(row / st.page_size)
					if target_page ~= st.current_page then
						st.current_page = target_page
						require("xls-viewer.render").render(buf)
					end
					local row_in_page = row - (st.current_page - 1) * st.page_size
					local buf_line = row_in_page + 1
					local cfg = require("xls-viewer.config").config
					local byte_col = 0
					for i = 1, col - 1 do
						byte_col = byte_col + (st.col_widths[i] or 0) + cfg.padding + 3
					end
					local line_count = vim.api.nvim_buf_line_count(buf)
					if buf_line + 1 <= line_count then
						vim.api.nvim_win_set_cursor(0, { buf_line + 1, byte_col })
					end
				else
					vim.notify("Invalid coordinate: " .. args.args, vim.log.levels.WARN)
				end
			end
		else
			require("xls-viewer.navigate").goto_cell(buf)
		end
	end, { nargs = "?", desc = "Jump to cell in XLS viewer" })

	vim.api.nvim_create_user_command("XlsPage", function(args)
		local buf = vim.api.nvim_get_current_buf()
		if args.args == "next" or args.args == "+" then
			require("xls-viewer.paginate").next_page(buf)
		elseif args.args == "prev" or args.args == "-" then
			require("xls-viewer.paginate").prev_page(buf)
		elseif tonumber(args.args) then
			local st = require("xls-viewer.state").get(buf)
			if st then
				local page = tonumber(args.args)
				local total = require("xls-viewer.state").get_total_pages(st)
				if page >= 1 and page <= total then
					st.current_page = page
					require("xls-viewer.render").render(buf)
				else
					vim.notify(string.format("Invalid page. Range: 1-%d", total), vim.log.levels.WARN)
				end
			end
		else
			require("xls-viewer.paginate").goto_page(buf)
		end
	end, { nargs = "?", desc = "Navigate pages in XLS viewer" })
end

return M
