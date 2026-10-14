-- Run from this directory: nvim --headless '+luafile tests/smoke.lua' '+qa!'
local function main()
  assert(vim.fn.has("nvim-0.12") == 1, "Neovim 0.12+ required")
  assert(vim.g.colors_name == "cursor-midnight", "Midnight theme not loaded")
  local function fg(name)
    return vim.api.nvim_get_hl(0, { name = name, link = false }).fg
  end
  assert(fg("Type") == 0x7b88a1 and fg("@type") == 0x7b88a1, "Universal type colors changed")
  assert(fg("@variable") == 0xd8dee9 and fg("@function") == 0x88c0d0, "Syntax colors changed")
  assert(fg("NeoTreeDirectoryName") == 0x7c818e, "Neo-tree colors changed")
  local ansi = {
    "#272c36",
    "#bf616a",
    "#a3be8c",
    "#ebcb8b",
    "#81a1c1",
    "#7d7c9b",
    "#88c0d0",
    "#e5e9f0",
    "#4c566a",
    "#bf616a",
    "#a3be8c",
    "#ebcb8b",
    "#81a1c1",
    "#b48ead",
    "#8fbcbb",
    "#eceff4",
  }
  for index, color in ipairs(ansi) do
    assert(vim.g["terminal_color_" .. (index - 1)] == color, "ANSI palette changed")
  end
  local plugins = require("lazy.core.config").plugins
  assert(plugins["neo-tree.nvim"] and not plugins["nvim-tree.lua"], "Wrong file tree")
  assert(
    not plugins["rust-tools.nvim"] and not plugins["nvim-cmp"] and not plugins["nightfox.nvim"],
    "Old stack returned"
  )
  assert(require("blink.cmp").get_lsp_capabilities().textDocument.completion.completionItem.snippetSupport)
  local lsp = require("plugins.configs.lspconfig")
  assert(next(lsp.unavailable) == nil, "Missing language tools; run :ToolsInstall then restart")
  for _, lang in ipairs(require("languages").parsers) do
    assert(vim.treesitter.language.add(lang), "Missing parser: " .. lang)
    assert(vim.treesitter.query.get(lang, "highlights"), "Missing highlight query: " .. lang)
  end
  for _, filetype in ipairs({ "neo-tree", "TelescopePrompt", "validation-no-parser" }) do
    vim.cmd("enew!")
    vim.bo.filetype = filetype -- Regression: unknown parsers must not break plugin windows.
  end
  print("PASS: theme, ANSI, essential stack, LSP availability, parsers, plugin-window guards")
end

local ok, err = xpcall(main, debug.traceback)
if not ok then
  vim.api.nvim_err_writeln(err)
  vim.cmd("cquit 1")
end
