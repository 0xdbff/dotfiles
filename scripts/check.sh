#!/bin/bash
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
if [ -n "${HOMEBREW_PREFIX:-}" ]; then
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
else
    for prefix in /opt/homebrew /usr/local; do
        if [ -x "$prefix/bin/brew" ]; then
            export PATH="$prefix/bin:$prefix/sbin:$PATH"
            break
        fi
    done
fi
export PATH="$HOME/.local/bin:$PATH"
failed=0
printf '%s\n' 'Dependency health (no installation or default-shell changes):'
for tool in zsh git fzf zoxide bat eza fd rg starship; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf 'OK   %-12s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf 'FAIL missing %s\n' "$tool"
        failed=1
    fi
done
command -v tldr >/dev/null 2>&1 || echo 'WARN optional tldr/tealdeer is unavailable.'
init=${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles-zsh/zsh/init.zsh
rc=${ZDOTDIR:-$HOME}/.zshrc
if [ -r "$init" ]; then
    printf 'OK   managed initialization: %s\n' "$init"
else
    printf 'FAIL missing configuration: %s\n' "$init"
    failed=1
fi
if [ -f "$rc" ] && awk '
    $0 == "# >>> dotfiles-zsh >>>" { if (inside || begins++) exit 1; inside=1; next }
    $0 == "# <<< dotfiles-zsh <<<" { if (!inside) exit 1; inside=0; ends++; next }
    END { if (inside || begins != 1 || ends != 1) exit 1 }
    ' "$rc"; then
    printf 'OK   exactly one managed initialization block in %s\n' "$rc"
else
    printf 'FAIL no initialization reference in %s\n' "$rc"
    failed=1
fi
if command -v zsh >/dev/null 2>&1; then
    for file in "$root"/config/zsh/*.zsh; do
        zsh -fn "$file" || failed=1
    done
    if [ -r "$init" ]; then
        # -d disables global rc files; -f disables user rc files. init is sourced
        # explicitly, so checking cannot run an unrelated personal startup file.
        zsh -dfi -o no_zle -c 'source "$1"; source "$2"' -- "$init" "$root/scripts/health.zsh" || failed=1
    fi
fi
if command -v starship >/dev/null 2>&1; then
    # Starship can return success while falling back after a TOML error: inspect
    # diagnostics too, rather than treating an exit code as proof of validity.
    work=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-check.XXXXXX")
    trap 'rm -rf "$work"' EXIT
    if STARSHIP_CONFIG="$root/config/starship.toml" STARSHIP_LOG=warn \
        STARSHIP_CACHE="$work" starship prompt --path "$root" --status 127 \
        --cmd-duration 1400 >"$work/prompt" 2>"$work/errors" &&
        ! grep -Eiq '(error|warn)' "$work/errors"; then
        echo 'OK   Starship rendered the supplied configuration.'
    else
        echo 'FAIL Starship configuration/render diagnostics:'
        cat "$work/errors"
        failed=1
    fi
fi
echo 'Interactive keystrokes and package transactions are not tested by --check.'
exit "$failed"
