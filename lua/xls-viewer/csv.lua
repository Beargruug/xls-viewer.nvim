-- Pure-Lua CSV/TSV reading and writing (RFC 4180 quoting).
local M = {}

local CANDIDATES = { ",", ";", "\t", "|" }

--- Guess the delimiter from the first line (quoted sections ignored)
---@param text string
---@return string
function M.sniff(text)
	local first = text:match("^[^\r\n]*") or ""
	first = first:gsub('"[^"]*"', "")
	local best, best_count = ",", 0
	for _, d in ipairs(CANDIDATES) do
		local _, count = first:gsub(vim.pesc(d), "")
		if count > best_count then
			best, best_count = d, count
		end
	end
	return best
end

--- Parse delimited text into rows of cells
---@param text string
---@param delim string Single-character delimiter
---@return table rows
function M.parse(text, delim)
	local rows, row = {}, {}
	local i, n = 1, #text
	if text:sub(1, 3) == "\239\187\191" then
		i = 4 -- UTF-8 BOM
	end
	local stop = "[" .. vim.pesc(delim) .. "\r\n]"

	local function end_row()
		-- Skip blank lines (a single empty field)
		if not (#row == 1 and row[1] == "") then
			rows[#rows + 1] = row
		end
		row = {}
	end

	while i <= n do
		local field
		if text:sub(i, i) == '"' then
			local parts = {}
			local j = i + 1
			while true do
				local q = text:find('"', j, true)
				if not q then
					parts[#parts + 1] = text:sub(j)
					i = n + 1
					break
				end
				parts[#parts + 1] = text:sub(j, q - 1)
				if text:sub(q + 1, q + 1) == '"' then
					parts[#parts + 1] = '"'
					j = q + 2
				else
					i = q + 1
					break
				end
			end
			field = table.concat(parts)
			-- Lenient: keep any stray characters between the closing quote and the delimiter
			local k = text:find(stop, i) or n + 1
			field = field .. text:sub(i, k - 1)
			i = k
		else
			local k = text:find(stop, i) or n + 1
			field = text:sub(i, k - 1)
			i = k
		end
		row[#row + 1] = field

		local c = text:sub(i, i)
		if c == delim then
			i = i + 1
			if i > n then
				row[#row + 1] = "" -- trailing delimiter at EOF
			end
		elseif c == "\r" or c == "\n" then
			i = i + ((c == "\r" and text:sub(i + 1, i + 1) == "\n") and 2 or 1)
			end_row()
		end
	end
	if #row > 0 then
		end_row()
	end
	return rows
end

--- Delimiter for a file path
---@param filepath string
---@param text string|nil File content for sniffing
---@return string
function M.delimiter_for(filepath, text)
	local ext = vim.fn.fnamemodify(filepath, ":e"):lower()
	if ext == "tsv" or ext == "tab" then
		return "\t"
	end
	return text and M.sniff(text) or ","
end

--- Loader with the same contract as open.load_excel
---@param filepath string
---@param _ any sheet (ignored, CSV has one sheet)
---@param callback fun(data: table|nil, err: string|nil)
function M.load(filepath, _, callback)
	local f, err = io.open(filepath, "rb")
	if not f then
		callback(nil, "Cannot read file: " .. tostring(err))
		return
	end
	local text = f:read("*a")
	f:close()

	local ok, rows = pcall(M.parse, text, M.delimiter_for(filepath, text))
	if not ok then
		callback(nil, "Failed to parse: " .. tostring(rows))
		return
	end

	local headers = table.remove(rows, 1) or {}
	local name = vim.fn.fnamemodify(filepath, ":t")
	callback({ sheet_names = { name }, sheet = name, headers = headers, rows = rows }, nil)
end

--- Encode one row for writing
---@param cells table
---@param delim string
---@return string
function M.encode_row(cells, delim)
	local out = {}
	for i, cell in ipairs(cells) do
		cell = tostring(cell or "")
		if cell:find('[\r\n"]') or cell:find(delim, 1, true) then
			cell = '"' .. cell:gsub('"', '""') .. '"'
		end
		out[i] = cell
	end
	return table.concat(out, delim)
end

return M
