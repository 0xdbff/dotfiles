if vim.fn.has("nvim-0.12") == 0 then
  error("This config requires Neovim 0.12+ (current maintained Tree-sitter API).")
end

require("options")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--branch=stable",
    "https://github.com/folke/lazy.nvim.git",
    lazypath,
  })
  if vim.v.shell_error ~= 0 then
    error("Could not install lazy.nvim. Check Git/network access:\n" .. output)
  end
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup(require("plugins"), require("lazy_config"))
require("mappings")
require("commands")
vim.cmd.colorscheme("cursor-midnight")
