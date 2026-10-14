vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt
o.termguicolors = true
o.number = true
o.relativenumber = true
o.signcolumn = "yes"
o.cursorline = true
o.mouse = "a"
o.clipboard = "unnamedplus"
o.expandtab = true
o.tabstop = 4
o.shiftwidth = 4
o.softtabstop = 4
o.smartindent = true
o.ignorecase = true
o.smartcase = true
o.splitright = true
o.splitbelow = true
o.scrolloff = 4
o.updatetime = 250
o.timeoutlen = 300
o.undofile = true
o.laststatus = 3
o.showmode = false
o.winborder = "single"
o.fillchars = { eob = " " }
o.guicursor = "a:ver100-Cursor/lCursor"

vim.diagnostic.config({
  severity_sort = true,
  update_in_insert = false,
  virtual_text = { prefix = "◈", spacing = 2 },
  float = { border = "single", source = true },
})
