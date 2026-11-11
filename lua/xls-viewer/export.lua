-- Export the current view (filter + sort applied, all pages)
local M = {}

local state = require("xls-viewer.state")
local csv = require("xls-viewer.csv")
local python = require("xls-viewer.python")

-- stdin: JSON { headers, rows, sheet, types }; argv[1] = output path
M.XLSX_SCRIPT = [[
import sys, json
try:
    import pandas as pd
except ImportError as e:
    print(f"{type(e).__name__}: {e}", file=sys.stderr)
    sys.exit(3)
try:
    data = json.load(sys.stdin)
    df = pd.DataFrame(data["rows"], columns=data["headers"])
    for i, kind in enumerate(data["types"]):
        if kind not in ("number", "date"):
            continue
        col = df.iloc[:, i]
        col = col.mask(col == "")
        try:
            col = pd.to_numeric(col) if kind == "number" else pd.to_datetime(col)
        except Exception:
            continue
        if hasattr(df, "isetitem"):
            df.isetitem(i, col)
        else:
            df.iloc[:, i] = col
    df.to_excel(sys.argv[1], sheet_name=(data["sheet"] or "Sheet1")[:31], index=False)
except ImportError as e:
    print(f"{type(e).__name__}: {e}", file=sys.stderr)
    sys.exit(3)
except Exception as e:
    print(f"{type(e).__name__}: {e}", file=sys.stderr)
    sys.exit(1)
]]

--- Rectangular copy of headers + view rows
---@param st table
---@return table headers, table rows
function M.collect(st)
	local rows = state.get_view_rows(st)
	local width = #st.headers
	for _, row in ipairs(rows) do
		width = math.max(width, #row)
	end

	local headers = {}
	for i = 1, width do
		headers[i] = st.headers[i] or ("Column " .. i)
	end

	local out = {}
	for r, row in ipairs(rows) do
		local copy = {}
		for i = 1, width do
			copy[i] = row[i] or ""
		end
		out[r] = copy
	end
	return headers, out
end

--- Default export path next to the source file
---@param st table
---@return string
function M.default_path(st)
	local dir = vim.fn.fnamemodify(st.filepath, ":h")
	local name = vim.fn.fnamemodify(st.filepath, ":t:r")
	local sheet = (st.current_sheet or ""):gsub("[^%w%-_]+", "_")
	local base = name
	if sheet ~= "" and st.current_sheet ~= vim.fn.fnamemodify(st.filepath, ":t") then
		base = base .. "_" .. sheet
	end
	return dir .. "/" .. base .. "_export.csv"
end

---@param path string
---@param headers table
---@param rows table
---@param delim string
---@return boolean ok, string|nil err
local function write_text(path, headers, rows, delim)
	local lines = { csv.encode_row(headers, delim) }
	for _, row in ipairs(rows) do
		lines[#lines + 1] = csv.encode_row(row, delim)
	end
	local f, err = io.open(path, "wb")
	if not f then
		return false, err
	end
	f:write(table.concat(lines, "\n"), "\n")
	f:close()
	return true
end

--- Write the current view to a file
---@param buf number
---@param path string
---@param force boolean|nil Overwrite without asking
function M.export(buf, path, force)
	local st = state.get(buf)
	if not st then
		return
	end

	path = vim.fn.fnamemodify(vim.fn.expand(path), ":p")
	local ext = vim.fn.fnamemodify(path, ":e"):lower()
	if ext ~= "csv" and ext ~= "tsv" and ext ~= "xlsx" then
		vim.notify("Export supports .csv, .tsv and .xlsx", vim.log.levels.WARN)
		return
	end
	if path == st.filepath then
		vim.notify("Refusing to overwrite the file being viewed", vim.log.levels.WARN)
		return
	end
	if not force and vim.fn.filereadable(path) == 1 then
		if vim.fn.confirm("Overwrite " .. path .. "?", "&Yes\n&No", 2) ~= 1 then
			return
		end
	end

	local headers, rows = M.collect(st)
	local done = string.format("Exported %d rows to %s", #rows, vim.fn.fnamemodify(path, ":~:."))

	if ext == "xlsx" then
		local types = {}
		for i = 1, #headers do
			types[i] = st.col_types[i] or "string"
		end
		local input = vim.json.encode({ headers = headers, rows = rows, sheet = st.current_sheet, types = types })
		python.run(M.XLSX_SCRIPT, { path }, input, function(_, err)
			if err then
				vim.notify("Export failed: " .. err, vim.log.levels.ERROR)
			else
				vim.notify(done, vim.log.levels.INFO)
			end
		end)
		return
	end

	local ok, err = write_text(path, headers, rows, ext == "tsv" and "\t" or ",")
	if ok then
		vim.notify(done, vim.log.levels.INFO)
	else
		vim.notify("Export failed: " .. tostring(err), vim.log.levels.ERROR)
	end
end

--- Prompt for a path, then export
---@param buf number
function M.prompt(buf)
	local st = state.get(buf)
	if not st then
		return
	end
	vim.ui.input({
		prompt = "Export view to (.csv/.tsv/.xlsx): ",
		default = M.default_path(st),
		completion = "file",
	}, function(input)
		if input and input ~= "" then
			M.export(buf, input, false)
		end
	end)
end

return M
