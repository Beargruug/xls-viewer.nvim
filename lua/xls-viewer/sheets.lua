local M = {}

local state = require("xls-viewer.state")
local open = require("xls-viewer.open")

--- Open sheet selection UI
---@param buf number Buffer number
function M.select_sheet(buf)
	local st = state.get(buf)
	if not st then
		return
	end

	if #st.sheet_names == 0 then
		vim.notify("No sheets available", vim.log.levels.WARN)
		return
	end

	if #st.sheet_names == 1 then
		vim.notify("Only one sheet in this file", vim.log.levels.INFO)
		return
	end

	-- Build options with current sheet indicator
	local options = {}
	for _, name in ipairs(st.sheet_names) do
		if name == st.current_sheet then
			table.insert(options, name .. " (current)")
		else
			table.insert(options, name)
		end
	end

	vim.ui.select(options, {
		prompt = "Select sheet:",
		format_item = function(item)
			return item
		end,
	}, function(choice, idx)
		if not choice or not idx then
			return
		end

		local sheet_name = st.sheet_names[idx]
		if sheet_name == st.current_sheet then
			return -- Already on this sheet
		end

		-- Load the new sheet
		open.load_sheet(buf, sheet_name)
	end)
end

return M
