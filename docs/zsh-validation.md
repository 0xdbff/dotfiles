# Local validation evidence

**Historical local evidence, not CI acceptance.** The first hosted run later
failed because Fedora lacked `cmp`/`diffutils` and the macOS terminal assertion
whitelisted Git description wording. The October 18 fixes add those regression
checks and the full `scripts/ci.sh` gate; current results are recorded separately
in [CI validation](ci-validation.md).

Recorded 2026-10-14 on macOS ARM64, Darwin 25, system Zsh 5.9, Bash 3.2,
Starship 1.23.0, and ShellCheck 0.11.0.

All configuration writes and terminal sessions used disposable HOME/XDG
directories. Homebrew artifacts were **fetched and extracted**, not installed
into the user's environment: fzf 0.74.5, fzf-tab 1.3.0, autosuggestions 0.7.1,
syntax highlighting 0.8.0, completions 0.36.0, and supporting tools. The sandbox
bat bottle was relocated to sandbox oniguruma and the existing libgit2 library.
pnpm 12.11.2's registry package was SHA-512 SRI verified and used only in the
sandbox. Existing Neovim/Alacritty and live shell configuration were unchanged.

## Passed

- `./tests/run.sh`: **28 tests**, plus ShellCheck and Bash/Zsh syntax checks.
  Coverage includes OS validation, mutation-free plans, backup/quoting/symlink
  preservation, repeat configuration, malformed blocks, install locking and
  package-failure short circuit, missing-formula selection, pinned Git fixtures,
  optional-tool fallback, secure dumps, quiet generated registrations, pnpm's
  sourced adapter, history settings, and actual Starship clean/dirty/failure/time/
  duration rendering. Package transactions and download failures in this suite
  are explicit mocks, not evidence of real installation.
- `python3 tests/interactive.py`: **17 actual terminal checks passed** using
  a separate tmux server: ghost/right acceptance; Git flag descriptions and
  branches; first-Tab flags for Docker, kubectl, cargo, pnpm, npm, brew and SSH;
  completion-based suggestions; quoted/shell-looking Ctrl+T paths; safe Tab file
  previews; spaced Alt+C navigation; Ctrl+R without execution; substring arrows;
  help invocation and buffer preservation; two-session saved/shared history,
  leading-space exclusion and consecutive deduplication.
- Real `docker completion zsh`, `kubectl completion zsh`, the active toolchain's
  `_cargo`, and `pnpm completion zsh` were generated, syntax-validated and used
  in those terminal checks. The pnpm adapter is sourced once after compinit;
  treating it as an ordinary `_pnpm` autoload would miss its real dispatcher.
- Sandbox `./setup.sh --check`: all required dependencies, four integrations,
  widgets, history privacy, default prompt, and installed command registrations
  reported healthy, with no startup diagnostics.
- `zsh -f scripts/benchmark.zsh`: **209.6 ms** after explicitly removing only the
  sandbox dump; **50.1 ms median warm initialization**, range 49.6–50.5 ms over
  seven runs. These numbers include ordered interactive initialization but not
  terminal launch or Starship's first prompt rendering. They are not a guarantee
  on other hardware, filesystems or user configurations.
- `git diff --check`; independent security and acceptance review. Review findings
  concerning inherited correction options, history health and managed-block
  detection were fixed and regression-tested.

## Not validated locally

- Actual Homebrew/DNF package installation, Fedora runtime/package layouts,
  `/etc/shells` edits or `chsh`; no whole-installer root execution or shell change
  was performed. macOS/Fedora CI jobs are provided but have **not** been run here.
- systemctl/DNF interactive flags: unavailable on this Mac, explicitly skipped.
- A real man pager's terminal restoration: the automated widget test uses a man
  stub. `man -w ls` and `whatis -- ls` were separately exercised on macOS.
- Every subcommand/argument of every tool, live Docker/Kubernetes object
  completion, hashed SSH hosts, every terminal escape sequence, narrow-terminal
  wrapping, and large-repository prompt latency.

Complete the platform-specific terminal checklist in [the guide](zsh.md) before
treating those remaining behaviors as accepted on a target machine.
