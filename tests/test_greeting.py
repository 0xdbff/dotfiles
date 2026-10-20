"""Fish-style aliases and portable greeting; no live host/network data needed."""
import os
from pathlib import Path
import pty
import select
import shlex
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ZSH = shutil.which("zsh")


@unittest.skipUnless(ZSH, "requires Zsh")
class ShellConveniences(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="zsh-greeting-")
        self.addCleanup(self.temp.cleanup)
        self.home = Path(self.temp.name)
        self.bin = self.home / "bin"
        self.bin.mkdir()
        self.env = dict(os.environ, HOME=str(self.home), ZDOTDIR=str(self.home),
                        PATH=str(self.bin), TERM="xterm-256color")
        self.env.pop("NO_COLOR", None)
        self.env.pop("DOTFILES_ZSH_GREETING", None)
        for tool in ("awk", "sort", "sed"):
            (self.bin / tool).symlink_to(shutil.which(tool))
        self.stub("uname", "Darwin 25.0\n")
        self.stub("uptime", " 12:00 up 2 days, 3 users\n")
        self.stub("df", """Filesystem Size Used Avail Capacity Mounted on
/dev/disk3s1 100Gi 74Gi 26Gi 74% /
/dev/mapper/data 100G 75G 25G 75% /data
/dev/sda1 100G 85G 15G 85% /volume with spaces
devfs 200Ki 200Ki 0Bi 100% /dev
""")

    def stub(self, name, output):
        file = self.bin / name
        file.write_text("#!/bin/sh\nprintf '%s' " + shlex.quote(output) + "\n")
        file.chmod(0o700)

    def run_zsh(self, module, code, terminal=False, interactive=True):
        args = [ZSH, "-dfi" if interactive else "-df", "-c",
                'source "$1"; ' + code, "--", str(ROOT / "config/zsh" / module)]
        if not terminal:
            return subprocess.run(args, env=self.env, cwd=self.home, text=True,
                                  capture_output=True, timeout=15)
        master, slave = pty.openpty()
        try:
            process = subprocess.run(args, env=self.env, cwd=self.home,
                                     stdout=slave, stderr=subprocess.PIPE, timeout=15)
            output = bytearray()
            # Drain before closing the last slave FD: macOS discards unread data on close.
            while select.select([master], [], [], 0.1)[0]:
                chunk = os.read(master, 8192)
                if not chunk:
                    break
                output.extend(chunk)
            return subprocess.CompletedProcess(args, process.returncode,
                                               output.decode(), process.stderr.decode())
        finally:
            os.close(master)
            if slave is not None:
                os.close(slave)

    def test_aliases_prefer_eza_and_preserve_original_flags(self):
        self.stub("eza", "")
        self.stub("exa", "")
        result = self.run_zsh("aliases.zsh", 'for name in Ltg Lt L llt ll lt l; do print -r -- "$name=$aliases[$name]"; done')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), [
            "Ltg=eza -laTS -F --no-permissions --octal-permissions --group-directories-first --time-style iso",
            "Lt=eza -laTS -F -I .git --no-permissions --octal-permissions --group-directories-first --time-style iso",
            "L=eza -laS -F --no-permissions --octal-permissions --group-directories-first --time-style iso",
            "llt=eza -1aT -F --group-directories-first", "ll=eza -1aF --group-directories-first",
            "lt=eza -1T -F --group-directories-first", "l=eza -1F --group-directories-first",
        ])

    def test_aliases_support_legacy_exa(self):
        self.stub("exa", "")
        result = self.run_zsh("aliases.zsh", 'print -r -- "$aliases[l]"')
        self.assertEqual(result.stdout.strip(), "exa -1F --group-directories-first")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_aliases_fall_back_without_replacing_ls(self):
        result = self.run_zsh("aliases.zsh", 'print -r -- "$aliases[l]|$aliases[ll]|$aliases[L]|${aliases[ls]-unset}"')
        self.assertEqual(result.stdout.strip(), "ls|ls -l|ls -la|unset")
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_real_eza_options_and_hidden_tree_exclusion(self):
        eza = shutil.which("eza")
        if not eza:
            self.skipTest("requires eza")
        (self.bin / "eza").symlink_to(eza)
        fixture = self.home / "fixture"
        fixture.mkdir()
        (fixture / ".git").mkdir()
        (fixture / ".git/hidden-object").touch()
        (fixture / "space file").touch()
        for alias in ("Ltg", "Lt", "L", "llt", "ll", "lt", "l"):
            with self.subTest(alias=alias):
                result = self.run_zsh("aliases.zsh", "eval '" + alias + " --color=never fixture'")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn("space file", result.stdout)
                if alias == "Lt":
                    self.assertNotIn(".git", result.stdout)
                if alias == "Ltg":
                    self.assertIn("hidden-object", result.stdout)

    def test_redirected_and_noninteractive_startup_stays_quiet(self):
        for interactive in (False, True):
            result = self.run_zsh("greeting.zsh", 'source "$1"', interactive=interactive)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout, "")
            self.assertEqual(result.stderr, "")

    def test_linux_ip_addresses_and_portable_disk_rows(self):
        self.stub("ip", """2: eth0@if7 inet 192.168.1.2/24 brd 192.168.1.255 scope global eth0
3: wlan0 inet 203.0.113.5/24 scope global wlan0
3: wlan0 inet6 fd00::2/64 scope global
""")
        result = self.run_zsh("greeting.zsh", "dotfiles_greeting")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        for text in ("OS: Darwin 25.0", "Uptime: 12:00 up 2 days", "Hostname:",
                     "74Gi / 100Gi", "/volume with spaces", "192.168.1.2", "203.0.113.5", "fd00::2"):
            self.assertIn(text, result.stdout)
        self.assertNotIn("\x1b", result.stdout)
        self.assertNotIn("/dev\t", result.stdout)
        self.assertNotIn("eth0@if", result.stdout)

    def test_macos_ifconfig_filters_down_loopback_and_link_local(self):
        self.stub("ifconfig", """lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 16384
    inet 127.0.0.1 netmask 0xff000000
    inet6 ::1 prefixlen 128
en0: flags=8863<UP,BROADCAST,SMART,RUNNING,SIMPLEX,MULTICAST> mtu 1500
    inet6 fe80::123%en0 prefixlen 64
    inet 10.0.0.5 netmask 0xffffff00
    inet6 2001:db8::5 prefixlen 64
en1: flags=8822<BROADCAST,SMART,SIMPLEX,MULTICAST> mtu 1500
    inet 192.168.2.5 netmask 0xffffff00
""")
        result = self.run_zsh("greeting.zsh", "dotfiles_greeting")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("10.0.0.5", result.stdout)
        self.assertIn("2001:db8::5", result.stdout)
        for text in ("127.0.0.1", "fe80::", "::1", "192.168.2.5"):
            self.assertNotIn(text, result.stdout)

    def test_terminal_colors_thresholds_and_once_only_greeting(self):
        self.stub("ip", """2: eth0 inet 172.16.0.5/24 scope global eth0
3: wlan0 inet 203.0.113.5/24 scope global wlan0
4: wwan0 inet6 fd00::2/64 scope global
""")
        result = self.run_zsh("greeting.zsh", 'source "$1"', terminal=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("OS:"), 1)
        self.assertIn("\x1b[0;33m/data", result.stdout)
        self.assertIn("\x1b[0;31m/volume with spaces", result.stdout)
        self.assertNotIn("\x1b[4m172.16", result.stdout)
        self.assertIn("\x1b[35mwlan0", result.stdout)
        self.assertIn("\x1b[4m203.0.113.5", result.stdout)
        self.assertIn("\x1b[33mwwan0", result.stdout)
        self.assertNotIn("\x1b[4mfd00", result.stdout)

    def test_no_color_and_automatic_greeting_opt_out(self):
        self.env["NO_COLOR"] = "1"
        result = self.run_zsh("greeting.zsh", ":", terminal=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("OS:", result.stdout)
        self.assertIn("No active global addresses.", result.stdout)
        self.assertNotIn("\x1b", result.stdout)
        self.env["DOTFILES_ZSH_GREETING"] = "0"
        result = self.run_zsh("greeting.zsh", ":", terminal=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, "")
