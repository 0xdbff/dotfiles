"""Portable dotfile links, btop and OpenCode V2 regression tests (offline)."""
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class OpenCodeConfig(unittest.TestCase):
    def test_minimal_portable_cli_config(self):
        path = ROOT / ".config/opencode/cli.json"
        config = json.loads(path.read_text())
        self.assertEqual(len(path.read_text().splitlines()), 5)
        self.assertEqual(set(config), {"$schema", "theme", "diffs"})
        self.assertEqual(config["$schema"], "https://opencode.ai/v2/cli.json")
        self.assertEqual(config["theme"], {"name": "cursor-midnight", "mode": "dark"})
        self.assertEqual(config["diffs"], {"wrap": "word"})

    def test_theme_complete_hues_tokens_and_resolvable_references(self):
        theme = json.loads((ROOT / ".config/opencode/themes/cursor-midnight.json").read_text())
        self.assertEqual(set(theme), {"base", "dark"})
        base = theme["base"]
        self.assertTrue({"categorical", "text", "background", "border", "scrollbar", "diff", "syntax", "markdown"}.issubset(base))
        self.assertEqual(set(base["syntax"]), {"comment", "keyword", "function", "variable", "string", "number", "type", "operator", "punctuation"})
        hues = theme["dark"]["hue"]
        for name in ("gray", "red", "orange", "yellow", "green", "cyan", "blue", "purple"):
            self.assertEqual(set(hues[name]), {str(n) for n in range(100, 1000, 100)})
            for color in hues[name].values():
                self.assertRegex(color, r"^#[0-9a-fA-F]{6}$")
        tree = dict(base, **theme["dark"])

        def resolve(value, seen=()):
            if not value.startswith("$"):
                self.assertTrue(value == "transparent" or re.fullmatch(r"#[0-9a-fA-F]{6}", value), value)
                return
            self.assertNotIn(value, seen, "cyclic theme reference")
            target = tree
            for part in value[1:].split("."):
                self.assertIn(part, target, "unresolved reference: " + value)
                target = target[part]
                if isinstance(target, str) and target.startswith("$"):
                    # The existing theme only aliases entire hue groups.
                    alias = tree
                    for token in target[1:].split("."):
                        alias = alias[token]
                    target = alias
            if isinstance(target, str):
                resolve(target, seen + (value,))

        def visit(node):
            if isinstance(node, dict):
                for key, value in node.items():
                    if key != "categorical":
                        visit(value)
            elif isinstance(node, str):
                resolve(node)

        visit(tree)


class BtopConfig(unittest.TestCase):
    def test_minimal_portable_preferences(self):
        path = ROOT / ".config/btop/btop.conf"
        config = {}
        for line in path.read_text().splitlines():
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            key, value = line.split("=", 1)
            self.assertNotIn(key.strip(), config, "duplicate preference")
            config[key.strip()] = json.loads(value.strip())
        self.assertEqual(config, {
            "color_theme": "TTY", "theme_background": False, "truecolor": True,
            "force_tty": False, "rounded_corners": True, "graph_symbol": "braille",
            "shown_boxes": "cpu mem net proc", "update_ms": 2000,
            "proc_sorting": "cpu lazy", "proc_tree": False, "proc_per_core": False,
            "clock_format": "%X", "show_cpu_watts": False,
            "save_config_on_exit": False,
        })
        self.assertLess(len(path.read_text().splitlines()), 30)
        self.assertEqual(sorted(p.name for p in path.parent.iterdir()), ["btop.conf"])


class ConfigLinks(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="dotfiles-links-")
        self.addCleanup(self.tmp.cleanup)
        self.home = Path(self.tmp.name)
        # A clone path with spaces and an apostrophe must still link correctly.
        self.clone = self.home / "clone with ' spaces"
        self.clone.mkdir()
        shutil.copytree(ROOT / ".config", self.clone / ".config")
        shutil.copytree(ROOT / "config", self.clone / "config")
        shutil.copytree(ROOT / "scripts", self.clone / "scripts")
        shutil.copyfile(ROOT / "install.sh", self.clone / "install.sh")
        self.env = dict(os.environ, HOME=str(self.home / "home"),
                        XDG_CONFIG_HOME=str(self.home / "xdg-config"),
                        XDG_DATA_HOME=str(self.home / "xdg-data"),
                        XDG_STATE_HOME=str(self.home / "xdg-state"),
                        XDG_CACHE_HOME=str(self.home / "xdg-cache"),
                        ZDOTDIR=str(self.home / "zdot"))

    def link(self, *args):
        return subprocess.run(["bash", str(self.clone / "install.sh"), "--links-only", *args],
                              cwd=self.home, env=self.env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=30)

    def test_any_clone_location_backs_up_and_preserves_private_opencode_settings(self):
        config = Path(self.env["XDG_CONFIG_HOME"])
        (config / "opencode/themes").mkdir(parents=True)
        (config / "opencode/opencode.json").write_text('{"private_setting":"keep local"}\n')
        (config / "opencode/cli.json").write_text('{"old_ui":"backup"}\n')
        (config / "opencode/themes/unrelated.json").write_text("{}\n")
        (config / "btop/themes").mkdir(parents=True)
        (config / "btop/themes/local.theme").write_text("# private local theme\n")
        (config / "btop/btop.conf").write_text('color_theme = "local"\n')
        (config / "nvim").mkdir()
        (config / "nvim/old").write_text("retain in backup")
        r = self.link()
        self.assertEqual(r.returncode, 0, r.stderr)
        for dest, source in (("nvim", ".config/nvim"),
                             ("alacritty/alacritty.toml", ".config/alacritty.toml"),
                             ("btop/btop.conf", ".config/btop/btop.conf"),
                             ("opencode/cli.json", ".config/opencode/cli.json"),
                             ("opencode/themes/cursor-midnight.json", ".config/opencode/themes/cursor-midnight.json"),
                             ("dotfiles-zsh", "config")):
            target = config / dest
            self.assertTrue(target.is_symlink(), dest)
            self.assertEqual(target.resolve(), (self.clone / source).resolve())
        self.assertEqual((config / "opencode/opencode.json").read_text(), '{"private_setting":"keep local"}\n')
        self.assertTrue((config / "opencode/themes/unrelated.json").is_file())
        self.assertFalse((config / "btop").is_symlink())
        self.assertEqual((config / "btop/themes/local.theme").read_text(), "# private local theme\n")
        btop_backups = list((config / "btop").glob("btop.conf.dotfiles-backup.*"))
        self.assertEqual(len(btop_backups), 1)
        self.assertEqual(btop_backups[0].read_text(), 'color_theme = "local"\n')
        backups = sorted(str(p) for p in config.rglob("*.dotfiles-backup.*"))
        self.assertTrue(any("cli.json" in p for p in backups))
        self.assertTrue(any("nvim" in p for p in backups))
        rc = Path(self.env["ZDOTDIR"]) / ".zshrc"
        first = rc.read_bytes()
        r = self.link()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(first, rc.read_bytes())
        self.assertEqual(backups, sorted(str(p) for p in config.rglob("*.dotfiles-backup.*")))
        self.assertEqual((config / "btop/themes/local.theme").read_text(), "# private local theme\n")
        self.assertIn("Already linked: " + str(config / "btop/btop.conf"), r.stdout)

    def test_existing_btop_config_directory_is_backed_up(self):
        config = Path(self.env["XDG_CONFIG_HOME"])
        previous = config / "btop/btop.conf"
        previous.mkdir(parents=True)
        (previous / "private").write_text("preserve directory contents")
        r = self.link()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(previous.is_symlink())
        backups = list(previous.parent.glob("btop.conf.dotfiles-backup.*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual((backups[0] / "private").read_text(), "preserve directory contents")

    def test_links_only_dry_run_does_not_create_home_or_xdg_directories(self):
        r = self.link("--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        for key in ("HOME", "XDG_CONFIG_HOME", "XDG_DATA_HOME", "XDG_STATE_HOME", "XDG_CACHE_HOME", "ZDOTDIR"):
            self.assertFalse(Path(self.env[key]).exists(), key)


class AppInstaller(unittest.TestCase):
    def run_bash(self, code, *args, env=None):
        return subprocess.run(["bash", "-euc", '. "$1/scripts/common.sh"; . "$1/scripts/link-configs.sh"; . "$1/scripts/install-apps.sh"; ' + code,
                               "--", str(ROOT), *args], env=env, text=True,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)

    def test_opencode_v2_accepts_actual_prefixed_and_bare_version_output(self):
        r = self.run_bash('''
          opencode() { printf '%s\\n' "$format"; }
          for format in 'opencode v2.0.29' 'v2.0.29' '2.0.29'; do
            opencode_v2_installed || exit 1
          done
          format='opencode v1.3.0'
          if opencode_v2_installed; then exit 2; fi
        ''')
        self.assertEqual(r.returncode, 0, r.stderr)

    def test_neovim_minimum_version(self):
        for version, expected in (("0.12.6", 0), ("1.0.0", 0), ("0.11.99", 1)):
            with self.subTest(version=version):
                r = self.run_bash('fake_version=$2; nvim() { printf "NVIM v%s\\n" "$fake_version"; }; verify_nvim_version', version)
                self.assertEqual(r.returncode == 0, expected == 0, r.stderr)

    def test_source_built_alacritty_terminfo_links_preserve_existing_definitions(self):
        with tempfile.TemporaryDirectory(prefix="alacritty-terminfo-") as temp:
            home = Path(temp)
            app = home / "Applications/Alacritty.app"
            resources = app / "Contents/Resources/61"
            resources.mkdir(parents=True)
            (resources / "alacritty").write_text("compiled fixture")
            (resources / "alacritty-direct").write_text("compiled direct fixture")
            old = home / ".terminfo/61"
            old.mkdir(parents=True)
            (old / "alacritty").write_text("preserve old definition")
            r = self.run_bash('link_alacritty_terminfo "$2"', str(app), env=dict(os.environ, HOME=str(home)))
            self.assertEqual(r.returncode, 0, r.stderr)
            self.assertEqual((old / "alacritty").resolve(), (resources / "alacritty").resolve())
            self.assertEqual((old / "alacritty-direct").resolve(), (resources / "alacritty-direct").resolve())
            backups = list(old.glob("alacritty.dotfiles-backup.*"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), "preserve old definition")

    def test_opencode_checksum_failure_cannot_extract_or_replace_binary(self):
        with tempfile.TemporaryDirectory(prefix="opencode-download-") as temp:
            home = Path(temp)
            (home / "state").mkdir()
            code = '''
              . "$1/apps.lock"
              STATE_DIR=$2/state
              trap cleanup EXIT
              opencode_v2_installed() { return 1; }
              uname() { echo x86_64; }
              curl() {
                while [ "$#" -gt 0 ]; do
                  if [ "$1" = --output ]; then echo corrupt > "$2"; return; fi
                  shift
                done
              }
              sha256sum() { return 1; }
              tar() { touch "$HOME/UNVERIFIED_EXTRACTION"; }
              install_opencode_linux
            '''
            r = self.run_bash(code, str(home), env=dict(os.environ, HOME=str(home)))
            self.assertNotEqual(r.returncode, 0)
            self.assertIn("checksum mismatch", r.stderr)
            self.assertFalse((home / "UNVERIFIED_EXTRACTION").exists())
            self.assertFalse((home / ".local/bin/opencode").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
