local M = {}

local config = require("xls-viewer.config")
local state = require("xls-viewer.state")
local render = require("xls-viewer.render")
local python = require("xls-viewer.python")

-- argv[1] = path, argv[2] = "name" | "index", argv[3] = sheet name or 0-based index
-- Prints one JSON object: { sheet_names, sheet, headers, rows } with all cells as strings.
M.EXCEL_SCRIPT = [[
import sys, json, datetime
try:
    import pandas as pd
except ImportError as e:
    print(f"{type(e).__name__}: {e}", file=sys.stderr)
    sys.exit(3)

def fmt(v):
    if v is None:
        return ""
    if isinstance(v, str):
        return v
    try:
        if pd.isna(v):
            return ""
    except (TypeError, ValueError):
        pass
    if isinstance(v, bool):
        return str(v)
    if isinstance(v, float) and v.is_integer() and abs(v) < 1e15:
        return str(int(v))
    if isinstance(v, datetime.datetime):
        if (v.hour, v.minute, v.second, v.microsecond) == (0, 0, 0, 0):
            return v.strftime("%Y-%m-%d")
        return v.isoformat(sep=" ")
    return str(v)

try:
    path, mode, spec = sys.argv[1], sys.argv[2], sys.argv[3]
    xls = pd.ExcelFile(path)
    names = [str(n) for n in xls.sheet_names]
    if not names:
        raise ValueError("No sheets found in file")
    if mode == "name" and spec in names:
        idx = names.index(spec)
    elif mode == "index" and spec.isdigit() and int(spec) < len(names):
        idx = int(spec)
    else:
        idx = 0
    df = xls.parse(xls.sheet_names[idx], dtype=object)
    print(json.dumps({
        "sheet_names": names,
        "sheet": names[idx],
        "headers": [fmt(c) for c in df.columns],
        "rows": [[fmt(v) for v in row] for row in df.itertuples(index=False, name=None)],
    }))
except ImportError as e:
    print(f"{type(e).__name__}: {e}", file=sys.stderr)
    sys.exit(3)
except Exception as e:
    print(f"{type(e).__name__}: {e}", file=sys.stderr)
    sys.exit(1)
]]

--- Make a cell safe for a single buffer line
---@param cell any
---@return string
function M.sanitize(cell)
	if type(cell) ~= "string" then
		cell = cell == vim.NIL and "" or tostring(cell)
	end
	if cell:find("[\r\n\t]") then
		cell = cell:gsub("\r\n", "↵"):gsub("[\r\n]", "↵"):gsub("\t", " ")
	end
	return cell
end

--- Load an Excel sheet via Python
---@param filepath string
---@param sheet string|number|nil Sheet name or 0-based index (nil = config default)
---@param callback fun(data: table|nil, err: string|nil) data = { sheet_names, sheet, headers, rows }
function M.load_excel(filepath, sheet, callback)
	if sheet == nil then
		sheet = config.config.default_sheet
	end
	local mode = type(sheet) == "string" and "name" or "index"

	python.run(M.EXCEL_SCRIPT, { filepath, mode, tostring(sheet or 0) }, nil, function(output, err)
		if err then
			callback(nil, err)
			return
		end
		local ok, data = pcall(vim.json.decode, output)
		if not ok or type(data) ~= "table" then
			callback(nil, "Failed to parse loader output: " .. tostring(output):sub(1, 200))
			return
		end
		for i, h in ipairs(data.headers) do
			data.headers[i] = M.sanitize(h)
		end
		for _, row in ipairs(data.rows) do
			for i, cell in ipairs(row) do
				row[i] = M.sanitize(cell)
			end
		end
		callback(data, nil)
	end)
end

--- Pick the loader for a file
---@param filepath string
---@return fun(filepath: string, sheet: any, callback: function)
function M.loader_for(filepath)
	return M.load_excel
end

--- Load a sheet into the buffer and render it
---@param buf number Buffer number
---@param sheet string|number|nil Sheet name, 0-based index, or nil for default
function M.load_sheet(buf, sheet)
	local st = state.get(buf)
	if not st then
		return
	end
	st.loading = true

	M.loader_for(st.filepath)(st.filepath, sheet, function(data, err)
		if not vim.api.nvim_buf_is_valid(buf) or state.get(buf) ~= st then
			return
		end
		st.loading = false
		if err then
			if #st.headers == 0 then
				render.message(buf, {
					"xls-viewer: failed to load " .. vim.fn.fnamemodify(st.filepath, ":t"),
					"",
					err,
				}, "ErrorMsg")
			end
			vim.notify("xls-viewer: " .. err, vim.log.levels.ERROR)
			return
		end

		st.sheet_names = data.sheet_names or {}
		state.set_data(st, data.sheet, data.headers or {}, data.rows or {})
		render.render(buf)
		pcall(vim.api.nvim_win_set_cursor, 0, { 1, 0 })
	end)
end

--- Entry point for BufReadCmd: turn the file's own buffer into the viewer
function M.open_xls()
	local buf = tonumber(vim.fn.expand("<abuf>")) or vim.api.nvim_get_current_buf()
	local filepath = vim.fn.expand("<afile>:p")

	local bo = vim.bo[buf]
	bo.buftype = "nofile"
	bo.bufhidden = "wipe"
	bo.swapfile = false
	bo.undolevels = -1
	bo.filetype = "xls-viewer"

	render.message(buf, { "Loading " .. vim.fn.fnamemodify(filepath, ":t") .. "..." }, "Comment")

	state.create(buf, filepath)

	local group = vim.api.nvim_create_augroup("XLSViewerBuf" .. buf, { clear = true })
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = group,
		buffer = buf,
		callback = function()
			state.destroy(buf)
			pcall(vim.api.nvim_del_augroup_by_id, group)
		end,
	})

	M._setup_keymaps(buf)
	M.load_sheet(buf, nil)
end

--- Setup buffer-local keymaps
---@param buf number Buffer number
function M._setup_keymaps(buf)
	local function map(lhs, fn, desc)
		vim.keymap.set("n", lhs, fn, { buffer = buf, silent = true, nowait = true, desc = "xls-viewer: " .. desc })
	end

	map("q", "<cmd>bdelete<CR>", "Close")
	map("<C-c>", "<cmd>bdelete<CR>", "Close")
	map("gs", function()
		require("xls-viewer.sheets").select_sheet(buf)
	end, "Select sheet")
	map("s", function()
		require("xls-viewer.sort").sort_by_cursor(buf)
	end, "Sort by column")
	map("/", function()
		require("xls-viewer.filter").prompt_filter(buf)
	end, "Filter rows")
	map("g/", function()
		require("xls-viewer.filter").prompt_column_filter(buf)
	end, "Filter column")
	map("<leader>F", function()
		require("xls-viewer.filter").clear_filter(buf)
	end, "Clear filter")
	map("gc", function()
		require("xls-viewer.navigate").goto_cell(buf)
	end, "Go to cell")
	map("]p", function()
		require("xls-viewer.paginate").next_page(buf)
	end, "Next page")
	map("[p", function()
		require("xls-viewer.paginate").prev_page(buf)
	end, "Previous page")
	map("gp", function()
		require("xls-viewer.paginate").goto_page(buf)
	end, "Go to page")
end

return M
