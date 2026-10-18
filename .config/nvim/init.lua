if vim.fn.has("nvim-0.12") == 0 then
  error("This config requires Neovim 0.12+ (current maintained Tree-sitter API).")
end

require("options")
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
  local lockpath = vim.fn.stdpath("config") .. "/lazy-lock.json"
  local lock = vim.json.decode(table.concat(vim.fn.readfile(lockpath), "\n"))
  local revision = assert(lock["lazy.nvim"] and lock["lazy.nvim"].commit, "Missing lazy.nvim lock revision")
  assert(#revision == 40 and revision:match("^%x+$"), "Expected a full lazy.nvim commit hash")
  vim.fn.mkdir(vim.fn.fnamemodify(lazypath, ":h"), "p")
  local stage = assert(vim.uv.fs_mkdtemp(lazypath .. ".bootstrap-XXXXXX"))
  local function abort(message)
    vim.fn.delete(stage, "rf") -- Only the staging directory created above.
    error(message)
  end
  local output = vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "--no-checkout",
    "https://github.com/folke/lazy.nvim.git",
    stage,
  })
  if vim.v.shell_error ~= 0 then
    abort("Could not install lazy.nvim. Check Git/network access:\n" .. output)
  end
  output = vim.fn.system({ "git", "-C", stage, "checkout", "--detach", revision })
  if vim.v.shell_error ~= 0 then
    abort("Could not check out locked lazy.nvim revision:\n" .. output)
  end
  local published, err = vim.uv.fs_rename(stage, lazypath)
  if not published then
    vim.fn.delete(stage, "rf")
    if not vim.uv.fs_stat(lazypath) then
      error("Could not publish lazy.nvim: " .. tostring(err))
    end
  end
end
vim.opt.rtp:prepend(lazypath)
require("lazy").setup(require("plugins"), require("lazy_config"))
require("mappings")
require("commands")
vim.cmd.colorscheme("cursor-midnight")
