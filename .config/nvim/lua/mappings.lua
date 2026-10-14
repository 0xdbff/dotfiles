local map = vim.keymap.set
local function n(lhs, rhs, desc)
  map("n", lhs, rhs, { silent = true, desc = desc })
end

-- Familiar keys; quit mappings now protect unsaved edits.
for key, direction in pairs({ h = "h", j = "j", k = "k", l = "l" }) do
  n("<C-" .. key .. ">", "<C-w>" .. direction, "Focus window " .. direction)
end
n("<leader>=", "<C-w>=", "Equalize splits")
n("<leader><leader>", "<C-^>", "Previous buffer")
n("<Tab>", "<cmd>bnext<CR>", "Next buffer")
n("<S-Tab>", "<cmd>bprevious<CR>", "Previous buffer")
n("<C-q>", "<cmd>bdelete<CR>", "Close buffer")
n("<C-s>", "<cmd>write<CR>", "Save")
n(";w", "<cmd>write<CR>", "Save")
n(";q", "<cmd>quit<CR>", "Quit safely")
n(";qq", "<cmd>qall<CR>", "Quit all safely")
n(";e", ':edit <C-r>=expand("%:p:h") . "/"<CR>', "Edit nearby file")
n(";te", ':tabedit <C-r>=expand("%:p:h") . "/"<CR>', "Open nearby file in tab")
n("<leader>/", "<cmd>nohlsearch<CR>", "Clear search")
map("v", "<leader>y", '"+y', { desc = "Copy to clipboard" })
map("v", "<leader>d", '"+d', { desc = "Cut to clipboard" })
map({ "n", "v" }, "<leader>p", '"+p', { desc = "Paste clipboard" })
n(";t", "<cmd>Neotree toggle<CR>", "Toggle file tree")
n("<C-n>", "<cmd>Neotree toggle<CR>", "Toggle file tree")
n("<leader>fe", "<cmd>Neotree reveal<CR>", "Reveal current file")
for key, picker in pairs({
  ff = "find_files",
  fg = "live_grep",
  fw = "live_grep",
  fb = "buffers",
  fh = "help_tags",
  fo = "oldfiles",
  gt = "git_status",
}) do
  n("<leader>" .. key, "<cmd>Telescope " .. picker .. "<CR>", "Find " .. picker)
end
local function format()
  local opts = { async = true, lsp_format = "fallback" }
  local mode = vim.fn.mode()
  if mode == "v" or mode == "V" or mode == "\22" then
    local first, last = vim.fn.line("v"), vim.fn.line(".")
    if first > last then
      first, last = last, first
    end
    -- Format selected lines, including the final byte (StyLua ranges are exclusive).
    opts.range = { start = { first, 0 }, ["end"] = { last, #vim.fn.getline(last) } }
  end
  require("conform").format(opts)
end
map({ "n", "v" }, ";f", format, { desc = "Format buffer/selection" })
n("<leader>fm", format, "Format buffer")
n("<leader>ca", vim.lsp.buf.code_action, "Code action")
n("<leader>e", vim.diagnostic.open_float, "Diagnostic detail")
n("<leader>q", vim.diagnostic.setloclist, "Diagnostic list")
n("[d", function()
  vim.diagnostic.jump({ count = -1, float = true })
end, "Previous diagnostic")
n("]d", function()
  vim.diagnostic.jump({ count = 1, float = true })
end, "Next diagnostic")
n("<leader>gp", function()
  require("gitsigns").preview_hunk()
end, "Preview Git hunk")
for key, command in pairs({ cr = "cargo run", cb = "cargo build", cc = "cargo check", m = "make" }) do
  n(";" .. key, "<cmd>TermExec cmd='" .. command .. "'<CR>", command)
end
map("t", "<Esc>", [[<C-\><C-n>]], { desc = "Terminal normal mode" })

vim.api.nvim_create_autocmd("LspAttach", {
  group = vim.api.nvim_create_augroup("UserLspKeys", { clear = true }),
  callback = function(event)
    local function buf(lhs, rhs, desc, mode)
      map(mode or "n", lhs, rhs, { buffer = event.buf, desc = desc })
    end
    buf("gD", vim.lsp.buf.declaration, "Declaration")
    buf("gd", vim.lsp.buf.definition, "Definition")
    buf("gi", vim.lsp.buf.implementation, "Implementation")
    buf("gr", vim.lsp.buf.references, "References")
    buf("K", vim.lsp.buf.hover, "Hover")
    buf("<leader>k", vim.lsp.buf.hover, "Hover")
    buf("<C-k>", vim.lsp.buf.signature_help, "Signature help", "i")
    buf("<leader>D", vim.lsp.buf.type_definition, "Type definition")
    buf("<leader>rn", vim.lsp.buf.rename, "Rename")
    buf("<leader>wa", vim.lsp.buf.add_workspace_folder, "Add workspace")
    buf("<leader>wr", vim.lsp.buf.remove_workspace_folder, "Remove workspace")
    buf("<leader>wl", function()
      print(vim.inspect(vim.lsp.buf.list_workspace_folders()))
    end, "Workspaces")
    buf("<leader>so", "<cmd>Telescope lsp_document_symbols<CR>", "Document symbols")
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if client and client.name == "texlab" then
      buf("<leader>lc", "<cmd>LspTexlabBuild<CR>", "Build LaTeX")
      buf("<leader>ll", "<cmd>LspTexlabBuild<CR>", "Build LaTeX")
      buf("<leader>lf", "<cmd>LspTexlabForward<CR>", "LaTeX forward search")
    end
  end,
})
