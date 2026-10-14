return {
  formatters_by_ft = require("languages").formatters_by_ft,
  formatters = {
    -- Include import sorting alongside configured safe lint fixes.
    ruff_fix = { append_args = { "--extend-select", "I" } },
  },
  default_format_opts = { lsp_format = "fallback" },
  notify_on_error = true,
  notify_no_formatters = true,
  -- Formatting is explicit (;f), never on save.
}
