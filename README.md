# 📊 xls-viewer.nvim

A Neovim plugin for viewing Excel (`.xls`, `.xlsx`, `.xlsm`) and CSV/TSV files directly in your editor with beautiful column alignment, syntax highlighting, multi-sheet support, sorting, filtering, and pagination.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-green.svg)

## ✨ Features

- 🔍 **Automatic Detection** - Opens Excel files automatically when you open `.xls`, `.xlsx` or `.xlsm` files
- 🧾 **CSV/TSV Support** - Opt-in, parsed in pure Lua (no Python needed); `,`/`;` delimiter auto-detected
- 📑 **Multi-Sheet Support** - Browse and switch between sheets with `vim.ui.select`
- 📐 **Column Alignment** - Perfectly aligned columns (Unicode-aware) with configurable widths
- ↔️ **Column Resizing** - Widen/narrow the column under the cursor with `>` / `<`
- 🏷️ **Type Indicators** - Detected column type shown under each header
- 💾 **Export** - Save the filtered/sorted view as `.csv`, `.tsv` or `.xlsx`
- 🎨 **Syntax Highlighting** - Color-coded cells based on data type (numbers, dates, booleans, nulls)
- 🔀 **Column Sorting** - Sort by any column (cursor-based), cycles through asc/desc/none
- 🔎 **Search & Filter** - Filter rows by pattern across all columns or a specific column
- 📍 **Cell Navigation** - Jump to any cell by spreadsheet coordinate (e.g., `B5`, `AA12`)
- 📄 **Pagination** - Efficiently handles large files with configurable page size
- ⚡ **Async Loading** - Non-blocking file loading via `vim.fn.jobstart`
- 🔒 **Read-Only Mode** - Prevents accidental modifications to your data
- ⌨️ **Intuitive Keybindings** - Vim-native navigation and control

## 📸 Screenshots

![Screenshot](https://github.com/user-attachments/assets/a04f708c-213f-4c66-8493-8b7016cabcd8)

## 📋 Requirements

### Required

- **Neovim** >= 0.9.0
- **Python 3** >= 3.7
- **pandas** - Python library for data manipulation
- **openpyxl** - For reading `.xlsx` files
- **xlrd** - For reading `.xls` files

Python is only needed for Excel files. CSV/TSV files are parsed in Lua.

### Optional

- A Neovim plugin manager (lazy.nvim, packer.nvim, vim-plug, etc.)

## 🚀 Installation

### Step 1: Install Python Dependencies

First, ensure you have Python 3 installed:

```bash
python3 --version
```

Then install the required Python packages:

```bash
# Using pip
pip3 install pandas openpyxl xlrd

# Or with user flag (if you get permission errors)
pip3 install --user pandas openpyxl xlrd

# Or using Python module
python3 -m pip install pandas openpyxl xlrd
```

**macOS users with Homebrew:** If you have multiple Python installations, make sure to install pandas in the correct one:

```bash
# Check which Python Neovim uses
which python3

# Install in that specific Python
/opt/homebrew/bin/python3 -m pip install pandas openpyxl xlrd
# or
/usr/bin/python3 -m pip install pandas openpyxl xlrd
```

Verify the installation:

```bash
python3 -c "import pandas; print('pandas installed successfully')"
python3 -c "import openpyxl; print('openpyxl installed successfully')"
python3 -c "import xlrd; print('xlrd installed successfully')"
```

### Step 2: Install the Plugin

#### Using [lazy.nvim](https://github.com/folke/lazy.nvim) (Recommended)

```lua
{
  'beargruug/xls-viewer.nvim',
  config = function()
    require('xls-viewer').setup()
  end
}
```

#### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'beargruug/xls-viewer.nvim',
  config = function()
    require('xls-viewer').setup()
  end
}
```

## ⚙️ Configuration

### Default Configuration

```lua
require('xls-viewer').setup({
  -- Python interpreter. nil = auto-detect: tries g:python3_host_prog,
  -- python3 on $PATH and common install locations, and uses the first
  -- one that has pandas installed.
  python_cmd = nil,

  -- File extensions opened in the viewer. Add "csv" / "tsv" to opt in.
  filetypes = { 'xls', 'xlsx', 'xlsm' },

  -- Column display settings
  max_column_width = 50,
  min_column_width = 3,
  padding = 2,

  -- Sheet selection (0 = first sheet, or use a sheet name string)
  default_sheet = 0,

  -- Pagination
  page_size = 500,

  -- Show each column's detected type under the header
  -- (# number, D date, B boolean, T text, ∅ empty)
  type_indicators = true,

  -- What `q` does when the viewer is the only thing open:
  -- true = quit the window (exits Neovim if it's the last one)
  -- false = only delete the buffer
  quit_on_close = true,

  -- Async loading (non-blocking)
  async = true,

  -- Highlight groups for data types
  highlights = {
    header = 'XlsHeader',       -- linked to Title by default
    number = 'XlsNumber',       -- linked to Number
    date = 'XlsDate',           -- linked to Special
    boolean = 'XlsBoolean',     -- linked to Boolean
    null = 'XlsNull',           -- linked to Comment
    string = 'XlsString',       -- linked to Normal
    separator = 'XlsSeparator', -- linked to NonText
  },
})
```

#### Custom Python Path

If you have multiple Python installations or use a virtual environment:

```lua
require('xls-viewer').setup({
  python_cmd = '/opt/homebrew/bin/python3',
  -- or for a virtual environment:
  -- python_cmd = '/path/to/venv/bin/python3',
})
```

#### CSV/TSV Files

CSV handling is opt-in so the viewer doesn't take over files you want to edit:

```lua
require('xls-viewer').setup({
  filetypes = { 'xls', 'xlsx', 'xlsm', 'csv', 'tsv' },
})
```

`.tsv` uses tabs. For `.csv`, the delimiter (`,` `;` tab `|`) is detected from the header line.

#### Custom Highlight Colors

Override the default highlight groups in your colorscheme or config:

```lua
vim.api.nvim_set_hl(0, 'XlsNumber', { fg = '#f9a825' })
vim.api.nvim_set_hl(0, 'XlsDate', { fg = '#4fc3f7' })
vim.api.nvim_set_hl(0, 'XlsBoolean', { fg = '#ce93d8' })
vim.api.nvim_set_hl(0, 'XlsNull', { fg = '#757575', italic = true })
vim.api.nvim_set_hl(0, 'XlsHeader', { fg = '#ffffff', bold = true })
```

## 🎮 Usage

### Basic Usage

Simply open any Excel file in Neovim:

```bash
nvim mydata.xlsx
# or
nvim report.xls
```

The plugin will automatically detect the file type and display it with formatted columns, syntax highlighting, and a status footer.

### Keybindings

When viewing an Excel file, the following keybindings are available. Press `?` in the viewer to see them in a popup:

| Key | Action |
|-----|--------|
| `?` | Show help (all keys and commands) |
| `q` | Close viewer: back to the previous buffer, or quit if nothing else is open |
| `gs` | Select/switch sheet |
| `s` | Sort by column under cursor (cycles: asc -> desc -> none) |
| `/` | Search/filter rows |
| `g/` | Filter a single column |
| `<leader>F` | Clear active filter |
| `>` / `<` | Widen / narrow column under cursor (accepts a count, e.g. `5>`) |
| `=` | Reset width of column under cursor |
| `g=` | Reset all column widths |
| `gc` | Go to cell (e.g., `B5`, `AA12`) |
| `]p` | Next page |
| `[p` | Previous page |
| `gp` | Go to specific page number |

### Commands

| Command | Description |
|---------|-------------|
| `:XlsSheet` | Open sheet selector |
| `:XlsSort [column]` | Sort by column name/number |
| `:XlsFilter [pattern]` | Filter rows by pattern |
| `:XlsFilterClear` | Clear active filter |
| `:XlsGoto [coord]` | Jump to cell (e.g., `:XlsGoto B5`) |
| `:XlsPage [n/next/prev]` | Navigate to page |
| `:XlsExport[!] [path]` | Export filtered/sorted view to `.csv`, `.tsv` or `.xlsx` (`!` overwrites without asking) |

### Multi-Sheet Navigation

When opening a file with multiple sheets, the first sheet is loaded by default. Press `gs` to open the sheet picker:

```
Select sheet:
> Sales (current)
  Inventory
  Summary
```

### Sorting

Place your cursor on any column and press `s` to cycle the sort:
1. First press: Sort ascending (▲)
2. Second press: Sort descending (▼)
3. Third press: Clear sort

The sort indicator appears in the footer: `Sort: Amount ▼`

### Filtering

Press `/` to enter a search pattern. The filter is case-insensitive and matches any cell content:

```
Filter rows: alice
```

The footer shows: `Filter: "alice" (3/100 rows)`

Press `g/` to pick a column first and filter only that column. Press `<leader>F` to clear the filter and show all rows again.

### Cell Navigation

Press `gc` and enter a cell coordinate to jump directly:

```
Go to cell (e.g., B5): C12
```

This supports standard spreadsheet notation (A-Z, AA-ZZ for columns, numbers for rows). Row numbers refer to the current view, so with a filter or sort active, `A5` is the 5th row you see.

### Column Resizing

Put the cursor on a column and press `>` to widen it or `<` to narrow it (2 cells per press; `5>` widens by 10). Widened columns may exceed `max_column_width`. Press `=` to reset the column, `g=` to reset all. Widths reset when you switch sheets.

### Exporting

`:XlsExport` writes every row of the current view (filter and sort applied, across all pages):

```vim
:XlsExport ~/Desktop/filtered.csv
:XlsExport report.xlsx
:XlsExport!  out.tsv     " overwrite without asking
```

Without a path it prompts, suggesting `<file>_<sheet>_export.csv` next to the source file. `.xlsx` export needs Python + pandas; number and date columns are written as real Excel types.

### Pagination

Large files are automatically paginated (default: 500 rows per page). The footer shows:

```
Sheet: Sales | Page 2/10 (rows 501-1000 of 5000)
```

Use `]p`/`[p` to navigate pages, or `gp` to jump to a specific page.

## 🏗️ Architecture

```
lua/xls-viewer/
├── init.lua        Entry point, setup, autocmds, user commands
├── config.lua      Configuration defaults and highlight setup
├── open.lua        Loader selection, buffer setup
├── keymaps.lua     Keymap table (also feeds the help window)
├── help.lua        `?` floating help window
├── close.lua       Smart close (previous buffer / window / quit)
├── python.lua      Shell-free Python runner with interpreter auto-detection
├── csv.lua         Pure-Lua CSV/TSV parser and writer
├── state.lua       Buffer-local state (data, sort, filter, page, view cache)
├── render.lua      Rendering pipeline, extmark highlights, type indicators
├── layout.lua      Cursor <-> cell mapping (multibyte safe)
├── sheets.lua      Multi-sheet selection via vim.ui.select
├── sort.lua        Column sorting
├── filter.lua      Search/filter with row count feedback
├── navigate.lua    Cell coordinate parsing and cursor jumping
├── paginate.lua    Page navigation
├── resize.lua      Interactive column resizing
└── export.lua      Export view to CSV/TSV/XLSX
```

## 🔧 Troubleshooting

### "ModuleNotFoundError: No module named 'pandas'"

**Problem:** Python can't find the pandas module.

**Solution:**

1. Check which Python Neovim is using:
   ```bash
   which python3
   ```

2. Install pandas in that specific Python:
   ```bash
   /path/to/python3 -m pip install pandas openpyxl xlrd
   ```

3. Or configure the plugin to use a specific Python (by default it tries `g:python3_host_prog`, `python3` on `$PATH`, `/usr/bin/python3`, then Homebrew paths):
   ```lua
   require('xls-viewer').setup({
     python_cmd = '/path/to/python3',
   })
   ```

### Multiple Python Installations (macOS)

If you have both Homebrew and system Python:

```bash
# Check all Python installations
which -a python3

# Test each one
/opt/homebrew/bin/python3 -c "import pandas"
/usr/bin/python3 -c "import pandas"

# Install in the one that works or configure the plugin
```

### File Not Opening

**Problem:** Excel file opens as binary/garbled text, or the buffer shows an error.

If the buffer shows `xls-viewer: failed to load ...`, the message below it names the Python interpreter that was tried and the error it raised.

**Solution:**

1. Ensure the plugin is loaded:
   ```vim
   :lua print(vim.inspect(package.loaded['xls-viewer']))
   ```

2. Check if autocmd is registered:
   ```vim
   :autocmd BufReadCmd
   ```

### Slow Loading with Large Files

Reduce `page_size` to load fewer rows at once:

```lua
require('xls-viewer').setup({
  page_size = 100,  -- Faster rendering, more pages
})
```

## 🤝 Contributing

Contributions are welcome! Here's how you can help:

1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Reporting Issues

When reporting issues, please include:

- Neovim version (`:version`)
- Python version (`python3 --version`)
- Pandas version (`python3 -c "import pandas; print(pandas.__version__)"`)
- Operating system
- Plugin configuration
- Steps to reproduce
- Error messages (`:messages`)

## 📝 Roadmap

- [x] Multi-sheet support with sheet selection
- [x] Column sorting
- [x] Search/filter functionality
- [x] Cell navigation (jump to cell by coordinates)
- [x] Syntax highlighting for different data types
- [x] Large file optimization (pagination)
- [x] CSV/TSV file support
- [x] Column resizing (interactive)
- [x] Export filtered/sorted view
- [x] Virtual text for cell type indicators

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

**Made with ❤️ for the Neovim community**

*If this plugin helps you, consider giving it a ⭐ on GitHub!*
