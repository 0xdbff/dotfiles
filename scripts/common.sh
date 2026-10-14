#!/bin/bash
# Shared functions. Sourcing this file performs no installation or writes.
DRY_RUN=${DRY_RUN:-0}
TEMP_PATHS=()
log() { printf '%s\n' "$*"; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
plan() { printf '[plan]'; printf ' %q' "$@"; printf '\n'; }
run() {
    if [ "$DRY_RUN" = 1 ]; then plan "$@"; else
        "$@" || die "Command failed: $*; previous package operations may have succeeded. Fix the error and rerun."
    fi
}
enable_homebrew() {
    local brew_bin
    brew_bin=$(command -v brew || :)
    if [ -z "$brew_bin" ]; then
        for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
            [ ! -x "$brew_bin" ] || break
        done
    fi
    [ -x "$brew_bin" ] || die 'Homebrew is required first. See https://docs.brew.sh/Installation; it is never bootstrapped automatically.'
    DOTFILES_BREW_BIN=$brew_bin
    eval "$("$brew_bin" shellenv)"
}
install_missing_brew_formulas() {
    local package
    local missing=()
    for package in "$@"; do
        if [ "$package" = git ] && command -v git >/dev/null 2>&1; then continue; fi
        if ! "$DOTFILES_BREW_BIN" list --formula "$package" >/dev/null 2>&1; then
            missing+=("$package")
        fi
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        run "$DOTFILES_BREW_BIN" install "${missing[@]}"
    else
        log 'All requested Homebrew formulas are already installed.'
    fi
}
detect_platform() {
    local release_file=${1:-/etc/os-release}
    case "$(uname -s)" in
        Darwin) printf 'macos\n' ;;
        Linux)
            [ -r "$release_file" ] || return 1
            # Read only the distribution identifier, not executable shell content.
            case "$(sed -n 's/^ID=//p' "$release_file" | tr -d '\042\047')" in
                fedora) printf 'fedora\n' ;; *) return 1 ;;
            esac ;;
        *) return 1 ;;
    esac
}
absolute_path() { case "$2" in /*) ;; *) die "$1 must be an absolute path: $2" ;; esac; }
initialize_paths() {
    : "${HOME:?HOME must be set}"
    CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
    DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
    STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-zsh
    export CONFIG_LINK=$CONFIG_HOME/dotfiles-zsh
    PLUGIN_DIR=$DATA_HOME/dotfiles-zsh/plugins
    export ZSHRC=${ZDOTDIR:-$HOME}/.zshrc
    absolute_path HOME "$HOME"
    absolute_path XDG_CONFIG_HOME "$CONFIG_HOME"
    absolute_path XDG_DATA_HOME "$DATA_HOME"
    absolute_path XDG_CACHE_HOME "${XDG_CACHE_HOME:-$HOME/.cache}"
    absolute_path XDG_STATE_HOME "$STATE_DIR"
    absolute_path ZDOTDIR "${ZDOTDIR:-$HOME}"
    absolute_path DOTFILES_ROOT "$DOTFILES_ROOT"
}
cleanup() {
    local path
    for path in ${TEMP_PATHS[@]+"${TEMP_PATHS[@]}"}; do
        [ ! -e "$path" ] || rm -rf -- "$path"
    done
    [ -z "${LOCK_DIR:-}" ] || rmdir "$LOCK_DIR" 2>/dev/null || :
}
backup_path() {
    local base candidate n
    base=$1.dotfiles-backup.$(date +%Y%m%d%H%M%S)
    candidate=$base; n=0
    while [ -e "$candidate" ] || [ -L "$candidate" ]; do
        n=$((n + 1)); candidate=$base.$n
    done
    printf '%s\n' "$candidate"
}
backup_move() {
    local backup
    backup=$(backup_path "$1")
    mv -- "$1" "$backup" || die "Could not back up $1"
    log "Backup: $backup"
}
install_pinned_plugin() {
    local name url commit target marker stage head
    name=$1; url=$2; commit=$3; target=$PLUGIN_DIR/$name
    if [ "$DRY_RUN" = 1 ]; then
        plan install-pinned-plugin "$url" "$commit" "$target"; return
    fi
    if [ -e "$target" ] || [ -L "$target" ]; then
        [ ! -L "$target" ] && [ -d "$target/.git" ] && [ ! -L "$target/.git" ] || die "Refusing unowned plugin: $target"
        marker=$target/.git/dotfiles-owner
        [ -f "$marker" ] && [ "$(sed -n '1p' "$marker")" = "$url" ] || die "Refusing unowned plugin: $target"
        head=$(git -C "$target" rev-parse HEAD) || die "Invalid plugin repository: $target"
        [ "$(sed -n '2p' "$marker")" = "$head" ] || die "Plugin HEAD changed locally: $target"
        [ -z "$(git -C "$target" status --porcelain --untracked-files=all --ignored)" ] || die "Plugin has local changes (including ignored files): $target"
        [ "$head" != "$commit" ] || { log "Already pinned: $name"; return; }
    fi
    mkdir -p "$PLUGIN_DIR"
    stage=$(mktemp -d "$PLUGIN_DIR/.${name}.XXXXXX") || die 'Cannot create plugin staging directory'
    TEMP_PATHS+=("$stage")
    run git init -q "$stage"
    run git -C "$stage" remote add origin "$url"
    run git -C "$stage" fetch --quiet --depth 1 origin "$commit"
    run git -C "$stage" checkout --quiet --detach FETCH_HEAD
    [ "$(git -C "$stage" rev-parse HEAD)" = "$commit" ] || die "Plugin commit mismatch: $name"
    printf '%s\n%s\n' "$url" "$commit" > "$stage/.git/dotfiles-owner"
    if [ -e "$target" ]; then backup_move "$target"; fi
    mv -- "$stage" "$target" || die "Cannot publish plugin: $target"
}
set_default_shell() {
    local shell_path
    if [ "$DRY_RUN" = 1 ]; then
        plan register-zsh-in-/etc/shells-if-needed
        plan chsh -s '<discovered-zsh-path>'; return
    fi
    shell_path=$(command -v zsh) || die 'Zsh is not on PATH after package installation'
    absolute_path zsh "$shell_path"
    [ -x "$shell_path" ] || die "Zsh is not executable: $shell_path"
    if ! grep -Fxq "$shell_path" /etc/shells; then
        command -v sudo >/dev/null 2>&1 || die 'sudo is needed to register Zsh in /etc/shells'
        printf '%s\n' "$shell_path" | sudo tee -a /etc/shells >/dev/null || die 'Could not register Zsh in /etc/shells'
    fi
    # chsh is deliberately not run through sudo: change only the invoking user.
    run chsh -s "$shell_path"
}
