# 📊 xls-viewer.nvim

A Neovim plugin for viewing Excel files (`.xls` and `.xlsx`(workes but need some improvement) directly in your editor with beautiful column alignment and formatting.

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Neovim](https://img.shields.io/badge/Neovim-0.7%2B-green.svg)

## ✨ Features

- 🔍 **Automatic Detection** - Opens Excel files automatically when you open `.xls` or `.xlsx` files
- 📐 **Column Alignment** - Perfectly aligned columns with configurable widths
- 🎨 **Beautiful Formatting** - Clean table view with box-drawing characters
- 📋 **Header Separation** - Visual separator line between headers and data
- 🔒 **Read-Only Mode** - Prevents accidental modifications to your data
- ⚡ **Fast & Lightweight** - Minimal overhead, quick loading
- ⌨️ **Intuitive Keybindings** - Simple vim motion navigation and control

## 📸 Screenshots

![Screenshot](https://github.com/user-attachments/assets/a04f708c-213f-4c66-8493-8b7016cabcd8)

## 📋 Requirements

### Required

- **Neovim** >= 0.7.0
- **Python 3** >= 3.7
- **pandas** - Python library for data manipulation
- **openpyxl** - For reading `.xlsx` files
- **xlrd** - For reading `.xls` files

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
python3 -c "import pandas; print('✓ pandas installed successfully')"
python3 -c "import openpyxl; print('✓ openpyxl installed successfully')"
python3 -c "import xlrd; print('✓ xlrd installed successfully')"
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
  python_cmd = '/usr/bin/python3',      -- Python command to use
  max_column_width = 50,                -- Maximum width for any column
  min_column_width = 3,                 -- Minimum width for any column
  padding = 2,                          -- Padding between columns
})
```

#### Custom Python Path

If you have multiple Python installations or use a virtual environment:

```lua
require('xls-viewer').setup({
  python_cmd = '/usr/bin/python3',  -- Specific Python path
  -- or
  python_cmd = '/path/to/venv/bin/python3',  -- Virtual environment
})
```

## 🎮 Usage

### Basic Usage

Simply open any Excel file in Neovim:

```bash
nvim mydata.xlsx
# or
nvim report.xls
```

The plugin will automatically detect the file type and display it with formatted columns.

### Keybindings

When viewing an Excel file, the following keybindings are available:

| Key | Action |
|-----|--------|
| `q` | Close the viewer buffer |

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

3. Or configure the plugin to use a specific Python:
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

**Problem:** Excel file opens as binary/garbled text.

**Solution:**

1. Ensure the plugin is loaded:
   ```vim
   :lua print(vim.inspect(package.loaded['xls-viewer']))
   ```

2. Check if autocmd is registered:
   ```vim
   :autocmd BufReadCmd
   ```

3. Manually trigger the viewer:
   ```vim
   :lua require('xls-viewer').open_xls()
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

- [ ] Multi-sheet support with sheet selection
- [ ] Column sorting
- [ ] Search/filter functionality
- [ ] Cell navigation (jump to cell by coordinates)
- [ ] Syntax highlighting for different data types
- [ ] Large file optimization (pagination)

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details

---

**Made with ❤️ for the Neovim community**

*If this plugin helps you, consider giving it a ⭐ on GitHub!*
