#!/bin/bash
# Full bootstrap, compatible with macOS Bash 3.2. Run as an ordinary user.
set -euo pipefail
umask 077
DOTFILES_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
export DOTFILES_ROOT
. "$DOTFILES_ROOT/scripts/common.sh"

usage() {
    cat <<'EOF'
Usage: ./install.sh [--platform macos|fedora] [--dry-run] [--set-default-shell]
       ./install.sh --links-only [--dry-run]
       ./install.sh --check | --help

Installs Zsh dependencies via setup.sh, then Neovim, Alacritty, OpenCode V2
and basic toolchains; links shell, editor, terminal and OpenCode settings.
--links-only        Link all configurations without packages or shell changes.
--dry-run           Print the plan; no writes, downloads or package queries.
--set-default-shell Explicitly change your default shell after successful setup.
--check             Delegate to setup.sh --check (no installation).
Run as your normal user, not sudo. macOS needs Homebrew and Xcode CLT.
macOS builds Alacritty 0.17.0 locally (potentially several minutes) because
the Homebrew Alacritty cask is disabled. App goes in ~/Applications.
Neovim plugin/language tools are opt-in later via :ToolsInstall; Flutter,
TeX and other large language SDKs are not installed by this script.
EOF
}

requested='' mode=install
DRY_RUN=0; SET_DEFAULT_SHELL=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --dry-run) DRY_RUN=1 ;;
        --links-only) [ "$mode" = install ] || die 'Conflicting modes'; mode=links ;;
        --check) [ "$mode" = install ] || die 'Conflicting modes'; mode=check ;;
        --set-default-shell) SET_DEFAULT_SHELL=1 ;;
        --platform) [ "$#" -ge 2 ] || die '--platform needs macos or fedora'
            [ -z "$requested" ] || die 'Specify platform only once'; requested=$2; shift ;;
        --platform=*) [ -z "$requested" ] || die 'Specify platform only once'; requested=${1#*=} ;;
        *) die "Unknown argument: $1 (see --help)" ;;
    esac
    shift
done
if [ "$mode" = check ]; then
    [ "$DRY_RUN" = 0 ] && [ "$SET_DEFAULT_SHELL" = 0 ] && [ -z "$requested" ] || die '--check cannot be combined with install options'
    exec /bin/bash "$DOTFILES_ROOT/setup.sh" --check
fi
case "$requested" in ''|macos|fedora) ;; *) die "Unsupported platform: $requested" ;; esac
if [ "$mode" = install ] || [ -n "$requested" ]; then
    PLATFORM=$(detect_platform) || die 'Package installation supports macOS and Fedora only (use --links-only for local configuration)'
    [ -z "$requested" ] || [ "$requested" = "$PLATFORM" ] || die "Requested $requested but detected $PLATFORM"
fi
[ "$mode" != links ] || [ "$SET_DEFAULT_SHELL" = 0 ] || die '--set-default-shell requires a normal installation'
if [ "$DRY_RUN" = 0 ] && [ "$(id -u)" = 0 ]; then die 'Run as your normal user, not root'; fi
initialize_paths
. "$DOTFILES_ROOT/scripts/configure.sh"
. "$DOTFILES_ROOT/scripts/link-configs.sh"
validate_configuration
validate_dotfiles_configs
# Separate outer lock spans setup's own lock, every app operation and linking.
# Acquire shared setup lock again for the final configuration phase.
FULL_LOCK=''; LOCK_DIR=''
full_cleanup() {
    cleanup
    [ -z "$FULL_LOCK" ] || rmdir "$FULL_LOCK" 2>/dev/null || :
}
if [ "$DRY_RUN" = 0 ]; then
    mkdir -p "$STATE_DIR"
    candidate=$STATE_DIR/full-install.lock
    mkdir "$candidate" 2>/dev/null || die "Full installation lock exists: $candidate (remove only after verifying no installer is running)"
    FULL_LOCK=$candidate
    trap full_cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
fi
if [ "$mode" = install ]; then
    args=(--platform "$PLATFORM")
    [ "$DRY_RUN" = 0 ] || args+=(--dry-run)
    # In dry-run setup itself prints its package/config plans, without queries.
    /bin/bash "$DOTFILES_ROOT/setup.sh" "${args[@]}"
    . "$DOTFILES_ROOT/apps.lock"
    . "$DOTFILES_ROOT/scripts/install-apps.sh"
    install_apps
fi
if [ "$DRY_RUN" = 0 ]; then
    candidate=$STATE_DIR/install.lock
    mkdir "$candidate" 2>/dev/null || die "Installation lock exists: $candidate (another setup may be running)"
    LOCK_DIR=$candidate
fi
if [ "$mode" = links ]; then configure_dotfiles; fi
link_dotfiles_configs
if [ "$SET_DEFAULT_SHELL" = 1 ]; then set_default_shell; fi
if [ "$DRY_RUN" = 1 ]; then log 'Dry-run complete; no changes made.'
else log 'Done. Open a new Zsh session. Run :ToolsInstall inside Neovim when you want language tools.'; fi
