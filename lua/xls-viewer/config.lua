local M = {}

-- Default configuration
M.config = {
	-- Python interpreter. nil = auto-detect: tries g:python3_host_prog, python3
	-- on $PATH, then common install locations, and uses the first with pandas.
	python_cmd = nil,
	-- File extensions handled by the viewer
	filetypes = { "xls", "xlsx", "xlsm" },
	max_column_width = 50,
	min_column_width = 3,
	padding = 2,
	-- Sheet selection
	default_sheet = 0, -- 0 = first sheet, or sheet name string
	-- Pagination
	page_size = 500,
	-- Show each column's detected type (# number, D date, B bool, T text, ∅ empty)
	-- on the line under the header
	type_indicators = true,
	-- `q` when the viewer is the only thing open: true = quit the window
	-- (exits Neovim if it's the last one), false = just delete the buffer
	quit_on_close = true,
	-- Async loading
	async = true,
	-- Highlight groups for data types
	highlights = {
		header = "XlsHeader",
		number = "XlsNumber",
		date = "XlsDate",
		boolean = "XlsBoolean",
		null = "XlsNull",
		string = "XlsString",
		separator = "XlsSeparator",
	},
}

function M.set(opts)
	opts = opts or {}
	M.config = vim.tbl_deep_extend("force", M.config, opts)
	-- Lists should replace, not merge by index
	if opts.filetypes then
		M.config.filetypes = opts.filetypes
	end
end

--- Setup default highlight groups (linked to standard groups)
function M.setup_highlights()
	local links = {
		XlsHeader = "Title",
		XlsNumber = "Number",
		XlsDate = "Special",
		XlsBoolean = "Boolean",
		XlsNull = "Comment",
		XlsString = "Normal",
		XlsSeparator = "NonText",
	}
	for group, link in pairs(links) do
		vim.api.nvim_set_hl(0, group, { link = link, default = true })
	end
end

return M
