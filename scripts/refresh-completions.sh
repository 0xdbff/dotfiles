#!/bin/bash
# Run at installation/update time, never on interactive shell startup.
set -eu
umask 077

cache=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-zsh
case "$cache" in /*) ;; *) echo 'XDG_CACHE_HOME must be absolute.' >&2; exit 1 ;; esac
if [ -L "$cache" ] || [ -L "$cache/completions" ]; then
    echo 'Refusing symlinked managed completion cache.' >&2
    exit 1
fi
mkdir -p "$cache/completions"
chmod 700 "$cache" "$cache/completions"
command -v zsh >/dev/null || { echo 'zsh is required to validate completions.' >&2; exit 1; }
work=$(mktemp -d "$cache/.refresh.XXXXXX")
trap 'rm -rf "$work"' EXIT
failed=0
changed=0

# Only these known, documented generators run. No candidate or command buffer
# is evaluated. Corepack must not download a package just to generate completion.
generate() {
    local tool=$1
    shift
    command -v "$tool" >/dev/null 2>&1 || return 0
    printf 'Completion: %s\n' "$tool"
    if COREPACK_ENABLE_NETWORK=0 COREPACK_ENABLE_DOWNLOAD_PROMPT=0 \
        "$tool" "$@" >"$work/_$tool" 2>"$work/errors" &&
        [ -s "$work/_$tool" ] &&
        grep -q '^#compdef ' "$work/_$tool" &&
        zsh -fn "$work/_$tool"; then
        if ! cmp -s "$work/_$tool" "$cache/completions/_$tool"; then
            mv "$work/_$tool" "$cache/completions/_$tool"
            changed=1
        fi
    else
        printf 'WARN: %s generator unavailable/invalid; keeping previous or native definitions.\n' "$tool" >&2
        cat "$work/errors" >&2
        failed=1
    fi
}

generate docker completion zsh
generate kubectl completion zsh
generate pnpm completion zsh

# Cargo ships a real Zsh definition, not a `cargo completion` subcommand.
# rustup's active toolchain can change; refresh after switching toolchains.
if command -v cargo >/dev/null 2>&1; then
    cargo_path=$(command -v cargo)
    if command -v rustup >/dev/null 2>&1; then
        cargo_path=$(rustup which cargo 2>/dev/null || printf '%s' "$cargo_path")
    fi
    cargo_completion=${cargo_path%/bin/cargo}/share/zsh/site-functions/_cargo
    if [ -f "$cargo_completion" ] && zsh -fn "$cargo_completion"; then
        cp "$cargo_completion" "$work/_cargo"
        if ! cmp -s "$work/_cargo" "$cache/completions/_cargo"; then
            mv "$work/_cargo" "$cache/completions/_cargo"
            changed=1
        fi
        printf 'Completion: cargo (toolchain definition)\n'
    fi
fi

# Changed definitions are a cache invalidation event. compinit re-registers new
# #compdef headers even when the number of installed completion files is equal.
if [ "$changed" -eq 1 ]; then
    find "$cache" -maxdepth 1 -type f -name 'zcompdump*' -exec rm -f {} \;
fi
if [ "$failed" -ne 0 ]; then
    echo 'Some optional generators failed. See --check; native definitions remain usable.' >&2
fi
# Missing/old optional developer tools must not break the base installation.
exit 0
