#!/usr/bin/env python3
"""Start the real OpenCode and btop TUIs with disposable, credential-free homes.

No model requests are submitted. btop panes (which contain real process data)
are never printed or saved as artifacts.
"""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time
import uuid

ROOT = Path(__file__).resolve().parents[1]


def main():
    binaries = {name: shutil.which(name) for name in ("tmux", "btop", "opencode")}
    missing = [name for name, binary in binaries.items() if not binary]
    if missing:
        raise SystemExit("Missing app-test dependencies: " + ", ".join(missing))
    server = "dotfiles-apps-" + uuid.uuid4().hex[:10]

    def tmux(*args, check=True):
        return subprocess.run([binaries["tmux"], "-L", server, *args], check=check,
                              stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                              text=True, timeout=15)

    def wait_for(predicate, label, timeout=30):
        deadline = time.monotonic() + timeout
        while time.monotonic() < deadline:
            if predicate():
                return
            time.sleep(0.1)
        # Deliberately exclude pane text: btop contains real process information.
        raise AssertionError("Application terminal check failed: " + label)

    def pane(name):
        return tmux("capture-pane", "-p", "-J", "-t", "apps:" + name).stdout.lower()

    def dead(name):
        return tmux("display-message", "-p", "-t", "apps:" + name,
                    "#{pane_dead}:#{pane_dead_status}").stdout.strip()

    with tempfile.TemporaryDirectory(prefix="dotfiles-apps-") as temp:
        home = Path(temp).resolve()
        config = home / "config"
        links = {
            "btop/btop.conf": ROOT / ".config/btop/btop.conf",
            "opencode/cli.json": ROOT / ".config/opencode/cli.json",
            "opencode/themes/cursor-midnight.json": ROOT / ".config/opencode/themes/cursor-midnight.json",
        }
        before = {path: path.read_bytes() for path in links.values()}
        for relative, source in links.items():
            target = config / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(source)
        project = home / "project"
        project.mkdir()
        # Do not forward OPENCODE_*, provider tokens, proxy credentials, or the
        # current client's server selection into this isolated standalone client.
        env = {
            "HOME": str(home), "PATH": os.environ["PATH"],
            "XDG_CONFIG_HOME": str(config), "XDG_DATA_HOME": str(home / "data"),
            "XDG_STATE_HOME": str(home / "state"), "XDG_CACHE_HOME": str(home / "cache"),
            "TERM": "xterm-256color", "LANG": os.environ.get("LANG") or "en_US.UTF-8",
        }

        def launch(name, *args):
            command = "env -i " + " ".join(shlex.quote(k + "=" + v) for k, v in env.items())
            command += " " + " ".join(shlex.quote(str(arg)) for arg in args)
            tmux("new-window", "-d", "-t", "apps", "-n", name, "-c", str(project), command)

        try:
            tmux("-f", "/dev/null", "new-session", "-d", "-s", "apps", "-n", "keeper",
                 "-x", "140", "-y", "45", "sleep 300")
            tmux("set-window-option", "-g", "remain-on-exit", "on")
            launch("btop", binaries["btop"])
            wait_for(lambda: all(label in pane("btop") for label in ("cpu", "mem", "net", "proc")),
                     "btop rendered all four configured panels")
            tmux("send-keys", "-t", "apps:btop", "q")
            wait_for(lambda: dead("btop").startswith("1:"), "btop exited normally")
            assert dead("btop") == "1:0", "btop returned a nonzero status"
            print("PASS btop startup, configured panels and normal exit (no elevated privileges)")

            launch("opencode", binaries["opencode"], "--standalone", project)
            wait_for(lambda: "ctrl+p" in pane("opencode") or "ask anything" in pane("opencode"),
                     "OpenCode standalone home screen rendered", timeout=60)
            assert "invalid configuration" not in pane("opencode"), "OpenCode rejected CLI configuration"
            tmux("send-keys", "-t", "apps:opencode", "C-c")
            # Some CLI releases use a two-press exit confirmation.
            time.sleep(0.5)
            if not dead("opencode").startswith("1:"):
                tmux("send-keys", "-t", "apps:opencode", "C-c")
            wait_for(lambda: dead("opencode").startswith("1:"), "OpenCode exited normally")
            assert dead("opencode") == "1:0", "OpenCode returned a nonzero status"
            print("PASS OpenCode standalone startup and normal exit with linked CLI/theme files (no prompts submitted)")
            for path, contents in before.items():
                assert path.read_bytes() == contents, "Application rewrote shared configuration: " + str(path)
            print("PASS application startup left repository configuration unchanged")
        finally:
            tmux("kill-server", check=False)


if __name__ == "__main__":
    main()
