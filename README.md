# Dotfiles

Personal Zsh, Neovim, Alacritty, and OpenCode configuration maintained by [Diogo Antunes (@0xdbff)](https://github.com/0xdbff). Cursor Midnight ties the editor, terminal, and OpenCode together.

## Install everything

Clone **anywhere**, then run the installer as your normal user:

```sh
git clone https://github.com/0xdbff/dotfiles.git "$HOME/dotfiles"
cd "$HOME/dotfiles"
./install.sh --platform macos       # Homebrew must already be installed
# Or, on Fedora:
./install.sh --platform fedora
```

`install.sh` installs the shell tools, application binaries and base developer
toolchain, then creates absolute symlinks from **this clone's actual location**
to your configuration directory. It is safe to rerun. Existing files/directories
are backed up before replacement, with backup paths printed; unrelated OpenCode
settings, accounts, agents, plugins and MCP servers are not copied or replaced.

```sh
./install.sh --platform macos --dry-run     # no downloads or file changes
./install.sh --links-only                  # link all configs; skip packages
./install.sh --platform macos --set-default-shell  # explicit shell-change opt-in
./install.sh --help
```

Never run the entire installer with sudo. Fedora 44+ is required for the packaged
Neovim 0.12+ configuration. Fedora requests sudo only for package
installation. Homebrew is not installed automatically: first follow its
[official bootstrap instructions](https://docs.brew.sh/Installation). macOS also
needs Apple's Command Line Tools (`xcode-select --install`). Where a package is
unavailable, reviewed pins/checksums in the lock files govern the fallback; no
`curl | sh` installer is executed. Alacritty's disabled macOS cask is not used or
worked around by bypassing Gatekeeper.

### What gets linked

Paths below are relative to `${XDG_CONFIG_HOME:-$HOME/.config}`:

| Destination | Source in this clone |
| --- | --- |
| `nvim` | `.config/nvim` |
| `alacritty/alacritty.toml` | `.config/alacritty.toml` |
| `opencode/cli.json` | `.config/opencode/cli.json` |
| `opencode/themes/cursor-midnight.json` | `.config/opencode/themes/cursor-midnight.json` |
| `dotfiles-zsh` | `config` (Zsh modules and Starship) |

The installer preserves existing `.zshrc` content and inserts one backed-up,
managed initialization block in `${ZDOTDIR:-$HOME}/.zshrc`. It leaves the legacy
`~/.config/alacritty.toml` path alone; Alacritty reads the linked canonical
`alacritty/alacritty.toml` instead. Keep the clone in place, or rerun the installer
after moving it to update the links.

### First launch

- **Zsh:** open a new Zsh terminal, then run `./setup.sh --check`.
- **Neovim:** open `nvim`, let Lazy install locked plugins, run `:ToolsInstall`,
  then restart. [The Neovim guide](.config/nvim/README.md) covers parsers, Mason,
  language tools and keys. Flutter/Dart and TeX distributions are project-specific
  SDKs and are not silently installed by the dotfiles script.
- **Alacritty:** macOS installs the Meslo Nerd Font cask and, when needed, builds
  a pinned native app in `~/Applications/Alacritty.app`, links its CLI into
  `~/.local/bin`, and registers its terminfo files. On Fedora, use the MesloLGS
  Nerd Font Propo family from
  [Meslo Nerd Font](https://www.nerdfonts.com/font-downloads) for the configured
  typography/icons. A missing font is separate from configuration linking.
- **OpenCode V2:** restart OpenCode to discover the theme; `/themes` selects it.
  Connect providers locally with `/connect`. Credentials stay outside Git.

## Zsh: Fish-like editing, native completion

From this checkout, as your normal user:

```sh
./setup.sh --platform macos                 # Homebrew must already be installed
./setup.sh --platform fedora                # DNF; asks for sudo as needed
```

Use `--dry-run` to inspect changes without writing anything. Nothing changes your
default shell unless you add `--set-default-shell`. Open a new Zsh terminal after
installation, then run `./setup.sh --check`.

This is a modular, framework-free setup: native Zsh completion + fzf-tab,
asynchronous history/completion suggestions, syntax highlighting, shared history,
fzf navigation, zoxide, and a restrained two-line Starship prompt. Existing
`.zshrc` content is preserved and backed up before inserting a managed block.
Neovim and Alacritty are **not** installed or modified by this script.

| Key | Action |
| --- | --- |
| Tab | Fuzzy completion with groups and descriptions when supplied by the tool |
| Right | Accept ghost text at end of line; otherwise move right |
| Up / Down | Search history by substring |
| Ctrl+R | Fuzzy persistent history |
| Ctrl+T | Insert files/directories |
| Alt+C | Fuzzy directory navigation |
| Alt+H / F1 | Consult documentation without discarding the command buffer |

See **[the Zsh guide](docs/zsh.md)** for prerequisites, completion coverage,
customization, updates, backup restoration, removal, limitations, tests, and
the terminal acceptance checklist.

## Contents

- `.config/nvim/`: TinyVim-based, multi-language Neovim configuration with a standalone Cursor Midnight colorscheme. See its [README](.config/nvim/README.md) for dependencies, setup, and key bindings.
- `.config/alacritty.toml`: Alacritty configuration using a matching palette and MesloLGS Nerd Font Propo.
- `.config/opencode/`: minimal OpenCode V2 CLI settings and the shared Cursor Midnight theme.
- `config/`: modular Zsh configuration and the two-line Starship prompt.
- `install.sh`: full installation/linking entry point; `setup.sh` is the independent Zsh-only installer.

## Minimal OpenCode configuration

The shared CLI config is deliberately **five lines**, not an export of a personal
OpenCode installation:

```json
{
  "$schema": "https://opencode.ai/v2/cli.json",
  "theme": {"name": "cursor-midnight", "mode": "dark"},
  "diffs": {"wrap": "word"}
}
```

Theme/UI preferences belong in `cli.json`, **not** `opencode.json`. Your global
server config, models, authentication, MCP settings and private plugins remain
machine-local. [Official CLI settings](https://opencode.ai/v2/docs/cli/config) and
[theme format](https://opencode.ai/v2/docs/cli/theme) describe the V2 integration.

## Sync changes

The symlinks make edits to the linked configuration edits to this repository.
There is no automatic commit or upload:

```sh
cd "$HOME/dotfiles"
git diff
git add .config config README.md
git commit -m "Update configs"
git push
```

On another linked machine, `git pull --ff-only` updates the linked configs.
Rerun `./install.sh --links-only` if links are missing or the clone moved; use a
full platform install if dependencies changed. Review changes before publishing;
never commit credentials or machine-local secrets.

## Tests and recovery

Run `./tests/run.sh` for isolated regression tests and static checks. With shell
dependencies and tmux installed, `python3 tests/interactive.py` exercises real
terminal editing/completion. See [recorded Zsh evidence](docs/zsh-validation.md)
and [the complete shell guide](docs/zsh.md).
Full-installer links/backups and OpenCode settings are validated in disposable
directories. Live application package installation, Fedora's OpenCode fallback,
and the macOS Alacritty source build were not executed locally; CI currently
exercises the Zsh installation and config linking, not the full app installer.

To unlink an app, remove only its destination symlink, then restore its printed
`.dotfiles-backup.*` file/directory if desired. Remove only the marked Zsh block
to disable the shell setup. Back up newer intentional edits before restoring an
old snapshot; never recursively delete a symlink's repository target. Package
removal is manual because tools may be shared by other configurations.

## Attribution and license

- Neovim is derived from [NvChad/tinyvim](https://github.com/NvChad/tinyvim), created by [Sidhanth Rathod (@siduck)](https://github.com/siduck), with contributions from the [upstream contributors](https://github.com/NvChad/tinyvim/graphs/contributors), including Owen Giles (@bousii).
- The imported upstream revision is `cbf1ec6c74afb2917dca125ebeefe334901cb204`. Its Git metadata is intentionally not included; this is a customized configuration, not an unmodified upstream release.
- Customizations and dotfiles maintenance by **Diogo Antunes (@0xdbff)**, modified **2026-10-14**. Changes include the Cursor Midnight themes, multi-language tools, key mappings, installers, tests, Zsh environment, and Alacritty/OpenCode settings.
- Color palette inspiration: Cursor's **Dark Midnight** theme, with the [BioHazard786/cursor-theme-vscode](https://github.com/BioHazard786/cursor-theme-vscode) mirror referenced by the Alacritty config.

Distributed under **GNU GPL version 3**; see [LICENSE](LICENSE). The original Neovim license is also preserved at [`.config/nvim/LICENSE`](.config/nvim/LICENSE). Third-party plugins retain their own licenses and are downloaded separately. Provided without warranty.
