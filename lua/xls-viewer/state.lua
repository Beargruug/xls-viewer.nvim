local M = {}

-- Buffer-local state storage keyed by buffer number
M.buffers = {}

--- Create a new state for a buffer
---@param buf number Buffer number
---@param filepath string Path to the Excel file
---@return table state The new state object
function M.create(buf, filepath)
	M.buffers[buf] = {
		filepath = filepath,
		buf = buf,
		-- Sheet data
		sheet_names = {},
		current_sheet = nil, -- name of current sheet
		-- Raw data (2D array of strings)
		headers = {},
		rows = {},
		-- Total row count in the file (for pagination)
		total_rows = 0,
		-- Sort state
		sort_col = nil, -- column index (1-based)
		sort_dir = nil, -- "asc", "desc", or nil (none)
		-- Filter state
		filter_pattern = nil,
		filter_column = nil, -- nil = all columns, number = specific column
		filtered_rows = nil, -- cached filtered result
		-- Pagination state
		current_page = 1,
		page_size = require("xls-viewer.config").config.page_size,
		-- Column widths (computed during render)
		col_widths = {},
		-- Loading state
		loading = false,
		-- Type info per column (detected during parse)
		col_types = {}, -- { [col_index] = "number"|"date"|"boolean"|"string"|"null" }
	}
	return M.buffers[buf]
end

--- Get state for a buffer
---@param buf number|nil Buffer number (defaults to current)
---@return table|nil state
function M.get(buf)
	buf = buf or vim.api.nvim_get_current_buf()
	return M.buffers[buf]
end

--- Remove state for a buffer (cleanup)
---@param buf number Buffer number
function M.destroy(buf)
	M.buffers[buf] = nil
end

--- Get the visible rows after applying filter and pagination
---@param state table Buffer state
---@return table rows The rows to display
function M.get_visible_rows(state)
	local rows = state.rows

	-- Apply filter
	if state.filter_pattern and state.filter_pattern ~= "" then
		if not state.filtered_rows then
			state.filtered_rows = {}
			for _, row in ipairs(rows) do
				local match = false
				if state.filter_column then
					-- Filter specific column
					local cell = row[state.filter_column] or ""
					if cell:lower():find(state.filter_pattern:lower(), 1, true) then
						match = true
					end
				else
					-- Filter all columns
					for _, cell in ipairs(row) do
						if cell:lower():find(state.filter_pattern:lower(), 1, true) then
							match = true
							break
						end
					end
				end
				if match then
					table.insert(state.filtered_rows, row)
				end
			end
		end
		rows = state.filtered_rows
	end

	-- Apply sorting
	if state.sort_col and state.sort_dir then
		rows = M._sort_rows(rows, state.sort_col, state.sort_dir, state.col_types)
	end

	-- Apply pagination
	local page_size = state.page_size
	local start_idx = (state.current_page - 1) * page_size + 1
	local end_idx = math.min(start_idx + page_size - 1, #rows)

	local paged_rows = {}
	for i = start_idx, end_idx do
		table.insert(paged_rows, rows[i])
	end

	return paged_rows
end

--- Get total visible row count (after filter, before pagination)
---@param state table Buffer state
---@return number
function M.get_total_visible_rows(state)
	if state.filter_pattern and state.filter_pattern ~= "" then
		if not state.filtered_rows then
			-- Force computation
			M.get_visible_rows(state)
		end
		return #state.filtered_rows
	end
	return #state.rows
end

--- Get total number of pages
---@param state table Buffer state
---@return number
function M.get_total_pages(state)
	local total = M.get_total_visible_rows(state)
	return math.max(1, math.ceil(total / state.page_size))
end

--- Invalidate filtered cache (call when filter changes)
---@param state table Buffer state
function M.invalidate_filter(state)
	state.filtered_rows = nil
end

--- Sort rows by column
---@param rows table 2D array of rows
---@param col number Column index
---@param dir string "asc" or "desc"
---@param col_types table Column type info
---@return table sorted_rows
function M._sort_rows(rows, col, dir, col_types)
	local sorted = vim.deepcopy(rows)
	local col_type = col_types[col] or "string"

	table.sort(sorted, function(a, b)
		local va = a[col] or ""
		local vb = b[col] or ""

		-- Numeric sort
		if col_type == "number" then
			local na = tonumber(va)
			local nb = tonumber(vb)
			if na and nb then
				if dir == "asc" then
					return na < nb
				else
					return na > nb
				end
			end
		end

		-- String sort (default)
		if dir == "asc" then
			return va:lower() < vb:lower()
		else
			return va:lower() > vb:lower()
		end
	end)

	return sorted
end

--- Detect column types from data
---@param rows table 2D array of rows
---@return table col_types
function M.detect_types(rows)
	local col_types = {}
	if #rows == 0 then
		return col_types
	end

	local num_cols = 0
	for _, row in ipairs(rows) do
		if #row > num_cols then
			num_cols = #row
		end
	end

	for col = 1, num_cols do
		local counts = { number = 0, boolean = 0, date = 0, null = 0, string = 0 }
		local total = 0

		for _, row in ipairs(rows) do
			local cell = row[col] or ""
			total = total + 1

			if cell == "" or cell:lower() == "nan" or cell:lower() == "none" or cell:lower() == "null" then
				counts.null = counts.null + 1
			elseif tonumber(cell) then
				counts.number = counts.number + 1
			elseif cell:lower() == "true" or cell:lower() == "false" then
				counts.boolean = counts.boolean + 1
			elseif cell:match("^%d%d%d%d[%-/]%d%d[%-/]%d%d") then
				counts.date = counts.date + 1
			else
				counts.string = counts.string + 1
			end
		end

		-- Determine dominant type (excluding nulls)
		local non_null = total - counts.null
		if non_null == 0 then
			col_types[col] = "null"
		elseif counts.number / non_null > 0.8 then
			col_types[col] = "number"
		elseif counts.boolean / non_null > 0.8 then
			col_types[col] = "boolean"
		elseif counts.date / non_null > 0.8 then
			col_types[col] = "date"
		else
			col_types[col] = "string"
		end
	end

	return col_types
end

return M
