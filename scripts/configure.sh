#!/bin/bash
# Source common.sh, set DOTFILES_ROOT, then call configure_dotfiles.
# This file intentionally does not execute anything when sourced.
MANAGED_BEGIN='# >>> dotfiles-zsh >>>'
MANAGED_END='# <<< dotfiles-zsh <<<'

resolve_zshrc() {
    local target link count
    target=$ZSHRC; count=0
    while [ -L "$target" ]; do
        count=$((count + 1)); [ "$count" -le 40 ] || die "Symlink loop: $ZSHRC"
        link=$(readlink "$target") || die "Cannot read symlink: $target"
        case "$link" in /*) target=$link ;; *) target=$(dirname -- "$target")/$link ;; esac
    done
    printf '%s\n' "$target"
}
validate_configuration() {
    local target
    initialize_paths
    target=$(resolve_zshrc)
    if [ -e "$target" ]; then
        [ -f "$target" ] || die "Not a regular .zshrc: $target"
        [ -r "$target" ] || die "Cannot read $target"
        # Reject duplicates, unmatched markers, nested markers and marker-like corruption.
        awk -v begin="$MANAGED_BEGIN" -v end="$MANAGED_END" '
          $0 == begin { if (inside || seen++) exit 1; inside=1; next }
          $0 == end { if (!inside) exit 1; inside=0; next }
          /dotfiles-zsh *(>>>|<<<)|[<>][<>][<>] *dotfiles-zsh/ { exit 1 }
          END { if (inside) exit 1 }
        ' "$target" || die "Malformed or duplicate dotfiles-zsh block in $target; repair it before rerunning"
    fi
}
configure_dotfiles() {
    local target dir temp quoted backup block
    validate_configuration
    if [ "$DRY_RUN" = 1 ]; then
        plan symlink-with-backup "$DOTFILES_ROOT/config" "$CONFIG_LINK"
        plan manage-zshrc-block-preserving-symlinks "$ZSHRC" "$CONFIG_LINK/zsh/init.zsh"
        return
    fi
    command -v cmp >/dev/null 2>&1 || die 'cmp is required (Fedora: install diffutils); no configuration changed'
    [ -f "$DOTFILES_ROOT/config/zsh/init.zsh" ] || die 'Missing config/zsh/init.zsh in checkout'
    [ -f "$DOTFILES_ROOT/config/starship.toml" ] || die 'Missing config/starship.toml in checkout'
    # Seed the new XDG history once; never truncate or modify the old history.
    if [ ! -e "$STATE_DIR/history" ] && [ ! -L "$STATE_DIR/history" ] &&
        [ -f "$HOME/.zsh_history" ] && [ ! -L "$HOME/.zsh_history" ] && [ -O "$HOME/.zsh_history" ]; then
        [ ! -L "$STATE_DIR" ] || die "Refusing symlinked managed history directory: $STATE_DIR"
        mkdir -p "$STATE_DIR"
        cp "$HOME/.zsh_history" "$STATE_DIR/history" || die 'Cannot copy previous Zsh history'
        chmod 600 "$STATE_DIR/history"
        log 'Copied previous ~/.zsh_history into private XDG history; original left untouched.'
    fi
    mkdir -p "$CONFIG_HOME"
    if [ -L "$CONFIG_LINK" ] && [ "$(readlink "$CONFIG_LINK")" = "$DOTFILES_ROOT/config" ]; then
        log "Already linked: $CONFIG_LINK"
    else
        if [ -e "$CONFIG_LINK" ] || [ -L "$CONFIG_LINK" ]; then backup_move "$CONFIG_LINK"; fi
        ln -s "$DOTFILES_ROOT/config" "$CONFIG_LINK" || die "Cannot link $CONFIG_LINK"
    fi
    target=$(resolve_zshrc); dir=$(dirname -- "$target")
    mkdir -p "$dir"
    temp=$(mktemp "$dir/.dotfiles-zshrc.XXXXXX") || die 'Cannot stage .zshrc'
    TEMP_PATHS+=("$temp")
    # Single-quote the absolute path, including any embedded apostrophes.
    quoted=$(printf '%s' "$CONFIG_LINK/zsh/init.zsh" | sed "s/'/'\\\\''/g")
    block=$(mktemp "$dir/.dotfiles-zsh-block.XXXXXX") || die 'Cannot stage managed block'
    TEMP_PATHS+=("$block")
    printf '%s\n%s\n%s\n' "$MANAGED_BEGIN" "source '$quoted'" "$MANAGED_END" > "$block"
    if [ -f "$target" ]; then
        # Preserve file permissions and everything outside the one managed block.
        cp -p "$target" "$temp"
        if grep -Fxq "$MANAGED_BEGIN" "$target"; then
            awk -v begin="$MANAGED_BEGIN" -v end="$MANAGED_END" '
          NR == FNR { block=block $0 ORS; next }
          $0 == begin { printf "%s", block; inside=1; next }
          $0 == end { inside=0; next }
          !inside { print }
            ' "$block" "$target" > "$temp"
        else
            # Preserve even a missing final newline in the unmanaged original.
            cat "$target" > "$temp"
            if [ -s "$temp" ] && [ "$(tail -c 1 "$temp" | wc -l | tr -d ' ')" = 0 ]; then printf '\n' >> "$temp"; fi
            cat "$block" >> "$temp"
        fi
    else
        chmod 600 "$temp"
        cat "$block" > "$temp"
    fi
    rm -f "$block"
    if [ -f "$target" ] && cmp -s "$target" "$temp"; then
        rm -f "$temp"; log "Already configured: $ZSHRC"; return
    fi
    if [ -f "$target" ]; then
        backup=$(backup_path "$target")
        cp -p "$target" "$backup" || die "Cannot back up $target"
        log "Backup: $backup"
    fi
    mv -- "$temp" "$target" || die "Cannot update $target"
    log "Configured: $ZSHRC (existing symlinks preserved)"
}
