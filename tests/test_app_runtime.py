"""Regression contracts for full validation and executable selection."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import shutil

ROOT = Path(__file__).resolve().parents[1]


class ExecutableSelection(unittest.TestCase):
    @unittest.skipUnless(shutil.which("nvim"), "requires Neovim for bootstrap failure regression")
    def test_failed_lazy_checkout_cleans_stage_and_retries(self):
        with tempfile.TemporaryDirectory(prefix="lazy-bootstrap-") as temp:
            home = Path(temp)
            config = home / "config"
            config.mkdir()
            (config / "nvim").symlink_to(ROOT / ".config/nvim", target_is_directory=True)
            binary = home / "bin"
            binary.mkdir()
            git = binary / "git"
            git.write_text('''#!/bin/sh
if [ "$1" = clone ]; then echo clone >> "$TEST_GIT_CALLS"; exit 0; fi
echo 'fixture checkout failure' >&2
exit 1
''')
            git.chmod(0o755)
            calls = home / "git-calls"
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(config),
                       XDG_DATA_HOME=str(home / "data"), XDG_STATE_HOME=str(home / "state"),
                       XDG_CACHE_HOME=str(home / "cache"), TEST_GIT_CALLS=str(calls),
                       PATH=str(binary) + ":" + os.environ["PATH"])
            env.pop("NVIM_APPNAME", None)
            for attempt in (1, 2):
                result = subprocess.run([shutil.which("nvim"), "--headless", "-i", "NONE", "+qa!"],
                                        env=env, text=True, stdout=subprocess.PIPE,
                                        stderr=subprocess.PIPE, timeout=20)
                self.assertIn("Could not check out locked lazy.nvim revision", result.stderr)
                self.assertFalse((home / "data/nvim/lazy/lazy.nvim").exists())
                self.assertEqual(list((home / "data/nvim/lazy").glob("*.bootstrap-*")), [])
                self.assertEqual(calls.read_text().count("clone"), attempt)

    def test_macos_opencode_v2_keg_does_not_replace_existing_v1(self):
        with tempfile.TemporaryDirectory(prefix="opencode-shadow-") as temp:
            home = Path(temp)
            old = home / "brew-bin"
            keg = home / "opencode-v2"
            old.mkdir()
            (keg / "bin").mkdir(parents=True)
            for file, version in ((old / "opencode", "1.2.0"), (keg / "bin/opencode", "opencode v2.0.32")):
                file.write_text('#!/bin/sh\nprintf "%s\\n" "' + version + '"\n')
                file.chmod(0o755)
            brew = old / "brew"
            brew.write_text('''#!/bin/sh
case "$1" in
  list) exit 0 ;;
  --prefix) printf '%s\\n' "$TEST_KEG" ;;
  *) echo 'Unexpected package operation' >&2; exit 9 ;;
esac
''')
            brew.chmod(0o755)
            env = dict(os.environ, HOME=str(home), PATH=str(old) + ":" + os.environ["PATH"], TEST_KEG=str(keg))
            result = subprocess.run(["/bin/bash", "-euc", '''
              . "$1/scripts/common.sh"; . "$1/scripts/link-configs.sh"; . "$1/scripts/install-apps.sh"
              DOTFILES_BREW_BIN=$2/brew
              install_opencode_macos
              opencode_v2_installed
              install_opencode_macos "$(command -v opencode)"
            ''', "--", str(ROOT), str(old)], env=env, text=True,
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual((home / ".local/bin/opencode").resolve(), (keg / "bin/opencode").resolve())
            self.assertIn('"1.2.0"', (old / "opencode").read_text())
            self.assertEqual(list((home / ".local/bin").glob("*.dotfiles-backup.*")), [])

    def test_user_local_binary_precedes_brew_in_interactive_shell(self):
        with tempfile.TemporaryDirectory(prefix="dotfiles-path-") as temp:
            home = Path(temp)
            env = dict(os.environ, HOME=str(home), XDG_CONFIG_HOME=str(home / "config"),
                       XDG_CACHE_HOME=str(home / "cache"), XDG_STATE_HOME=str(home / "state"),
                       HOMEBREW_PREFIX=str(home / "brew"))
            result = subprocess.run(["zsh", "-dfi", "-o", "no_zle", "-c", 'source "$1"; [[ $path[1] == "$HOME/.local/bin" ]]',
                                     "--", str(ROOT / "config/zsh/init.zsh")], env=env,
                                    stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
