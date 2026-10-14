#!/bin/bash
# Source common.sh and apps.lock first. No installs or queries on source.
opencode_version() {
    local version
    version=$("$1" --version 2>/dev/null) || return 1
    version=${version#opencode }
    printf '%s\n' "${version#v}"
}
opencode_v2_installed() {
    local version
    command -v opencode >/dev/null 2>&1 || return 1
    version=$(opencode_version opencode) || return 1
    case "$version" in 2.*) return 0 ;; *) return 1 ;; esac
}

verify_nvim_version() {
    local version major minor
    version=$(nvim --version | head -n 1) || die 'Cannot query Neovim version'
    version=${version#NVIM v}; major=${version%%.*}; version=${version#*.}; minor=${version%%.*}
    case "$major:$minor" in *[!0-9:]*|:*) die 'Cannot parse Neovim version' ;; esac
    [ "$major" -gt 0 ] || [ "$minor" -ge 12 ] || die 'Neovim >=0.12 required; run brew upgrade neovim (macOS) or sudo dnf upgrade neovim (Fedora 44+), then rerun'
}

install_opencode_linux() {
    local arch sha archive stage destination version
    if [ "$DRY_RUN" = 1 ]; then
        plan reuse-opencode-if-version-2-otherwise-download-verified "$OPENCODE_VERSION" "$HOME/.local/bin/opencode"
        plan verify-sha256-from-apps.lock-before-extracting
        return
    fi
    if opencode_v2_installed; then log 'Already installed: OpenCode V2'; return; fi
    case "$(uname -m)" in
        aarch64|arm64) arch=arm64; sha=$OPENCODE_LINUX_ARM64_SHA256 ;;
        x86_64) arch=x64-baseline; sha=$OPENCODE_LINUX_X64_SHA256 ;;
        *) die 'OpenCode standalone supports Linux arm64 and x86_64 only' ;;
    esac
    stage=$(mktemp -d "$STATE_DIR/.opencode.XXXXXX") || die 'Cannot stage OpenCode'
    TEMP_PATHS+=("$stage")
    archive=$stage/opencode.tar.gz
    run curl --fail --location --proto '=https' --tlsv1.2 --output "$archive" "https://opencode.ai/files/bin/$OPENCODE_VERSION/opencode-linux-$arch.tar.gz"
    printf '%s  %s\n' "$sha" "$archive" | sha256sum --check --status || die 'OpenCode checksum mismatch; nothing extracted'
    run tar -xzf "$archive" -C "$stage" opencode
    [ -f "$stage/opencode" ] && [ ! -L "$stage/opencode" ] || die 'Unexpected OpenCode archive layout'
    run chmod 755 "$stage/opencode"
    version=$(opencode_version "$stage/opencode") || die 'Downloaded OpenCode cannot execute'
    [ "$version" = "$OPENCODE_VERSION" ] || die "Unexpected downloaded OpenCode version: $version"
    destination=$HOME/.local/bin/opencode
    run mkdir -p "$HOME/.local/bin"
    if [ -e "$destination" ] || [ -L "$destination" ]; then backup_move "$destination"; fi
    run mv "$stage/opencode" "$destination"
    export PATH="$HOME/.local/bin:$PATH"
    opencode_v2_installed || die 'OpenCode V2 is still shadowed on PATH'
}

link_alacritty_terminfo() {
    local resources entry relative
    resources=$1/Contents/Resources
    # tic uses hex directories on macOS; accept letter directories as well.
    for entry in "$resources"/61/alacritty "$resources"/61/alacritty-direct \
        "$resources"/a/alacritty "$resources"/a/alacritty-direct; do
        [ -f "$entry" ] || continue
        relative=${entry#"$resources"/}
        link_config_file "$entry" "$HOME/.terminfo/$relative"
    done
}

install_alacritty_macos() {
    local stage app destination marker
    destination=$HOME/Applications/Alacritty.app
    marker=$destination/Contents/dotfiles-build-commit
    if [ "$DRY_RUN" = 1 ]; then
        plan reuse-alacritty-if-installed-otherwise-build-locked "$ALACRITTY_VERSION" "$ALACRITTY_COMMIT" "$destination"
        plan cargo build --release --locked
        plan assemble-and-adhoc-sign-official-app-template "$HOME/.local/bin/alacritty"
        return
    fi
    if [ -f "$marker" ] && [ "$(cat "$marker")" = "$ALACRITTY_COMMIT" ] && [ -x "$destination/Contents/MacOS/alacritty" ]; then
        link_alacritty_terminfo "$destination"
        link_config_file "$destination/Contents/MacOS/alacritty" "$HOME/.local/bin/alacritty"
        return
    fi
    if [ ! -f "$marker" ] && command -v alacritty >/dev/null 2>&1; then log 'Already installed: Alacritty'; return; fi
    run xcode-select -p
    stage=$(mktemp -d "$STATE_DIR/.alacritty.XXXXXX") || die 'Cannot stage Alacritty'
    TEMP_PATHS+=("$stage")
    run git init -q "$stage"
    run git -C "$stage" remote add origin https://github.com/alacritty/alacritty.git
    run git -C "$stage" fetch --depth 1 origin "$ALACRITTY_COMMIT"
    run git -C "$stage" checkout --quiet --detach FETCH_HEAD
    [ "$(git -C "$stage" rev-parse HEAD)" = "$ALACRITTY_COMMIT" ] || die 'Alacritty source commit mismatch'
    # Same app template as upstream make app, but cargo uses --locked.
    (cd "$stage" && cargo build --release --locked) || die 'Alacritty build failed; install Xcode CLT and current Rust, then rerun'
    app=$stage/Alacritty.app
    run cp -R "$stage/extra/osx/Alacritty.app" "$app"
    run mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources/completions"
    run cp "$stage/target/release/alacritty" "$app/Contents/MacOS/alacritty"
    run cp "$stage/extra/completions/_alacritty" "$app/Contents/Resources/completions/"
    run tic -xe alacritty,alacritty-direct -o "$app/Contents/Resources" "$stage/extra/alacritty.info"
    printf '%s\n' "$ALACRITTY_COMMIT" > "$app/Contents/dotfiles-build-commit"
    run codesign --force --deep --sign - "$app"
    run mkdir -p "$HOME/Applications"
    if [ -e "$destination" ] || [ -L "$destination" ]; then backup_move "$destination"; fi
    run mv "$app" "$destination"
    link_alacritty_terminfo "$destination"
    link_config_file "$destination/Contents/MacOS/alacritty" "$HOME/.local/bin/alacritty"
}

install_apps() {
    case "$PLATFORM" in
        macos)
            if [ "$DRY_RUN" = 0 ]; then
                enable_homebrew
                xcode-select -p >/dev/null 2>&1 || die 'Install Xcode Command Line Tools first (xcode-select --install)'
            fi
            if [ "$DRY_RUN" = 1 ]; then
                plan brew install neovim tree-sitter-cli node python@3.13 go rust curl unzip
                plan brew install --cask font-meslo-lg-nerd-font
            else
                install_missing_brew_formulas neovim tree-sitter-cli node python@3.13 go rust curl unzip
                if ! "$DOTFILES_BREW_BIN" list --cask font-meslo-lg-nerd-font >/dev/null 2>&1; then
                    run "$DOTFILES_BREW_BIN" install --cask font-meslo-lg-nerd-font
                fi
            fi
            if [ "$DRY_RUN" = 1 ]; then
                plan reuse-opencode-if-version-2-otherwise brew install anomalyco/tap/opencode-v2
            elif opencode_v2_installed; then log 'Already installed: OpenCode V2'
            else
                # Never silently remove another formula to resolve a conflict.
                run brew install anomalyco/tap/opencode-v2
                opencode_v2_installed || die 'OpenCode V2 required; check for another opencode earlier on PATH'
            fi
            install_alacritty_macos ;;
        fedora)
            run sudo dnf install -y neovim alacritty tree-sitter-cli nodejs python3 golang rust cargo gcc make unzip curl tar
            install_opencode_linux
            log 'Fedora font: install MesloLGS Nerd Font Propo yourself if missing; no unverified font download is performed.' ;;
        *) die "Unsupported apps platform: $PLATFORM" ;;
    esac
    if [ "$DRY_RUN" = 1 ]; then
        plan verify-neovim-at-least-0.12
    else
        verify_nvim_version
    fi
    if [ "$DRY_RUN" = 1 ]; then
        log 'App/toolchain plan complete; no installation performed. Language tools remain opt-in via :ToolsInstall.'
    else
        log 'Basic toolchains installed. Language servers/parsers are opt-in via :ToolsInstall; large SDKs remain manual.'
    fi
}
