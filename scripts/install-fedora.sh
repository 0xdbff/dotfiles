#!/bin/bash
dnf_has_package() { dnf -q list "$1" >/dev/null 2>&1; }

install_starship_release() {
    local arch checksum archive stage actual binary destination marker staged_binary
    case "$(uname -m)" in
        x86_64) arch=x86_64; checksum=$STARSHIP_SHA256_X86_64 ;;
        aarch64|arm64) arch=aarch64; checksum=$STARSHIP_SHA256_AARCH64 ;;
        *) die 'No pinned Starship binary for this architecture; install a verified Starship package manually' ;;
    esac
    destination=$HOME/.local/bin/starship
    marker=$HOME/.local/bin/.starship-dotfiles-owned
    if [ -e "$destination" ] || [ -L "$destination" ]; then
        [ -f "$marker" ] && [ ! -L "$marker" ] && [ ! -L "$destination" ] || die "Refusing to replace unowned $destination"
        actual=$(sha256sum "$destination"); actual=${actual%% *}
        [ "$(sed -n '2p' "$marker")" = "$actual" ] || die "Starship binary modified locally: $destination"
        [ "$(sed -n '1p' "$marker")" != "$STARSHIP_VERSION/$arch" ] || { log 'Already pinned: starship'; return; }
    fi
    mkdir -p "$DATA_HOME/dotfiles-zsh" "$HOME/.local/bin"
    stage=$(mktemp -d "$DATA_HOME/dotfiles-zsh/.starship.XXXXXX") || die 'Cannot stage Starship'
    TEMP_PATHS+=("$stage")
    archive=starship-$arch-unknown-linux-musl.tar.gz
    run curl --fail --location --proto '=https' --tlsv1.2 --retry 2 --output "$stage/$archive" "https://github.com/starship/starship/releases/download/v$STARSHIP_VERSION/$archive"
    actual=$(sha256sum "$stage/$archive"); actual=${actual%% *}
    [ "$actual" = "$checksum" ] || die 'Starship archive checksum mismatch; nothing extracted or installed'
    # Extract only the expected member, not arbitrary paths from the archive.
    run tar -xzf "$stage/$archive" -C "$stage" starship
    binary=$stage/starship
    [ -f "$binary" ] && [ ! -L "$binary" ] || die 'Invalid Starship binary in archive'
    chmod 755 "$binary"
    actual=$(sha256sum "$binary"); actual=${actual%% *}
    # Stage on the destination filesystem before atomic publication.
    staged_binary=$(mktemp "$HOME/.local/bin/.starship-dotfiles.XXXXXX") || die 'Cannot stage Starship executable'
    TEMP_PATHS+=("$staged_binary")
    run cp "$binary" "$staged_binary"
    chmod 755 "$staged_binary"
    if [ -e "$destination" ]; then backup_move "$destination"; fi
    run mv "$staged_binary" "$destination"
    if [ -e "$marker" ] || [ -L "$marker" ]; then backup_move "$marker"; fi
    printf '%s\n%s\n' "$STARSHIP_VERSION/$arch" "$actual" > "$marker"
}

install_platform() {
    if [ "$DRY_RUN" = 1 ]; then
        plan require-dnf
        plan sudo dnf install -y zsh fzf zoxide bat eza fd-find ripgrep git tealdeer zsh-autosuggestions zsh-syntax-highlighting curl ca-certificates tar gzip coreutils
        plan dnf-probe-starship-zsh-completions-fzf-tab '(no queries during dry-run)'
        plan starship-dnf-or-checksum-pinned-release "$STARSHIP_VERSION" "$HOME/.local/bin/starship"
        install_pinned_plugin zsh-completions "$ZSH_COMPLETIONS_URL" "$ZSH_COMPLETIONS_COMMIT"
        install_pinned_plugin fzf-tab "$FZF_TAB_URL" "$FZF_TAB_COMMIT"
        return
    fi
    command -v dnf >/dev/null 2>&1 || die 'Fedora DNF is required first'
    command -v sudo >/dev/null 2>&1 || die 'sudo is required for DNF; run the installer as your normal user'
    log 'DNF package installation needs administrator privileges; sudo may request your password.'
    run sudo dnf install -y zsh fzf zoxide bat eza fd-find ripgrep git tealdeer zsh-autosuggestions zsh-syntax-highlighting curl ca-certificates tar gzip coreutils
    if dnf_has_package starship; then
        run sudo dnf install -y starship
    elif command -v starship >/dev/null 2>&1; then
        log 'Using existing Starship from PATH'
    else
        install_starship_release
    fi
    export PATH="$HOME/.local/bin:$PATH"
    if dnf_has_package zsh-completions; then
        run sudo dnf install -y zsh-completions
    else
        install_pinned_plugin zsh-completions "$ZSH_COMPLETIONS_URL" "$ZSH_COMPLETIONS_COMMIT"
    fi
    if dnf_has_package fzf-tab; then
        run sudo dnf install -y fzf-tab
    else
        install_pinned_plugin fzf-tab "$FZF_TAB_URL" "$FZF_TAB_COMMIT"
    fi
}
