#!/bin/bash
# Compatible with the Bash 3.2 shipped by macOS.
set -euo pipefail
umask 077
DOTFILES_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
export DOTFILES_ROOT
. "$DOTFILES_ROOT/scripts/common.sh"

usage() {
    cat <<'EOF'
Usage: ./setup.sh [--platform macos|fedora] [--dry-run] [--set-default-shell]
       ./setup.sh --check
       ./setup.sh --help

Installs packages, then links this checkout and adds one managed .zshrc block.
macos/fedora may also be supplied as a positional platform argument.
--dry-run           Print the plan; no writes, downloads, or package queries.
--check             Run scripts/check.sh without installing anything.
--set-default-shell Explicitly register Zsh if necessary, then run chsh as you.
Existing configuration is preserved; replacements receive unique backups.
Run as your normal user, never sudo ./setup.sh. Homebrew must already exist.
EOF
}

requested='' mode=install
DRY_RUN=0
SET_DEFAULT_SHELL=0
while [ "$#" -gt 0 ]; do
    case "$1" in
        --help|-h) usage; exit 0 ;;
        --dry-run) DRY_RUN=1 ;;
        --check) mode=check ;;
        --set-default-shell) SET_DEFAULT_SHELL=1 ;;
        --platform)
            [ "$#" -ge 2 ] || die '--platform needs macos or fedora'
            [ -z "$requested" ] || die 'Specify the platform only once'
            requested=$2; shift ;;
        --platform=*) [ -z "$requested" ] || die 'Specify the platform only once'; requested=${1#*=} ;;
        macos|fedora) [ -z "$requested" ] || die 'Specify the platform only once'; requested=$1 ;;
        *) die "Unknown argument: $1 (see --help)" ;;
    esac
    shift
done
if [ "$mode" = check ]; then
    [ "$DRY_RUN" = 0 ] && [ "$SET_DEFAULT_SHELL" = 0 ] && [ -z "$requested" ] || die '--check cannot be combined with install options'
    exec /bin/bash "$DOTFILES_ROOT/scripts/check.sh"
fi
case "$requested" in ''|macos|fedora) ;; *) die "Unsupported platform: $requested" ;; esac
PLATFORM=$(detect_platform) || die 'Supported platforms are macOS and Fedora only'
[ -z "$requested" ] || [ "$requested" = "$PLATFORM" ] || die "Requested $requested but detected $PLATFORM"
if [ "$DRY_RUN" = 0 ] && [ "$(id -u)" = 0 ]; then
    die 'Run as your normal user, not root; only package installation and /etc/shells registration use sudo'
fi
initialize_paths
. "$DOTFILES_ROOT/plugins.lock"
. "$DOTFILES_ROOT/scripts/configure.sh"
validate_configuration
if [ "$DRY_RUN" = 0 ]; then
    mkdir -p "$STATE_DIR"
    LOCK_DIR=$STATE_DIR/install.lock
    mkdir "$LOCK_DIR" 2>/dev/null || die "Installation lock exists: $LOCK_DIR (remove it only after verifying no installer is running)"
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
fi
# shellcheck source=/dev/null
. "$DOTFILES_ROOT/scripts/install-$PLATFORM.sh"
install_platform
configure_dotfiles
if [ "$DRY_RUN" = 1 ]; then
    plan "$DOTFILES_ROOT/scripts/refresh-completions.sh"
else
    /bin/bash "$DOTFILES_ROOT/scripts/refresh-completions.sh"
fi
if [ "$SET_DEFAULT_SHELL" = 1 ]; then set_default_shell; fi
if [ "$DRY_RUN" = 1 ]; then log 'Dry-run complete; no changes made.'
else log 'Done. Open a new Zsh session (or run zsh).'; fi
