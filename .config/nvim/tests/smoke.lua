-- Run from this directory: nvim --headless '+luafile tests/smoke.lua' '+qa!'
local common = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/smoke-common.lua")
common.run(function()
  common.core()
  assert(#require("languages").servers == 16, "Expected all 16 language servers")
  assert(#require("languages").parsers == 25, "Expected all 25 parsers")
  local lsp = require("plugins.configs.lspconfig")
  assert(next(lsp.unavailable) == nil, "Missing language tools; run :ToolsInstall then restart")
  for _, lang in ipairs(require("languages").parsers) do
    assert(vim.treesitter.language.add(lang), "Missing parser: " .. lang)
    assert(vim.treesitter.query.get(lang, "highlights"), "Missing highlight query: " .. lang)
  end
  common.plugin_filetypes()
  print("PASS: theme, ANSI, essential stack, LSP availability, parsers, plugin-window guards")
end)
