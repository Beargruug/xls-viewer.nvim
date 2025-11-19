local M = {}

M.config = require("xls-viewer.config")
M.open = require("xls-viewer.open")

-- Setup function
function M.setup(opts)
	M.config.set(opts)

	-- Create autocmd for XLS/XLSX files
	vim.api.nvim_create_autocmd({ "BufReadCmd" }, {
		pattern = { "*.xls", "*.xlsx" },
		callback = function()
			M.open.open_xls()
		end,
		group = vim.api.nvim_create_augroup("XLSViewer", { clear = true }),
	})
end

return M
