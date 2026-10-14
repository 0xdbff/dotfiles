# Dotfiles

Personal Neovim and Alacritty configuration maintained by [Diogo Antunes (@0xdbff)](https://github.com/0xdbff).

## Contents

- `.config/nvim/`: TinyVim-based, multi-language Neovim configuration with a standalone Cursor Midnight colorscheme. See its [README](.config/nvim/README.md) for dependencies, setup, and key bindings.
- `.config/alacritty.toml`: Alacritty configuration using a matching palette and MesloLGS Nerd Font Propo.

## Install

Clone the repository, then link the configs. **Back up any existing files or directories at the destinations first**; the commands below intentionally do not overwrite them.

```sh
git clone https://github.com/0xdbff/dotfiles.git "$HOME/dotfiles"
mkdir -p "$HOME/.config"
test ! -e "$HOME/.config/nvim" && test ! -L "$HOME/.config/nvim" &&
  ln -s "$HOME/dotfiles/.config/nvim" "$HOME/.config/nvim"
test ! -e "$HOME/.config/alacritty.toml" && test ! -L "$HOME/.config/alacritty.toml" &&
  ln -s "$HOME/dotfiles/.config/alacritty.toml" "$HOME/.config/alacritty.toml"
```

Open Neovim to install its plugins, then follow the Neovim README for language tools. Install the configured Nerd Font separately for Alacritty.

## Sync changes

The symlinks make edits under `~/.config/nvim` and `~/.config/alacritty.toml` edits to this repository. There is no automatic commit or upload:

```sh
cd "$HOME/dotfiles"
git diff
git add .config
git commit -m "Update configs"
git push
```

On another linked machine, `git pull --ff-only` updates the configs. Review changes before publishing; never commit credentials or machine-local secrets.

## Attribution and license

- Neovim is derived from [NvChad/tinyvim](https://github.com/NvChad/tinyvim), created by [Sidhanth Rathod (@siduck)](https://github.com/siduck), with contributions from the [upstream contributors](https://github.com/NvChad/tinyvim/graphs/contributors), including Owen Giles (@bousii).
- The imported upstream revision is `cbf1ec6c74afb2917dca125ebeefe334901cb204`. Its Git metadata is intentionally not included; this is a customized configuration, not an unmodified upstream release.
- Customizations and dotfiles maintenance by **Diogo Antunes (@0xdbff)**, modified **2026-10-14**. Changes include the Cursor Midnight theme, multi-language tools, key mappings, tests, and Alacritty settings.
- Color palette inspiration: Cursor's **Dark Midnight** theme, with the [BioHazard786/cursor-theme-vscode](https://github.com/BioHazard786/cursor-theme-vscode) mirror referenced by the Alacritty config.

Distributed under **GNU GPL version 3**; see [LICENSE](LICENSE). The original Neovim license is also preserved at [`.config/nvim/LICENSE`](.config/nvim/LICENSE). Third-party plugins retain their own licenses and are downloaded separately. Provided without warranty.
