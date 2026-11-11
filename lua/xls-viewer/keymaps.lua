-- Single source of truth for buffer keymaps; the help window renders from this too.
local M = {}

local function mod(name)
	return require("xls-viewer." .. name)
end

local function resize_step(sign)
	return function(buf)
		mod("resize").resize(buf, sign * vim.v.count1 * mod("resize").STEP)
	end
end

---@type { section: string, keys: { [1]: string, [2]: fun(buf: number), [3]: string }[] }[]
M.SECTIONS = {
	{
		section = "General",
		keys = {
			{
				"?",
				function(buf)
					mod("help").toggle(buf)
				end,
				"Show this help",
			},
			{
				"q",
				function(buf)
					mod("close").close(buf)
				end,
				"Close viewer (quits if nothing else is open)",
			},
			{
				"<C-c>",
				function(buf)
					mod("close").close(buf)
				end,
				"Close viewer",
			},
			{
				"gs",
				function(buf)
					mod("sheets").select_sheet(buf)
				end,
				"Select sheet",
			},
		},
	},
	{
		section = "Sort & filter",
		keys = {
			{
				"s",
				function(buf)
					mod("sort").sort_by_cursor(buf)
				end,
				"Sort by column (asc → desc → off)",
			},
			{
				"/",
				function(buf)
					mod("filter").prompt_filter(buf)
				end,
				"Filter rows (all columns)",
			},
			{
				"g/",
				function(buf)
					mod("filter").prompt_column_filter(buf)
				end,
				"Filter a single column",
			},
			{
				"<leader>F",
				function(buf)
					mod("filter").clear_filter(buf)
				end,
				"Clear filter",
			},
		},
	},
	{
		section = "Navigation",
		keys = {
			{
				"gc",
				function(buf)
					mod("navigate").goto_cell(buf)
				end,
				"Go to cell (e.g. B5)",
			},
			{
				"]p",
				function(buf)
					mod("paginate").next_page(buf)
				end,
				"Next page",
			},
			{
				"[p",
				function(buf)
					mod("paginate").prev_page(buf)
				end,
				"Previous page",
			},
			{
				"gp",
				function(buf)
					mod("paginate").goto_page(buf)
				end,
				"Go to page",
			},
		},
	},
	{
		section = "Columns",
		keys = {
			{ ">", resize_step(1), "Widen column (count: 5>)" },
			{ "<", resize_step(-1), "Narrow column (count: 5<)" },
			{
				"=",
				function(buf)
					mod("resize").reset(buf, false)
				end,
				"Reset column width",
			},
			{
				"g=",
				function(buf)
					mod("resize").reset(buf, true)
				end,
				"Reset all column widths",
			},
		},
	},
}

M.COMMANDS = {
	{ ":XlsSheet", "Select sheet" },
	{ ":XlsSort [col]", "Sort by column name or number" },
	{ ":XlsFilter [text]", "Filter rows" },
	{ ":XlsFilterClear", "Clear filter" },
	{ ":XlsGoto [B5]", "Jump to cell" },
	{ ":XlsPage [n|next|prev]", "Go to page" },
	{ ":XlsExport[!] [path]", "Export view to .csv/.tsv/.xlsx" },
}

--- Set buffer-local keymaps
---@param buf number
function M.setup(buf)
	for _, section in ipairs(M.SECTIONS) do
		for _, km in ipairs(section.keys) do
			local fn = km[2]
			vim.keymap.set("n", km[1], function()
				fn(buf)
			end, { buffer = buf, silent = true, nowait = true, desc = "xls-viewer: " .. km[3] })
		end
	end
end

return M
