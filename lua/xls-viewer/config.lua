local M = {}

-- Default configuration
M.config = {
	python_cmd = "/usr/bin/python3",
	max_column_width = 50,
	min_column_width = 3,
	padding = 2,
	-- Sheet selection
	default_sheet = 0, -- 0 = first sheet, or sheet name string
	-- Pagination
	page_size = 500,
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
	M.config = vim.tbl_deep_extend("force", M.config, opts or {})
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
