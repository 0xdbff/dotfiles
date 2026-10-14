local catalog = require("languages")
local M = { enabled = {}, unavailable = {} }
local sdk_dart = vim.fn.expand("~/flutter/bin/dart")
local dart = vim.fn.executable(sdk_dart) == 1 and sdk_dart or "dart"

vim.lsp.config("*", { capabilities = require("blink.cmp").get_lsp_capabilities() })

local overrides = {
  clangd = {
    before_init = function(params)
      -- clangd 23+ uses standard general.positionEncodings, not this old extension.
      params.capabilities.offsetEncoding = nil
    end,
  },
  lua_ls = {
    settings = {
      Lua = {
        runtime = { version = "LuaJIT", path = { "lua/?.lua", "lua/?/init.lua" } },
        diagnostics = { globals = { "vim" } },
        workspace = { library = { vim.env.VIMRUNTIME }, checkThirdParty = false },
        telemetry = { enable = false },
      },
    },
  },
  rust_analyzer = {
    settings = {
      ["rust-analyzer"] = {
        cargo = { allFeatures = true },
        procMacro = { enable = true },
      },
    },
  },
  pyright = {
    settings = {
      pyright = { disableOrganizeImports = true },
      python = { analysis = { typeCheckingMode = "basic" } },
    },
  },
  ruff = {
    on_attach = function(client)
      if vim.lsp.is_enabled("pyright") then
        client.server_capabilities.hoverProvider = false
      end
    end,
  },
  texlab = {
    settings = {
      texlab = {
        build = {
          executable = "latexmk",
          args = { "-pdf", "-interaction=nonstopmode", "-synctex=1", "%f" },
          onSave = false,
          forwardSearchAfter = false,
        },
        diagnosticsDelay = 300,
        formatterLineLength = 100,
        latexFormatter = "latexindent",
        bibtexFormatter = "texlab",
        latexindent = { modifyLineBreaks = false },
      },
    },
  },
  dartls = { cmd = { dart, "language-server", "--protocol=lsp" } },
}

for _, name in ipairs(catalog.servers) do
  vim.lsp.config(name, overrides[name] or {})
end

-- Called by :ToolsEnable (or on restart) after Mason adds executables to PATH.
-- Expose skipped commands for health/docs; never install anything here.
local functional_commands = {
  ts_ls = "typescript-language-server",
  html = "vscode-html-language-server",
  cssls = "vscode-css-language-server",
  jsonls = "vscode-json-language-server",
  yamlls = "yaml-language-server",
}
function M.enable()
  M.enabled, M.unavailable = {}, {}
  for _, name in ipairs(catalog.servers) do
    local cmd = vim.lsp.config[name].cmd
    local executable = type(cmd) == "table" and cmd[1] or functional_commands[name]
    if executable and vim.fn.executable(executable) == 1 then
      vim.lsp.enable(name)
      M.enabled[#M.enabled + 1] = name
    else
      vim.lsp.enable(name, false)
      M.unavailable[name] = executable or "missing command data"
    end
  end
  return M.enabled, M.unavailable
end

M.enable()
return M
