"""Offline regression tests. All writes go to disposable HOME/XDG directories."""
import os
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class Sandbox(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-test-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        XDG_CONFIG_HOME=str(self.home / "config"),
                        XDG_DATA_HOME=str(self.home / "data"),
                        XDG_CACHE_HOME=str(self.home / "cache"),
                        XDG_STATE_HOME=str(self.home / "state"), TERM="xterm-256color",
                        GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null")
        self.env.pop("STARSHIP_CONFIG", None)
        self.env.pop("DOTFILES_ZSH_LOADED", None)

    def run_cmd(self, args, **kwargs):
        return subprocess.run(args, env=self.env, cwd=ROOT, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              timeout=30, **kwargs)

    def zsh(self, code, interactive=True):
        return self.run_cmd(["zsh", "-dfi" if interactive else "-df", "-c",
                             'source "$1"; ' + code, "--",
                             str(ROOT / "config/zsh/init.zsh")])


class StaticAndCLI(Sandbox):
    def test_shell_syntax(self):
        for f in [ROOT / "setup.sh", ROOT / "install.sh", *ROOT.glob("scripts/*.sh")]:
            r = self.run_cmd(["bash", "-n", str(f)])
            self.assertEqual(r.returncode, 0, (f, r.stderr))
        for f in ROOT.glob("config/zsh/*.zsh"):
            r = self.run_cmd(["zsh", "-fn", str(f)])
            self.assertEqual(r.returncode, 0, (f, r.stderr))

    def test_help_and_bad_arguments_do_not_write(self):
        r = self.run_cmd(["bash", "setup.sh", "--help"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("--dry-run", r.stdout)
        for args in [["--wat"], ["--platform"], ["--platform", "windows"]]:
            self.assertNotEqual(self.run_cmd(["bash", "setup.sh", *args]).returncode, 0)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_platform_mismatch_rejected(self):
        wrong = "fedora" if platform.system() == "Darwin" else "macos"
        r = self.run_cmd(["bash", "setup.sh", "--platform", wrong, "--dry-run"])
        self.assertNotEqual(r.returncode, 0, r.stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    @unittest.skipUnless(platform.system() == "Darwin", "macOS dry-run on macOS")
    def test_dry_run_is_read_only(self):
        r = self.run_cmd(["bash", "setup.sh", "--platform", "macos", "--dry-run"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("brew", r.stdout.lower())
        self.assertEqual(list(self.home.iterdir()), [])


@unittest.skipUnless(shutil.which("zsh"), "requires Zsh")
class Configuration(Sandbox):
    def test_noninteractive_is_noop(self):
        r = self.zsh('print -r -- "OK:$options[interactive]"', interactive=False)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "OK:off")
        self.assertEqual(r.stderr, "")
        self.assertEqual(list(self.home.iterdir()), [])

    def test_native_completion_and_history(self):
        r = self.zsh('''
          (( $+functions[compdef] )) || exit 11
          [[ $_comps[git] == _git && $_comps[ssh] == _ssh ]] || exit 12
          [[ -o sharehistory && -o histignorespace && -o histignoredups ]] || exit 13
          [[ ! -o correct && ! -o correctall ]] || exit 14
          print -r -- "NATIVE_OK"
        ''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("NATIVE_OK", r.stdout)

    def test_inherited_correction_options_disabled(self):
        r = self.run_cmd(["zsh", "-dfi", "-c", '''
          setopt correct correctall
          source "$1"
          [[ ! -o correct && ! -o correctall ]]
        ''', "--", str(ROOT / "config/zsh/init.zsh")])
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_repeated_source_does_not_duplicate_hooks(self):
        r = self.zsh('''
          before=${(j.:.)precmd_functions}
          source "$1"
          [[ $before == ${(j.:.)precmd_functions} ]] || exit 15
          print REPEAT_OK
        ''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("REPEAT_OK", r.stdout)

    def test_completion_descriptions_exist(self):
        r = self.zsh('''
          autoload -Uz +X _git _ssh
          [[ ${functions[_git]} == *'--version'* ]] || exit 16
          zstyle -s ':completion:*:descriptions' format label || exit 17
          [[ $label == *'%d'* ]] || exit 18
          print METADATA_OK
        ''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("METADATA_OK", r.stdout)

    def test_optional_tools_missing_keeps_native_shell_usable(self):
        minimal = self.home / "minimal-bin"
        minimal.mkdir()
        for tool in ("mkdir", "chmod", "mv", "rm"):
            (minimal / tool).symlink_to(shutil.which(tool))
        self.env["PATH"] = str(minimal)
        self.env["HOMEBREW_PREFIX"] = str(self.home / "no-brew")
        zsh_bin = shutil.which("zsh")
        r = self.run_cmd([zsh_bin, "-dfi", "-c", '''
          source "$1"
          (( $+functions[compdef] )) || exit 1
          [[ -z $DOTFILES_ZSH_FZF_SOURCE && -z $DOTFILES_ZSH_FZF_TAB_SOURCE ]] || exit 2
          [[ $PROMPT == *'>'* ]] || exit 3
          print FALLBACK_OK
        ''', "--", str(ROOT / "config/zsh/init.zsh")])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("FALLBACK_OK", r.stdout)

    def test_multiple_generated_definitions_register_without_startup_noise(self):
        completions = self.home / "cache/dotfiles-zsh/completions"
        completions.mkdir(parents=True)
        for name in ("fixturea", "fixtureb", "fixturec"):
            file = completions / ("_" + name)
            file.write_text('#compdef ' + name + '\n_' + name + '() { _arguments "--flag[flag description]"; }\n')
            file.chmod(0o600)
        r = self.zsh('''
          [[ $_comps[fixturea] == _fixturea && $_comps[fixtureb] == _fixtureb ]] || exit 1
          print QUIET
        ''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "QUIET")

    def test_pnpm_sourced_adapter_registers_actual_function(self):
        completions = self.home / "cache/dotfiles-zsh/completions"
        completions.mkdir(parents=True)
        file = completions / "_pnpm"
        file.write_text('#compdef pnpm pn\n_pnpm_completion() { _describe values reply; }\ncompdef _pnpm_completion pnpm pn\n')
        file.chmod(0o600)
        r = self.zsh('''
          [[ $_comps[pnpm] == _pnpm_completion && $_comps[pn] == _pnpm_completion ]] || exit 1
          (( $+functions[_pnpm_completion] )) || exit 2
          print PNPM_ADAPTER_OK
        ''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(r.stdout.strip(), "PNPM_ADAPTER_OK")

    def test_unsafe_completion_dumps_cannot_execute(self):
        cache = self.home / "cache/dotfiles-zsh"
        cache.mkdir(parents=True, mode=0o700)
        version = self.run_cmd(["zsh", "-df", "-c", "print $ZSH_VERSION"]).stdout.strip()
        dump = cache / ("zcompdump-" + version)
        payload = 'touch "$HOME/UNSAFE_DUMP_EXECUTED"\n'
        for unsafe in ("writable", "symlink", "compiled-companion"):
            with self.subTest(unsafe=unsafe):
                if dump.exists() or dump.is_symlink():
                    dump.unlink()
                compiled = Path(str(dump) + ".zwc")
                if compiled.exists():
                    compiled.unlink()
                if unsafe == "symlink":
                    other = self.home / "payload"
                    other.write_text(payload)
                    dump.symlink_to(other)
                else:
                    dump.write_text(payload)
                    dump.chmod(0o666 if unsafe == "writable" else 0o600)
                    if unsafe == "compiled-companion":
                        compiled.write_text("untrusted compiled file")
                r = self.zsh('(( $+functions[compdef] )) || exit 1; print SAFE_OK')
                self.assertEqual(r.returncode, 0, r.stderr)
                self.assertFalse((self.home / "UNSAFE_DUMP_EXECUTED").exists())

    def test_help_parsing_never_executes_substitution(self):
        r = self.zsh('''
          text='$(touch "$HOME/HELP_EXECUTED")'
          _dotfiles_zsh_help_command "$text" && exit 1
          _dotfiles_zsh_help_command 'sudo -u someone git status' || exit 2
          [[ $REPLY == git ]] || exit 3
          print HELP_SAFE
        ''')
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse((self.home / "HELP_EXECUTED").exists())


class CompletionRefresh(Sandbox):
    def setUp(self):
        super().setUp()
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env["PATH"] = str(self.bin) + os.pathsep + "/usr/bin:/bin:/usr/sbin:/sbin"
        # On Linux zsh can be in /usr/local/bin; use the already resolved binary.
        if shutil.which("zsh"):
            (self.bin / "zsh").symlink_to(shutil.which("zsh"))

    def fake(self, name, body):
        f = self.bin / name
        f.write_text("#!/bin/sh\n" + body + "\n")
        f.chmod(0o755)

    def test_generator_metadata_and_failed_refresh_preserves_previous(self):
        self.fake("docker", '''[ "$*" = 'completion zsh' ] || exit 8
printf '#compdef docker\\n_docker() { _arguments "--flag[documented flag]"; }\\n'
''')
        r = self.run_cmd(["bash", "scripts/refresh-completions.sh"])
        self.assertEqual(r.returncode, 0, r.stderr)
        target = self.home / "cache/dotfiles-zsh/completions/_docker"
        previous = target.read_text()
        self.assertIn("documented flag", previous)
        self.fake("docker", 'echo broken >&2; exit 1')
        r = self.run_cmd(["bash", "scripts/refresh-completions.sh"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("WARN", r.stderr)
        self.assertEqual(target.read_text(), previous)

    def test_invalid_shell_output_is_not_published(self):
        self.fake("kubectl", "printf '#compdef kubectl\\nif {{{\\n'")
        r = self.run_cmd(["bash", "scripts/refresh-completions.sh"])
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.home / "cache/dotfiles-zsh/completions/_kubectl").exists())

    def test_symlink_cache_refused(self):
        (self.home / "cache").mkdir()
        elsewhere = self.home / "elsewhere"
        elsewhere.mkdir()
        (self.home / "cache/dotfiles-zsh").symlink_to(elsewhere)
        r = self.run_cmd(["bash", "scripts/refresh-completions.sh"])
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(list(elsewhere.iterdir()), [])


class InstallerSafety(Sandbox):
    def test_fedora_installs_cmp_provider(self):
        r = self.run_cmd(["bash", "-euc", '''
          DOTFILES_ROOT=$1; DRY_RUN=1
          . "$1/scripts/common.sh"; initialize_paths
          . "$1/plugins.lock"; . "$1/scripts/install-fedora.sh"
          install_platform
        ''', "--", str(ROOT)])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("diffutils", r.stdout)
        self.assertEqual(list(self.home.iterdir()), [])

    def test_missing_cmp_fails_before_configuration_changes(self):
        rc = self.home / ".zshrc"
        rc.write_text("export KEEP_SETTING=yes\n")
        original = rc.read_bytes()
        minimal = self.home / "minimal-bin"
        minimal.mkdir()
        (minimal / "awk").symlink_to(shutil.which("awk"))
        self.env["PATH"] = str(minimal)
        r = self.run_cmd(["/bin/bash", "-euc", '''
          DOTFILES_ROOT=$1
          . "$1/scripts/common.sh"; . "$1/scripts/configure.sh"
          configure_dotfiles
        ''', "--", str(ROOT)])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("cmp is required", r.stderr)
        self.assertEqual(rc.read_bytes(), original)
        self.assertFalse((self.home / "config").exists())

    def configure(self):
        return self.run_cmd(["bash", "-euc", '''
          DOTFILES_ROOT=$1
          . "$1/scripts/common.sh"
          . "$1/scripts/configure.sh"
          trap cleanup EXIT
          configure_dotfiles
        ''', "--", str(ROOT)])

    def test_preserves_settings_backups_and_idempotence(self):
        rc = self.home / ".zshrc"
        original = "export KEEP_ME=yes"  # intentionally no trailing newline
        rc.write_text(original)
        old_history = self.home / ".zsh_history"
        old_history.write_text(": 123:0;echo previous-session\n")
        existing = self.home / "config/dotfiles-zsh"
        existing.mkdir(parents=True)
        (existing / "old-config").write_text("preserve")
        r = self.configure()
        self.assertEqual(r.returncode, 0, r.stderr)
        first = rc.read_bytes()
        backups = list(self.home.glob(".zshrc.dotfiles-backup.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), original)
        self.assertIn(b"KEEP_ME=yes", first)
        self.assertEqual(first.count(b"# >>> dotfiles-zsh >>>"), 1)
        self.assertTrue(existing.is_symlink())
        self.assertEqual(len(list(existing.parent.glob("dotfiles-zsh.dotfiles-backup.*"))), 1)
        self.assertEqual((self.home / "state/dotfiles-zsh/history").read_text(), old_history.read_text())
        r = self.configure()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(rc.read_bytes(), first)
        self.assertEqual(len(list(self.home.glob(".zshrc.dotfiles-backup.*"))), 1)

    def test_relative_rc_symlink_and_quoted_xdg_path(self):
        real = self.home / "real-rc"
        real.write_text("export PRESERVE=yes\n")
        rc = self.home / ".zshrc"
        rc.symlink_to("real-rc")
        self.env["XDG_CONFIG_HOME"] = str(self.home / "config with ' quote")
        r = self.configure()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(rc.is_symlink())
        self.assertEqual(os.readlink(rc), "real-rc")
        r = self.run_cmd(["zsh", "-df", "-c", 'source "$HOME/.zshrc"; [[ $PRESERVE == yes ]]'])
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_malformed_block_refused_without_changes(self):
        rc = self.home / ".zshrc"
        original = "keep\n# >>> dotfiles-zsh >>>\nbroken\n"
        rc.write_text(original)
        r = self.configure()
        self.assertNotEqual(r.returncode, 0)
        self.assertEqual(rc.read_text(), original)
        self.assertFalse((self.home / "config").exists())

    def test_platform_detection_fedora_not_other_linux(self):
        release = self.home / "os-release"
        release.write_text('ID="fedora"\n')
        args = ["bash", "-c", '. "$1/scripts/common.sh"; uname() { echo Linux; }; detect_platform "$2"', "--", str(ROOT), str(release)]
        r = self.run_cmd(args)
        self.assertEqual(r.stdout.strip(), "fedora")
        release.write_text("ID=ubuntu\n")
        self.assertNotEqual(self.run_cmd(args).returncode, 0)

    def test_pinned_plugin_real_local_git_and_dirty_refusal(self):
        source = self.home / "upstream"
        source.mkdir()
        (source / "plugin.zsh").write_text("# real fixture\n")
        for args in [["init", "-q"], ["add", "."], ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "fixture"]]:
            r = self.run_cmd(["git", "-C", str(source), *args])
            self.assertEqual(r.returncode, 0, r.stderr)
        commit = self.run_cmd(["git", "-C", str(source), "rev-parse", "HEAD"]).stdout.strip()
        r = self.run_cmd(["bash", "-euc", '''
          DOTFILES_ROOT=$1; . "$1/scripts/common.sh"; initialize_paths; trap cleanup EXIT
          install_pinned_plugin fixture "$2" "$3"
          install_pinned_plugin fixture "$2" "$3"
          echo '# changed locally' >> "$PLUGIN_DIR/fixture/plugin.zsh"
          if (install_pinned_plugin fixture "$2" "$3"); then exit 9; fi
        ''', "--", str(ROOT), str(source), commit])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("local changes", r.stderr)

    def test_backup_failure_never_replaces_rc(self):
        original = "export DO_NOT_LOSE=yes\n"
        (self.home / ".zshrc").write_text(original)
        r = self.run_cmd(["bash", "-euc", '''
          DOTFILES_ROOT=$1
          . "$1/scripts/common.sh"; . "$1/scripts/configure.sh"
          trap cleanup EXIT
          cp() {
            local destination arg
            for arg in "$@"; do destination=$arg; done
            case $destination in *.dotfiles-backup.*) return 1 ;; esac
            command cp "$@"
          }
          configure_dotfiles
        ''', "--", str(ROOT)])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Cannot back up", r.stderr)
        self.assertEqual((self.home / ".zshrc").read_text(), original)

    def test_download_checksum_failure_precedes_extraction(self):
        r = self.run_cmd(["bash", "-euc", '''
          DOTFILES_ROOT=$1
          . "$1/scripts/common.sh"; initialize_paths; . "$1/plugins.lock"
          . "$1/scripts/install-fedora.sh"; trap cleanup EXIT
          uname() { echo x86_64; }
          curl() {
            while [ "$#" -gt 0 ]; do
              if [ "$1" = --output ]; then echo invalid > "$2"; return; fi
              shift
            done
          }
          sha256sum() { printf '0000  %s\\n' "$1"; }
          tar() { touch "$HOME/EXTRACTED_UNVERIFIED"; }
          install_starship_release
        ''', "--", str(ROOT)])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("checksum mismatch", r.stderr)
        self.assertFalse((self.home / "EXTRACTED_UNVERIFIED").exists())
        self.assertFalse((self.home / ".local/bin/starship").exists())

    @unittest.skipUnless(platform.system() == "Darwin", "macOS CLI contract test")
    def test_mock_package_transaction_failure_lock_and_shell_opt_in(self):
        mock = self.home / "mock-bin"
        mock.mkdir()
        brew = mock / "brew"
        brew.write_text('''#!/bin/sh
echo "$*" >> "$HOME/brew-calls"
case "$1" in
  list) exit 1 ;;
  install) exit "${MOCK_INSTALL_FAILURE:-0}" ;;
  shellenv) echo ':' ;;
  *) exit 7 ;;
esac
''')
        brew.chmod(0o755)
        for tool in ("docker", "kubectl", "pnpm", "cargo", "rustup"):
            file = mock / tool
            file.write_text("#!/bin/sh\nexit 1\n")
            file.chmod(0o755)
        chsh = mock / "chsh"
        chsh.write_text('#!/bin/sh\ntouch "$HOME/SHELL_CHANGED"\n')
        chsh.chmod(0o755)
        self.env["PATH"] = str(mock) + ":" + os.environ["PATH"]
        self.env["MOCK_INSTALL_FAILURE"] = "9"
        r = self.run_cmd(["bash", "setup.sh", "--platform", "macos"])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("previous package operations may have succeeded", r.stderr)
        self.assertFalse((self.home / "config").exists())
        lock = self.home / "state/dotfiles-zsh/install.lock"
        self.assertFalse(lock.exists())
        self.env["MOCK_INSTALL_FAILURE"] = "0"
        r = self.run_cmd(["bash", "setup.sh", "--platform", "macos"])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue((self.home / "config/dotfiles-zsh").is_symlink())
        self.assertFalse((self.home / "SHELL_CHANGED").exists())
        self.assertFalse(lock.exists())
        lock.mkdir()
        before = (self.home / "brew-calls").read_text()
        r = self.run_cmd(["bash", "setup.sh", "--platform", "macos"])
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Installation lock exists", r.stderr)
        self.assertEqual((self.home / "brew-calls").read_text(), before)

    def test_macos_installs_only_missing_formula(self):
        mock = self.home / "mock-bin"
        mock.mkdir()
        brew = mock / "brew"
        brew.write_text('''#!/bin/sh
case "$1" in
  list) [ "$3" != fzf ] ;;
  install) echo "$*" > "$HOME/installed-formulas" ;;
  shellenv) echo ':' ;;
  *) exit 7 ;;
esac
''')
        brew.chmod(0o755)
        self.env["PATH"] = str(mock) + ":" + os.environ["PATH"]
        r = self.run_cmd(["bash", "-euc", '''
          . "$1/scripts/common.sh"
          . "$1/scripts/install-macos.sh"
          install_platform
        ''', "--", str(ROOT)])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual((self.home / "installed-formulas").read_text().strip(), "install fzf")


@unittest.skipUnless(shutil.which("starship"), "requires Starship")
class Prompt(Sandbox):
    def render(self, status=0, duration=0):
        self.env["STARSHIP_CONFIG"] = str(ROOT / "config/starship.toml")
        self.env["STARSHIP_CACHE"] = str(self.home / "starship-cache")
        r = self.run_cmd(["starship", "prompt", "--path", str(self.home),
                          "--status", str(status), "--cmd-duration", str(duration)])
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertNotIn("Error", r.stderr)
        self.assertNotIn("WARN", r.stderr)
        import re
        return re.sub(r"\x1b\[[0-9;]*m", "", r.stdout)

    def test_two_lines_clock_duration_and_failure(self):
        import re
        short = self.render()
        long = self.render(127, 1400)
        self.assertLessEqual(len(short.splitlines()), 2)
        self.assertRegex(short, r"\b\d{2}:\d{2}\b")
        self.assertNotIn("took", short)
        self.assertIn("took", long)
        self.assertIn("127", long)
        self.assertNotIn("127", short)

    def test_git_clean_and_tracked_changes(self):
        (self.home / "tracked.txt").write_text("original\n")
        for args in [["init", "-q"], ["add", "tracked.txt"],
                     ["-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid", "commit", "-qm", "initial"]]:
            r = self.run_cmd(["git", "-C", str(self.home), *args])
            self.assertEqual(r.returncode, 0, r.stderr)
        clean = self.render()
        self.assertIn("git:", clean)
        self.assertNotIn("!", clean)
        (self.home / "tracked.txt").write_text("modified\n")
        self.assertIn("!", self.render())


if __name__ == "__main__":
    unittest.main(verbosity=2)
