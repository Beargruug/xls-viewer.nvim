local M = {}

-- Default configuration
M.config = {
	python_cmd = "/usr/bin/python3",
	max_column_width = 50,
	min_column_width = 3,
	padding = 2,
}

function M.set(opts)
	M.config = vim.tbl_extend("force", M.config, opts or {})
end

return M
