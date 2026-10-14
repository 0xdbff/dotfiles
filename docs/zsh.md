# Zsh environment

## Installation and trust

Supported targets: current macOS (Intel or Apple Silicon) and current Fedora.
Run as your ordinary account, never `sudo ./setup.sh`. You need network access,
Git to clone this repository, and permission to install packages. DNF operations
use sudo, with the normal password prompt. Neither an existing login shell nor
unrelated Neovim, Alacritty, Bash, or Fish settings are changed.

```sh
git clone https://github.com/0xdbff/dotfiles.git
cd dotfiles
./setup.sh --platform macos --dry-run
./setup.sh --platform macos
# Or, on Fedora:
./setup.sh --platform fedora --dry-run
./setup.sh --platform fedora
```

Homebrew is not bootstrapped automatically. If absent, first read the official
[Homebrew installation instructions](https://docs.brew.sh/Installation), review
the installer, and explicitly choose to install it. Follow its `brew shellenv`
instructions so `brew` is on PATH. This setup also recognizes the standard
`/opt/homebrew` and `/usr/local` prefixes. macOS needs Apple's Command Line Tools
(`xcode-select --install`) if not already available.

```sh
./setup.sh --help
./setup.sh --check
./setup.sh --platform macos --set-default-shell  # explicit opt-in only
```

The installer validates the platform against the running OS. Dry-run does not
install packages, download plugins, create directories/backups, or change files.
Installation stops on required package/download failures; fix the reported error
and rerun. Already installed packages are not gratuitously reinstalled/upgraded.
Package-manager versions follow the platform's maintained repositories rather
than pretending different macOS and Fedora packages are byte-identical.

Homebrew supplies the tools and all four plugins. Fedora supplies Zsh, Git, fzf,
zoxide, bat, eza, fd (`fd-find` package), ripgrep, tealdeer, autosuggestions, and
syntax highlighting. Where the configured Fedora repositories lack fzf-tab or
zsh-completions, full-commit Git pins in `plugins.lock` are used instead of adding
third-party repositories. Starship uses DNF if available; otherwise the installer
uses a versioned upstream release with a committed SHA-256 for supported Linux
architectures. No remote installer scripts are executed. Review the lock file
when updating these trusted dependencies; upstream plugins are executable code.

## Layout and preservation

```text
setup.sh                     platform validation and install orchestration
scripts/                     package installers, configuration, checks, benchmark
config/zsh/                  ordered, interactive-only modules
config/starship.toml         default two-line prompt
plugins.lock                 external dependency pins
tests/                       isolated offline and terminal tests
```

The managed configuration link is
`${XDG_CONFIG_HOME:-~/.config}/dotfiles-zsh -> <checkout>/config`. Keep the
checkout at its installed path; rerun setup after moving it. The initialization
block lives in `${ZDOTDIR:-$HOME}/.zshrc`. Export a non-default ZDOTDIR before
installation if you use one. Existing content outside the marked block remains
in place. Existing files/links that need replacement are backed up, with paths
printed by the installer. Malformed or ambiguous managed blocks are rejected.
Installation can safely be repeated; concurrent installations are refused.

Existing frameworks or a second prompt/completion initializer are not silently
removed. Disable those yourself after reviewing your backup: loading two full
shell environments can cause conflicting widgets or duplicated hooks. Put this
setup after environment/PATH declarations. This setup does not touch `.zshenv`,
so noninteractive scripts do not pay its initialization cost.

Fallback plugins live under `${XDG_DATA_HOME:-~/.local/share}/dotfiles-zsh/plugins`.
Completion caches and generated definitions live under
`${XDG_CACHE_HOME:-~/.cache}/dotfiles-zsh`. History lives under XDG state, is
private, persistent, and shared between sessions. Leading-space commands are
excluded. Consecutive duplicates and trivial navigation noise are filtered;
history is not indiscriminately deduplicated or cleared. Do not put secrets on a
command line; ignoring history is not a complete security boundary.
An existing regular, user-owned `~/.zsh_history` is copied once to the managed
history when it does not exist; the original is never removed or truncated.
Custom history locations are not automatically imported.

## Completion and command discovery

Zsh's completion engine supplies commands, flags, argument types, Git refs,
users/hosts, files, directories, aliases and binaries from PATH. `zsh-completions`
adds definitions; fzf-tab **displays**, but does not invent, this metadata.
Matching is case-insensitive, with relaxed native matching and fuzzy filtering
inside the selector. Groups have labels; flags show descriptions where the
upstream definition provides them. In the selector, type to filter, use arrows
to move, Enter to accept, Esc to cancel, and F1/F2 to change groups. Tab/Shift+Tab
behavior inside fzf differs from the native fallback; see the terminal checklist.
Without fzf-tab, native Zsh completion still works.

| Tool | Actual completion source |
| --- | --- |
| git, ssh, npm, dnf | Zsh's native definitions (versions vary by platform) |
| brew | Homebrew's `share/zsh/site-functions` |
| systemctl | Fedora/systemd package's Zsh definitions |
| cargo | Package/toolchain `_cargo`; copied from the active rustup toolchain on refresh |
| docker | Package/Desktop completion directory, or `docker completion zsh` |
| kubectl | Package definition, or `kubectl completion zsh` |
| pnpm (9+) | `pnpm completion zsh` |

The setup does **not** install Docker, Kubernetes, Node, Rust, or pnpm just to
complete them. Package completion directories are registered **before** the
single `compinit`. Generators run at install/refresh time, never on every shell
startup. Corepack network downloads are disabled during generation. Old or broken
optional generators warn and preserve any previous valid definition; the health
check reports missing registrations rather than claiming universal support.

After installing/updating developer tools or switching rustup toolchains:

```sh
./scripts/refresh-completions.sh
exec zsh
```

Only the named tools' documented completion generators run. Previews never run a
candidate as a command or execute the current command buffer. File previews are
bounded and avoid special files; directory previews use listings; command
discovery uses descriptions where available. Native SSH completion depends on
your SSH config/known hosts; hashed hosts cannot reveal their names. Some dynamic
completions (Docker objects, kubectl resources) necessarily query their tool or
service when you request them. Slow/offline services can make those completions
slow even though shell startup is fast.

## Editing and documentation

Emacs-style editing is the default. Right arrow accepts an entire suggestion at
the end of the buffer; normal cursor movement works elsewhere. Alt+F accepts a
word. Up/Down perform substring history search; Ctrl+R opens fzf history across
saved sessions. Ctrl+T inserts selected paths, Alt+C changes directory, and
`z name` / `zi` use zoxide without replacing `cd`. Use `..` / `...` for parents,
and explicit `ll` / `la` listings; ordinary `ls`, `cat`, `find`, and `grep` are
not silently replaced. `bcat` uses bat without a pager. Automatic command/spelling
correction is disabled. fzf uses fd when available, respecting ignore files and
excluding `.git`, with native traversal as the fallback.

Alt+H or F1 opens the man page for a safely parsed command, preserving the editing
buffer. Missing pages fall back gracefully to a description or guidance. This is
not an arbitrary shell parser: complex wrappers, assignments, pipelines and shell
builtins may need a direct `man command`. Use `whatis command` for a short
description, `apropos keyword` for a documentation search, and `tldr command` for
examples. Tealdeer may require `tldr --update` once to download its page cache.
`command --help` remains an explicit action by you, not something previews run.

On macOS configure Option as Meta/Esc in your terminal (Terminal.app: Profiles →
Keyboard → “Use Option as Meta key”). Esc then H/C/F also sends an Alt sequence.
F1, Shift+Tab and alternate arrow escape sequences depend on terminal settings;
standard escape sequences and terminfo bindings are used where available.

## Prompt and customization

The default prompt shows directory, branch, quiet dirty state, failure status,
duration above one second, and local prompt time (`HH:mm`), then a simple prompt
character on the second line. No runtime version barrage; no Nerd Font required.
Starship's built-in `time` is the time the prompt is rendered after a command,
**not** command duration. A long idle prompt does not tick like a clock. Git
untracked scanning is suppressed to limit work in large trees; tracked changes
remain visible. Extremely large or networked repositories may still need local
Git tuning; command timeouts can omit slow modules rather than blocking forever.

Edit `config/starship.toml` in this checkout to share a prompt change, or set
`STARSHIP_CONFIG` to a private TOML file before initialization. Use readable
ASCII defaults, or opt into a Nerd Font branch symbol yourself. You can customize
colors, truncation, `cmd_duration.min_time`, and `time.time_format` independently.
Local shell settings belong in
`${XDG_CONFIG_HOME:-~/.config}/dotfiles-zsh.local.zsh`, not managed modules. The
local file loads before the final syntax highlighter; custom widgets belong
there. Optional missing tools disable only their own integration.

## Updates, disable, restore

Review `git diff` before `git pull --ff-only`; then rerun setup. Update packaged
dependencies deliberately with Homebrew (`brew update; brew upgrade …`) or DNF
(`sudo dnf upgrade …`). The installer itself is not a general system upgrader.
Fallback Git plugins stay on their lock-file commits; maintainers should review
upstream changes, update full pins, and run the tests before publishing. Never
`git pull` managed fallback directories: that defeats the reproducible pin.

To disable, remove only the clearly marked dotfiles-zsh block from `.zshrc` and
open a new shell. To restore exactly, close other shells first, copy the printed
backup of `.zshrc` back to its original path (preserving any symlink arrangement),
and restore any config link backup the installer printed. Keep newer intentional
edits separately before restoring an old backup. Do not indiscriminately replace
all of `.zshrc` if you have edited it since installation.

After disabling, remove the `dotfiles-zsh` configuration **symlink**, managed
plugin/cache directories if no longer needed, and optionally the local settings
file. The symlink points into this checkout: do not recursively delete its target.
Keep the history file unless you explicitly want to erase it. Package removal is
manual because tools may be shared with other configurations. If you opted into
a default-shell change, restore your chosen registered shell with `chsh -s …`.

## Validation

```sh
./tests/run.sh                         # Python 3, Zsh; Starship tests if installed
./setup.sh --check                     # actual installed deps/plugins/registrations
zsh -f ./scripts/benchmark.zsh          # first + seven warm interactive startups
python3 tests/interactive.py           # installed plugins + fzf + tmux required
```

Offline tests use disposable HOME/XDG directories and never invoke package
installation. ShellCheck runs if available. `--check` sources the managed init in
an isolated interactive shell, not your personal `.zshrc`; this may warm its
completion cache. Registration checks are not proof of keystroke behavior.
The benchmark measures initialization, not terminal launch or prompt rendering;
the ~200 ms target is a goal, not a guaranteed number across hardware/toolchains.
The terminal runner uses a disposable tmux server and HOME to exercise actual
ZLE/fzf widgets, completion metadata, safe path insertion/previews, and shared
history. Its documentation test uses a controlled man stub; a real pager still
belongs in the manual checklist. See [recorded local evidence](zsh-validation.md)
for the measured environment and remaining platform checks. macOS and Fedora CI
jobs install and repeat the real setup; workflow presence is not a passing run.

### Terminal acceptance checklist (on **both** targets)

- Open a fresh terminal: no startup diagnostics; prompt at most two lines.
- Execute `echo shell-suggestion-check`, type its prefix, see muted ghost text,
  press Right then Enter; verify it ran. Test a completion-based suggestion too.
- Run `git --` Tab: descriptions, flags and fuzzy filtering; cancel without
  altering the command. Try `git switch` Tab in a repo with several branches.
- Tab a command prefix from PATH, mixed-case path, directory with spaces, and
  `ssh` host; verify candidates are appropriate, grouped and insert safely.
- Exercise Tab/Shift+Tab and F1/F2 inside the selector; Esc cancels. Confirm
  ordinary Tab/native completion after `disable-fzf-tab`, then re-enable it.
- Ctrl+R selects history without executing it. Ctrl+T safely inserts a filename
  with spaces/quotes; Alt+C changes directory. Up/Down match a middle substring.
- Type `git status`, press Alt+H, quit the pager: same buffer and cursor. Try a
  command without a man page and a malicious-looking shell fragment: no execution.
- Check each installed Docker/kubectl/cargo/npm/pnpm/systemctl/brew/dnf command's
  subcommands and short/long flags. Do not count absent tools as tested.
- In two shells, add distinct commands; check shared saved history, duplicates,
  and leading-space exclusion without losing old history.
- `true`: no duration/status noise; `false`: failure; `sleep 1.4`: duration and
  current prompt time. Git clean/modified repo: useful but quiet status.
- Rerun install: no duplicate block, identical config, no needless backups or
  reinstalls. Rename an optional plugin temporarily: native completion still works.
- Measure startup on target hardware; inspect large-repository prompt latency.

### Known differences from Fish

This remains Zsh, with Zsh quoting, word splitting and scripting rules. Flag/help
quality depends on actual completion metadata; it does not scrape every binary's
help text or Fish's man-page cache. The fuzzy selector cannot invent missing
flags. Inline suggestions combine asynchronous history and native completion,
not Fish's exact ranking model. Truecolor, Meta keys, terminal width and package
versions affect presentation. Carapace is deliberately not enabled by default:
native/tool-generated definitions keep startup and maintenance smaller without a
second competing completion dispatcher.

## Upstream integration references

Verified against official documentation when implementing this setup:
[Zsh completion](https://zsh.sourceforge.io/Doc/Release/Completion-System.html),
[fzf-tab load order and previews](https://github.com/Aloxaf/fzf-tab),
[autosuggestion strategies](https://github.com/zsh-users/zsh-autosuggestions),
[syntax highlighting load order](https://github.com/zsh-users/zsh-syntax-highlighting/blob/master/INSTALL.md),
[zsh-completions fpath](https://github.com/zsh-users/zsh-completions),
[fzf key bindings](https://github.com/junegunn/fzf#setting-up-shell-integration),
[Starship modules](https://starship.rs/config/),
[Docker completion](https://docs.docker.com/engine/cli/completion/),
[kubectl completion](https://kubernetes.io/docs/tasks/tools/install-kubectl-macos/#enable-shell-autocompletion),
[pnpm completion](https://pnpm.io/completion),
[Homebrew formulas](https://formulae.brew.sh/), and
[Fedora package inventory](https://packages.fedoraproject.org/).
