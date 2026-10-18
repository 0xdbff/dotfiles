#!/bin/bash
# The same complete gate on hosted runners and a developer's target system.
# Use disposable HOME/XDG variables when testing without replacing live configs.
set -euo pipefail
umask 077
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
cd "$root"
platform=${1:?Usage: scripts/ci.sh macos|fedora}
case "$platform" in macos|fedora) ;; *) echo 'Expected macos or fedora.' >&2; exit 1 ;; esac
for tool in shellcheck tmux; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "Missing validation prerequisite: $tool (install with Homebrew/DNF)." >&2
        exit 1
    }
done
report=${DOTFILES_CI_REPORT_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-ci}
mkdir -p "$report"
export PATH="$HOME/.local/bin:$PATH"
export DOTFILES_TEST_ARTIFACT_DIR="$report/terminal"

snapshot() {
    python3 - "$report/$1" <<'PY'
import hashlib, json, os, pathlib, sys
config = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", str(pathlib.Path.home() / ".config")))
rc = pathlib.Path(os.environ.get("ZDOTDIR", str(pathlib.Path.home()))) / ".zshrc"
paths = [rc] + [config / relative for relative in (
    "dotfiles-zsh", "nvim", "alacritty/alacritty.toml", "opencode/cli.json",
    "opencode/themes/cursor-midnight.json", "btop/btop.conf")]
result = {}
for path in paths:
    entry = {"link": os.readlink(path) if path.is_symlink() else None,
             "backups": sorted(str(p) for p in path.parent.glob(path.name + ".dotfiles-backup.*"))}
    if path.is_file():
        entry["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
    result[str(path)] = entry
pathlib.Path(sys.argv[1]).write_text(json.dumps(result, sort_keys=True, indent=2) + "\n")
PY
}

./install.sh --platform "$platform" --dry-run 2>&1 | tee "$report/dry-run.log"
./install.sh --platform "$platform" 2>&1 | tee "$report/install.log"
snapshot before-repeat.json
./install.sh --platform "$platform" 2>&1 | tee "$report/repeat-install.log"
snapshot after-repeat.json
cmp "$report/before-repeat.json" "$report/after-repeat.json"
echo 'PASS full reinstall preserved managed configs, links and backup counts.'
./tests/run.sh 2>&1 | tee "$report/unit-and-lint.log"
./install.sh --check 2>&1 | tee "$report/health.log"
python3 tests/interactive.py 2>&1 | tee "$report/terminal.log"
python3 tests/apps.py 2>&1 | tee "$report/apps.log"

# Real locked plugins and Neovim startup. Keep the separate all-LSP/parser smoke
# strict and opt-in: Flutter/TeX and language servers are not base-install claims.
cp .config/nvim/lazy-lock.json "$report/nvim-lock-before.json"
nvim --headless -i NONE '+Lazy! restore' '+qa!' 2>&1 | tee "$report/nvim-restore.log"
cmp "$report/nvim-lock-before.json" .config/nvim/lazy-lock.json
nvim --headless -i NONE '+lua dofile(vim.fn.stdpath("config") .. "/tests/config-smoke.lua")' '+qa!' \
    2>&1 | tee "$report/nvim-core.log"
printf '\n'
zsh -f scripts/benchmark.zsh 2>&1 | tee "$report/startup.log"
echo 'PASS complete dotfiles installation, repeatability, config and runtime gates.'
