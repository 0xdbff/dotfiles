-- Core-only CI gate after Lazy restore; does not install or certify language tools.
local common = dofile(vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":h") .. "/smoke-common.lua")
common.run(function()
  common.core()
  local servers = require("languages").servers
  assert(#servers == 16, "Expected all 16 native server definitions")
  for _, name in ipairs(servers) do
    local config = vim.lsp.config[name]
    assert(type(config) == "table", "Missing native server config: " .. name)
    assert(type(config.cmd) == "table" or type(config.cmd) == "function", "Missing server command: " .. name)
    assert(type(config.filetypes) == "table" and #config.filetypes > 0, "Missing server filetypes: " .. name)
    assert(
      config.capabilities.textDocument.completion.completionItem.snippetSupport,
      "Missing completion capabilities: " .. name
    )
  end
  for _, command in ipairs({ "TSInstallAll", "MasonInstallAll", "ToolsInstall", "ToolsEnable", "ToolsStatus" }) do
    assert(vim.api.nvim_get_commands({})[command], "Missing user command: " .. command)
  end
  assert(vim.g.mapleader == " ", "Expected Space leader")
  for _, key in ipairs({
    ";w",
    ";q",
    ";qq",
    ";t",
    "<C-n>",
    "<C-h>",
    "<leader>ff",
    "<leader>fg",
    "<leader>fm",
    "<leader>ca",
    "[d",
    "]d",
  }) do
    assert(vim.fn.maparg(key, "n") ~= "", "Missing normal mapping: " .. key)
  end
  assert(vim.fn.maparg(";f", "v") ~= "", "Missing visual formatter mapping")
  assert(vim.fn.maparg("<Esc>", "t") ~= "", "Missing terminal escape mapping")
  assert(#vim.api.nvim_get_autocmds({ group = "UserLspKeys", event = "LspAttach" }) > 0, "Missing LSP key setup")
  assert(#vim.api.nvim_get_autocmds({ group = "UserTreesitter", event = "FileType" }) > 0, "Missing parser guard")
  common.plugin_filetypes()
  print(
    "PASS: core configuration: Midnight/16 ANSI colors, real plugin stack, completion capabilities, 16 native LSP definitions, user commands/keymaps, unknown-filetype guards; language executables/parsers NOT certified"
  )
end)
