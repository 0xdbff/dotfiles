#!/bin/bash
# Read-only checks for the applications and individual managed config links.
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
if [ -n "${HOMEBREW_PREFIX:-}" ]; then
    export PATH="$HOMEBREW_PREFIX/bin:$HOMEBREW_PREFIX/sbin:$PATH"
fi
export PATH="$HOME/.local/bin:$PATH"
. "$root/scripts/common.sh"
. "$root/scripts/install-apps.sh"
failed=0
for tool in nvim alacritty opencode btop tree-sitter node python3 go cargo rustc; do
    if command -v "$tool" >/dev/null 2>&1; then
        printf 'OK   app/tool %-12s %s\n' "$tool" "$(command -v "$tool")"
    else
        printf 'FAIL missing app/tool %s\n' "$tool"
        failed=1
    fi
done
if command -v nvim >/dev/null 2>&1; then
    (verify_nvim_version) || failed=1
fi
if ! opencode_v2_installed; then
    echo 'FAIL OpenCode V2 is required for cli.json and the shared theme.'
    failed=1
fi
config=${XDG_CONFIG_HOME:-$HOME/.config}
check_link() {
    if [ -L "$config/$1" ] && [ "$(readlink "$config/$1")" = "$root/$2" ]; then
        printf 'OK   managed link %s\n' "$config/$1"
    else
        printf 'FAIL missing/wrong managed link %s (expected %s)\n' "$config/$1" "$root/$2"
        failed=1
    fi
}
check_link nvim .config/nvim
check_link alacritty/alacritty.toml .config/alacritty.toml
check_link opencode/cli.json .config/opencode/cli.json
check_link opencode/themes/cursor-midnight.json .config/opencode/themes/cursor-midnight.json
check_link btop/btop.conf .config/btop/btop.conf
if command -v alacritty >/dev/null 2>&1 && [ -r "$config/alacritty/alacritty.toml" ]; then
    if alacritty migrate --dry-run --config-file "$config/alacritty/alacritty.toml" >/dev/null; then
        echo 'OK   Alacritty parsed the linked config (no GUI or writes).'
    else
        echo 'FAIL Alacritty configuration could not be parsed.'
        failed=1
    fi
fi
if command -v python3 >/dev/null 2>&1; then
    python3 - "$config" <<'PY' || failed=1
import json, pathlib, sys
config = pathlib.Path(sys.argv[1]) / "opencode"
cli = json.loads((config / "cli.json").read_text())
assert cli["theme"] == {"name": "cursor-midnight", "mode": "dark"}
theme = json.loads((config / "themes/cursor-midnight.json").read_text())
assert "base" in theme and "dark" in theme
print("OK   linked OpenCode CLI settings and theme JSON.")
PY
fi
echo 'Application startup and terminal behavior are exercised separately by tests/apps.py.'
exit "$failed"
