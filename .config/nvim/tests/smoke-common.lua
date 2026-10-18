local M = {}

function M.no_errors()
  -- Lazy reports some configuration failures through scheduled notifications.
  vim.wait(100, function()
    return false
  end)
  assert(vim.v.errmsg == "", "Neovim startup/runtime error: " .. vim.v.errmsg)
  local messages = vim.api.nvim_exec2("messages", { output = true }).output
  for _, marker in ipairs({ "Error detected", "Error executing", "Failed to run", "stack traceback:" }) do
    assert(not messages:find(marker, 1, true), "Neovim startup/runtime error:\n" .. messages)
  end
end

function M.core()
  M.no_errors()
  assert(vim.fn.has("nvim-0.12") == 1, "Neovim 0.12+ required")
  for _, module in ipairs({
    "options",
    "mappings",
    "commands",
    "plugins.configs.lspconfig",
    "plugins.configs.treesitter",
  }) do
    assert(package.loaded[module], "Startup did not load " .. module)
  end
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
    assert(vim.g["terminal_color_" .. (index - 1)] == color, "ANSI palette changed at " .. (index - 1))
  end
  local plugins = require("lazy.core.config").plugins
  assert(plugins["neo-tree.nvim"] and not plugins["nvim-tree.lua"], "Wrong file tree")
  for _, name in ipairs({ "rust-tools.nvim", "nvim-cmp", "nightfox.nvim" }) do
    assert(not plugins[name], "Old stack returned: " .. name)
  end
  -- Exercise real lazy plugin setup even in an empty headless buffer.
  local modules = {
    ["neo-tree.nvim"] = "neo-tree",
    ["plenary.nvim"] = "plenary.path",
    ["nui.nvim"] = "nui.popup",
    ["nvim-web-devicons"] = "nvim-web-devicons",
    ["mini.statusline"] = "mini.statusline",
    ["gitsigns.nvim"] = "gitsigns",
    ["nvim-treesitter"] = "nvim-treesitter",
    ["rainbow-delimiters.nvim"] = "rainbow-delimiters",
    ["blink.cmp"] = "blink.cmp",
    ["mason.nvim"] = "mason",
    ["conform.nvim"] = "conform",
    ["telescope.nvim"] = "telescope",
    ["toggleterm.nvim"] = "toggleterm",
  }
  for name, module in pairs(modules) do
    assert(plugins[name], "Missing plugin spec: " .. name)
    require("lazy").load({ plugins = { name } })
    assert(require(module), "Missing plugin module: " .. module)
    assert(plugins[name]._.loaded, "Plugin not loaded: " .. name)
  end
  assert(plugins["nvim-lspconfig"] and plugins["nvim-lspconfig"]._.loaded, "Native LSP plugin not loaded")
  assert(
    require("blink.cmp").get_lsp_capabilities().textDocument.completion.completionItem.snippetSupport,
    "Completion snippet capabilities missing"
  )
  M.no_errors()
end

function M.plugin_filetypes()
  for _, filetype in ipairs({ "neo-tree", "TelescopePrompt", "validation-no-parser" }) do
    vim.cmd("enew!")
    vim.bo.filetype = filetype -- Unknown parsers must not break plugin windows.
    assert(vim.bo.filetype == filetype, "Filetype event failed: " .. filetype)
  end
  M.no_errors()
end

function M.run(main)
  local ok, err = xpcall(main, debug.traceback)
  if not ok then
    vim.api.nvim_err_writeln(err)
    vim.cmd("cquit 1")
  end
end

return M
