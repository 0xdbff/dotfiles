#!/bin/bash
# Source common.sh, set DOTFILES_ROOT, initialize_paths, then call this module.
# Sourcing has no side effects. Keep OpenCode's other settings/data untouched.
validate_dotfiles_configs() {
    local source
    for source in "$DOTFILES_ROOT/.config/nvim" "$DOTFILES_ROOT/.config/alacritty.toml" \
        "$DOTFILES_ROOT/.config/btop/btop.conf" \
        "$DOTFILES_ROOT/.config/opencode/cli.json" \
        "$DOTFILES_ROOT/.config/opencode/themes/cursor-midnight.json"; do
        [ -e "$source" ] || die "Missing configuration in checkout: $source"
    done
    [ -d "$DOTFILES_ROOT/.config/nvim" ] || die 'Neovim configuration must be a directory'
}

link_config_file() {
    local source destination
    source=$1; destination=$2
    if [ "$DRY_RUN" = 1 ]; then
        plan symlink-with-backup "$source" "$destination"; return
    fi
    if [ -L "$destination" ] && [ "$(readlink "$destination")" = "$source" ]; then
        log "Already linked: $destination"; return
    fi
    mkdir -p "$(dirname -- "$destination")" || die "Cannot create parent for $destination"
    if [ -e "$destination" ] || [ -L "$destination" ]; then backup_move "$destination"; fi
    ln -s "$source" "$destination" || die "Cannot link $destination"
    log "Linked: $destination -> $source"
}

link_dotfiles_configs() {
    initialize_paths
    validate_dotfiles_configs
    link_config_file "$DOTFILES_ROOT/.config/nvim" "$CONFIG_HOME/nvim"
    link_config_file "$DOTFILES_ROOT/.config/alacritty.toml" "$CONFIG_HOME/alacritty/alacritty.toml"
    link_config_file "$DOTFILES_ROOT/.config/btop/btop.conf" "$CONFIG_HOME/btop/btop.conf"
    link_config_file "$DOTFILES_ROOT/.config/opencode/cli.json" "$CONFIG_HOME/opencode/cli.json"
    link_config_file "$DOTFILES_ROOT/.config/opencode/themes/cursor-midnight.json" "$CONFIG_HOME/opencode/themes/cursor-midnight.json"
    # Do not touch the legacy $CONFIG_HOME/alacritty.toml.
}
