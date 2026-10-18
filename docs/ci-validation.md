# Complete runner validation

## October 18, 2026 changes

The original run [38571283231](https://github.com/0xdbff/dotfiles/actions/runs/38571283231)
failed for two reproducible reasons:

- Fedora's minimal image lacked `cmp`. Failed comparisons were treated as
  changed configuration, creating unnecessary backups. The installer now installs
  `diffutils` and refuses configuration writes if `cmp` is unavailable.
- Homebrew Zsh describes Git's `--version` as “prints the git suite version”.
  The terminal test expected four other English phrases despite the real metadata
  being displayed. It now requires a candidate row and nonempty native description,
  excluding prompt/query echoes and respecting terminal wrapping.

The expanded hosted run also exposed two real provider differences that the
earlier local tools did not show. Both were reproduced locally:

- In Fedora 44's native Zsh 5.9, bidirectional case folding combined with Git's
  branch matcher computed `fish-B` as a common prefix even though both real
  candidates were `fish-alpha` and `fish-beta`. Exact-prefix-first matching fixes
  normal branch completion. The remaining uppercase-prefix limitation of that
  old native provider is documented in the shell guide, not claimed fixed.
- npm 11.13+ stopped returning global options from `npm completion`. The adapter
  now generates real option names, short aliases and descriptions from the
  installed npm configuration definitions, while still calling npm's native
  protocol for commands/scripts/arguments. This was exercised with npm 12.2.0,
  including script-name completion. No handwritten option catalog replaces npm.

The expanded runner uses `scripts/ci.sh`, on both target platforms, for:

1. Actual full installation, repeat installation, and file/link/backup idempotence.
2. Offline regressions, syntax and ShellCheck.
3. Shell plus installed-application/version/config-link health checks.
4. Real ZLE/fzf keystrokes, flags, descriptions, safe previews and shared history.
5. Actual btop and isolated OpenCode standalone TUI startup and clean exit; no
   model prompts or live credentials. Process panes are not retained.
6. Fresh locked Neovim plugins and core theme/plugin/LSP-declaration startup.
7. Measured interactive shell initialization.

Every failed stage fails the job. Diagnostic reports are retained as Actions
artifacts for seven days. Fedora 44 is pinned, the checkout belongs to its normal
test account, and installer invocations never run as root. Checkout uses Node 24.

Neovim's all-language `tests/smoke.lua` is still strict. The base configuration
smoke does not claim Dart/Flutter/TeX SDKs, Mason tools or all parsers were
installed. Optional command tests distinguish an unprovisioned Corepack launcher
from a working pnpm binary; working tools cannot silently skip missing metadata.

## Local system evidence

Testing uses this macOS ARM64 system's actual Homebrew package installation and
real binaries, with disposable HOME/XDG paths rather than replacing live private
settings. The first real installation exposed an additional OpenCode V1 npm vs
V2 Homebrew PATH/link conflict. This is fixed by retaining the existing binary,
verifying V2, installing an unlinked V2 keg when necessary, and managing a backed-up
`~/.local/bin/opencode` link with user-local PATH precedence.

Real btop 1.4.7 and OpenCode 2.0.32 were started in separate test terminals and
exited normally. The btop panels rendered without elevated privileges, the shared
CLI/theme were loaded without submitting prompts, and repository configs were
unchanged. The full gate and hosted results must pass before calling the runner
accepted; historical October 14 sandbox evidence is not a passing CI result.

The final local `scripts/ci.sh macos` run passed: **47 tests**, ShellCheck,
installation/reinstallation snapshots, real Zsh workflows, both application
TUIs, and fresh locked Neovim bootstrap/core startup. Its original Lazy lock
remained byte-identical. Bootstrap now stages/checks out the locked manager
before publishing, and a failed checkout regression proves cleanup and retry.
Measured initialization was 221.0 ms first / 212.1 ms warm median (seven runs,
207.2–218.0 ms), excluding terminal launch/first prompt rendering. The approximate
200 ms goal is not a hidden bypass for functional checks.

Local optional checks explicitly did not exercise systemctl/DNF (absent on
macOS) or an unprovisioned Corepack pnpm launcher. Working Docker, kubectl,
cargo, npm, Homebrew and SSH flag completions were exercised. Hosted results
are tracked for the pushed commit rather than inferred from this local pass.
