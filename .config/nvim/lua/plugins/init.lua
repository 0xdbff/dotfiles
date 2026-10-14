return {
  { "nvim-tree/nvim-web-devicons", opts = {} },
  { "nvim-mini/mini.statusline", opts = { use_icons = true, set_vim_settings = false } },
  {
    "nvim-neo-tree/neo-tree.nvim",
    tag = "3.42.0",
    lazy = false, -- Neo-tree handles its own lazy loading.
    dependencies = { "nvim-lua/plenary.nvim", "MunifTanjim/nui.nvim", "nvim-tree/nvim-web-devicons" },
    opts = {
      sources = { "filesystem", "buffers", "git_status" },
      popup_border_style = "single",
      window = { width = 32 },
      filesystem = {
        follow_current_file = { enabled = true },
        filtered_items = { hide_dotfiles = false },
      },
      default_component_configs = {
        icon = {
          provider = function(icon, node)
            if node.type == "file" or node.type == "terminal" then
              icon.text = require("nvim-web-devicons").get_icon(node.name, nil, { default = true })
              icon.highlight = "NeoTreeFileIcon"
            end
          end,
        },
      },
    },
  },
  {
    "lewis6991/gitsigns.nvim",
    event = { "BufReadPre", "BufNewFile" },
    opts = { attach_to_untracked = true },
  },
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      require("plugins.configs.treesitter")
    end,
  },
  {
    "HiPhish/rainbow-delimiters.nvim",
    tag = "v0.12.0",
    lazy = false,
    init = function()
      vim.g.rainbow_delimiters = {
        highlight = { "CursorMidnightBracket1", "CursorMidnightBracket2", "CursorMidnightBracket3" },
      }
    end,
  },
  {
    "saghen/blink.cmp",
    tag = "v1.10.2",
    opts = function()
      return require("plugins.configs.blink")
    end,
  },
  { "mason-org/mason.nvim", tag = "v2.3.1", opts = {} },
  {
    "neovim/nvim-lspconfig",
    tag = "v2.12.0",
    dependencies = { "mason-org/mason.nvim", "saghen/blink.cmp" },
    config = function()
      require("plugins.configs.lspconfig")
    end,
  },
  {
    "stevearc/conform.nvim",
    event = { "BufReadPre", "BufNewFile" },
    cmd = "ConformInfo",
    opts = function()
      return require("plugins.configs.conform")
    end,
  },
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = function()
      return require("plugins.configs.telescope")
    end,
  },
  {
    "akinsho/toggleterm.nvim",
    cmd = { "ToggleTerm", "TermExec" },
    keys = { { "<C-c>", "<cmd>ToggleTerm<CR>", mode = { "n", "i", "t" }, desc = "Toggle terminal" } },
    opts = {
      direction = "vertical",
      size = 80,
      shade_terminals = false,
      highlights = {
        Normal = { link = "CursorMidnightTerminal" },
        NormalFloat = { link = "CursorMidnightTerminal" },
        FloatBorder = { link = "CursorMidnightTerminalBorder" },
      },
    },
  },
}
