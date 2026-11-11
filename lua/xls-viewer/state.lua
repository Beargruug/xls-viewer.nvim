local M = {}

-- Buffer-local state storage keyed by buffer number
M.buffers = {}

--- Create a new state for a buffer
---@param buf number Buffer number
---@param filepath string Path to the file
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
		-- Sort state
		sort_col = nil, -- column index (1-based)
		sort_dir = nil, -- "asc", "desc", or nil (none)
		-- Filter state
		filter_pattern = nil,
		filter_column = nil, -- nil = all columns, number = specific column
		view_rows = nil, -- cached filtered + sorted rows
		-- Pagination state
		current_page = 1,
		page_size = require("xls-viewer.config").config.page_size,
		-- Column widths (computed during render)
		col_widths = {},
		-- User width overrides per column (interactive resizing)
		width_overrides = {},
		-- Byte slots per rendered line: { [lnum] = { {start, end}, ... } }
		line_slots = {},
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

--- Load new sheet data into state and reset view settings
---@param st table Buffer state
---@param sheet string Sheet name
---@param headers table
---@param rows table
function M.set_data(st, sheet, headers, rows)
	st.current_sheet = sheet
	st.headers = headers
	st.rows = rows
	st.loading = false
	st.current_page = 1
	st.filter_pattern = nil
	st.filter_column = nil
	st.sort_col = nil
	st.sort_dir = nil
	st.width_overrides = {}
	st.col_types = M.detect_types(rows)
	M.invalidate(st)
end

---@param cell string
---@return boolean
function M.is_null(cell)
	if cell == "" then
		return true
	end
	local l = cell:lower()
	return l == "nan" or l == "none" or l == "null"
end

--- Get rows after filter and sort (all pages), cached
---@param st table Buffer state
---@return table rows
function M.get_view_rows(st)
	if st.view_rows then
		return st.view_rows
	end

	local rows = st.rows

	if st.filter_pattern and st.filter_pattern ~= "" then
		local pattern = st.filter_pattern:lower()
		local filtered = {}
		for _, row in ipairs(rows) do
			local match = false
			if st.filter_column then
				local cell = row[st.filter_column] or ""
				match = cell:lower():find(pattern, 1, true) ~= nil
			else
				for _, cell in ipairs(row) do
					if cell:lower():find(pattern, 1, true) then
						match = true
						break
					end
				end
			end
			if match then
				table.insert(filtered, row)
			end
		end
		rows = filtered
	end

	if st.sort_col and st.sort_dir then
		rows = M._sort_rows(rows, st.sort_col, st.sort_dir, st.col_types)
	end

	st.view_rows = rows
	return rows
end

--- Get the rows of the current page
---@param st table Buffer state
---@return table rows
function M.get_page_rows(st)
	local rows = M.get_view_rows(st)
	local start_idx = (st.current_page - 1) * st.page_size + 1
	local end_idx = math.min(start_idx + st.page_size - 1, #rows)
	local paged = {}
	for i = start_idx, end_idx do
		paged[#paged + 1] = rows[i]
	end
	return paged
end

--- Total row count after filter (before pagination)
---@param st table Buffer state
---@return number
function M.get_total_visible_rows(st)
	return #M.get_view_rows(st)
end

--- Get total number of pages
---@param st table Buffer state
---@return number
function M.get_total_pages(st)
	return math.max(1, math.ceil(M.get_total_visible_rows(st) / st.page_size))
end

--- Invalidate the view cache (call when filter or sort changes)
---@param st table Buffer state
function M.invalidate(st)
	st.view_rows = nil
end

--- Sort rows by column. Stable; nulls always last; returns a new table.
---@param rows table 2D array of rows
---@param col number Column index
---@param dir string "asc" or "desc"
---@param col_types table Column type info
---@return table sorted_rows
function M._sort_rows(rows, col, dir, col_types)
	local numeric = (col_types[col] or "string") == "number"

	-- Precompute keys: { row, is_null, kind (0=number, 1=string), value, index }
	local keyed = {}
	for i, row in ipairs(rows) do
		local cell = row[col] or ""
		local null = M.is_null(cell)
		local num = numeric and not null and tonumber(cell) or nil
		keyed[i] = {
			row = row,
			null = null,
			kind = num and 0 or 1,
			value = num or cell:lower(),
			index = i,
		}
	end

	local desc = dir == "desc"
	table.sort(keyed, function(a, b)
		if a.null ~= b.null then
			return b.null -- nulls last regardless of direction
		end
		if not a.null then
			if a.kind ~= b.kind then
				return a.kind < b.kind -- numbers before text
			end
			if a.value ~= b.value then
				if desc then
					return a.value > b.value
				end
				return a.value < b.value
			end
		end
		return a.index < b.index
	end)

	local sorted = {}
	for i, k in ipairs(keyed) do
		sorted[i] = k.row
	end
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
		local counts = { number = 0, boolean = 0, date = 0, string = 0 }
		local non_null = 0

		for _, row in ipairs(rows) do
			local cell = row[col] or ""
			if not M.is_null(cell) then
				non_null = non_null + 1
				local l = cell:lower()
				if tonumber(cell) then
					counts.number = counts.number + 1
				elseif l == "true" or l == "false" then
					counts.boolean = counts.boolean + 1
				elseif cell:match("^%d%d%d%d[%-/]%d%d[%-/]%d%d") then
					counts.date = counts.date + 1
				else
					counts.string = counts.string + 1
				end
			end
		end

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
