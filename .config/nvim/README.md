# TinyVim · Cursor Midnight

A lean, multi-language configuration based on [NvChad/tinyvim](https://github.com/NvChad/tinyvim), upstream revision `cbf1ec6c74afb2917dca125ebeefe334901cb204`.

Originally created by [Sidhanth Rathod (@siduck)](https://github.com/siduck) and the [TinyVim contributors](https://github.com/NvChad/tinyvim/graphs/contributors). Customized by **Diogo Antunes (@0xdbff)** on **2026-10-14**. Distributed under GNU GPL version 3; see [LICENSE](LICENSE) and the repository's [attribution](../../README.md#attribution-and-license).

## Requirements

- **Neovim 0.12+** (validated with 0.12.6), Git, curl, tar, unzip, and a C compiler.
- **Tree-sitter CLI 0.26.1+** installed via a package manager, not npm; validated with 0.27.1.
- Node/npm, Python/venv, and Go for Mason-managed language tools; ripgrep for project search.
- Rust's `cargo`, `rustc`, and `rustfmt` from rustup for Rust projects/formatting.
- Dart/Flutter SDK for Dart (`dart` on PATH, or `~/flutter/bin/dart`).
- A TeX distribution providing `latexmk` for LaTeX builds; forward search requires your own viewer configuration.
- A Nerd Font for icons (the existing Alacritty font is suitable).

Plugins are managed by **lazy.nvim** and locked in `lazy-lock.json`. Current stable plugin tags are used where appropriate; Tree-sitter uses its maintained `main` branch and native Neovim highlighting. There is no packer, Rust-tools, old LSP setup framework, cmp/LuaSnip stack, duplicate theme, AI, or DAP bundle.

## Languages and setup

| Language | LSP | Formatting |
| --- | --- | --- |
| Lua | lua_ls | StyLua |
| C/C++ | clangd | clang-format |
| Rust | rust_analyzer | rustfmt |
| Python | Pyright + Ruff | Ruff fixes/import sorting + format |
| JavaScript/TypeScript/React | ts_ls | Prettier |
| HTML/CSS/JSON/YAML | respective native LSP configs | Prettier |
| Markdown | Marksman | Prettier |
| Bash | bashls | shfmt |
| TOML | Taplo | Taplo |
| Go | gopls | gofumpt + goimports |
| LaTeX/BibTeX | Texlab | native Texlab formatting |
| Dart/Flutter | dartls | native Dart formatting |

`lua/languages.lua` is the single language/tool/parser catalog. All LSPs use `vim.lsp.config()` / `vim.lsp.enable()`. Missing executables are skipped rather than generating startup errors.

For a fresh machine:
1. Open Neovim; Lazy installs plugins.
2. Run **`:ToolsInstall`**, then let Mason and parser installations finish (`:Mason` shows progress).
3. Restart Neovim, or run **`:ToolsEnable`** and reopen the buffer.
4. Inspect **`:ToolsStatus`**, `:checkhealth vim.lsp mason nvim-treesitter`, or `:ConformInfo` if a tool is unavailable.

Health may report optional ecosystems (PHP/Java/Julia/LuaRocks) that are intentionally not installed, upstream LSP filetype aliases, or Blink's unused native fuzzy binary. This config uses Lua fuzzy matching; those warnings do not require adding more dependencies. Conform exposes `:ConformInfo`, not a `:checkhealth conform` module.

Tools are installed explicitly, not downloaded on every startup. Formatting is explicit, **not on save**; project formatter settings are respected. Completion uses blink.cmp's stable API, Lua fuzzy matching, and native `vim.snippet`—no extra snippet engine or binary download.

After tools are installed, run the non-destructive smoke checks from this directory:
`nvim --headless '+luafile tests/smoke.lua' '+qa!'`.

## Familiar keys

Leader is **Space**. Native `gc` / `gcc` comments are available.

| Keys | Action |
| --- | --- |
| Ctrl-h/j/k/l; Space-= | Split navigation; equalize |
| Space-Space; Tab / Shift-Tab | Alternate buffer; next / previous |
| `;w`, Ctrl-s; `;q`, `;qq`; Ctrl-q | Save; safe quit / quit all; close buffer |
| `;e`, `;te` | Edit nearby file / open in tab |
| Space-y/d/p | Clipboard copy/cut/paste |
| `;t`, Ctrl-n; Space-fe | Neo-tree toggle; reveal current file |
| Space-ff/fg/fb/fh/fo/gt | Files/text/buffers/help/recent/Git status |
| `;f`, Space-fm | Format (visual `;f` formats selected lines) |
| gd/gD/gi/gr; K or Space-k | Definition/declaration/implementation/references; hover |
| Insert Ctrl-k; Space-D/rn/ca/so | Signature help; type/rename/code action/symbols |
| Space-wa/wr/wl | Workspace add/remove/list |
| Space-e/q; `[d`, `]d` | Diagnostic detail/list; previous/next |
| Space-/; Space-gp | Clear search; preview Git hunk |
| Ctrl-c; terminal Escape | Toggle terminal; terminal normal mode |
| `;cr`, `;cb`, `;cc`, `;m` | Terminal Cargo run/build/check/Make |
| LaTeX Space-lc/ll/lf | Texlab build/build/forward search (attached Texlab required) |

Quit keys intentionally no longer discard unsaved edits. Ctrl-k remains split navigation in normal mode; signature help uses insert mode.

## Theme and layout

`colors/cursor-midnight.lua` preserves the established Cursor Midnight palette as a **standalone, language-neutral colorscheme**. Generic Tree-sitter and semantic token colors apply across languages, as do nested bracket colors; there are no Rust-only overrides. Neo-tree icons/sidebar are muted, with Git status colors. No theme-engine dependency is required. Editor background is `#1e2127`; embedded terminal background is `#191c22`. Alacritty is configured separately and was not reset.

Configuration follows TinyVim's small layout: `options.lua`, `mappings.lua`, `commands.lua`, `languages.lua`, and `plugins/configs/`.

## Backup and recovery

Before replacing an existing setup, close Neovim and back up its config, data, state, and cache directories. Use `:lua print(vim.fn.stdpath("config"))` (and `"data"`, `"state"`, `"cache"`) to locate them. Keep backups outside this public repository. To restore, close Neovim, preserve the current directories, and put the saved directories back at their original paths; this does not change the installed Neovim binary.
