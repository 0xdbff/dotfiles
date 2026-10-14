return {
  snippets = { preset = "default" }, -- Neovim's vim.snippet; no extra engine.
  fuzzy = { implementation = "lua" }, -- No downloaded native binary or Cargo build.
  sources = { default = { "lsp", "path", "snippets", "buffer" } },
  keymap = {
    preset = "default",
    ["<CR>"] = { "accept", "fallback" },
    ["<C-p>"] = { "select_prev", "fallback" },
    ["<C-n>"] = { "select_next", "fallback" },
    ["<C-d>"] = { "scroll_documentation_down", "fallback" },
    ["<C-f>"] = { "scroll_documentation_up", "fallback" },
  },
  completion = { documentation = { auto_show = true, auto_show_delay_ms = 200 } },
  signature = { enabled = true },
}
