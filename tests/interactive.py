#!/usr/bin/env python3
"""Real ZLE/fzf keystroke acceptance in an isolated tmux terminal.

Requires tmux, fzf and installed plugins. No plugin downloads or package installs.
DOTFILES_TEST_PLUGIN_DIR can point to a separately downloaded plugin directory.
"""
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]


def main():
    for tool in ("tmux", "zsh", "fzf"):
        if not shutil.which(tool):
            raise SystemExit("Missing terminal-test dependency: " + tool)
    with tempfile.TemporaryDirectory(prefix="zsh-ui-") as temp:
        home = Path(temp)
        socket = str(home / "socket")

        def tmux(*args, check=True):
            return subprocess.run(["tmux", "-S", socket, *args], check=check,
                                  text=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, timeout=10)

        def screen():
            return tmux("capture-pane", "-p", "-t", "shell", "-S", "-100").stdout

        def wait_for(predicate, label):
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if predicate():
                    return
                time.sleep(0.1)
            raise AssertionError(label + "\n" + screen())

        def literal(text):
            tmux("send-keys", "-t", "shell", "-l", text)

        def key(*keys):
            tmux("send-keys", "-t", "shell", *keys)

        def command(text):
            literal(text)
            key("Enter")
            time.sleep(0.25)

        plugins = Path(os.environ.get("DOTFILES_TEST_PLUGIN_DIR",
                       str(Path(os.environ.get("XDG_DATA_HOME", str(Path.home() / ".local/share")))
                           / "dotfiles-zsh/plugins")))
        target = home / "data/dotfiles-zsh/plugins"
        target.parent.mkdir(parents=True)
        if plugins.is_dir():
            target.symlink_to(plugins)
        existing_completions = Path(os.environ.get("DOTFILES_TEST_COMPLETION_DIR",
            str(Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
                / "dotfiles-zsh/completions")))
        if existing_completions.is_dir():
            shutil.copytree(existing_completions, home / "cache/dotfiles-zsh/completions")
        (home / "bin").mkdir()
        man = home / "bin/man"
        man.write_text('#!/bin/sh\nprintf "MAN_OPENED:%s\\n" "$*" | tee -a "$HOME/man-invocations"\n')
        man.chmod(0o755)
        # Deterministic prompt; real widgets, suggestions and highlighter remain.
        (home / ".zshrc").write_text(
            'source ' + shlex.quote(str(ROOT / "config/zsh/init.zsh")) + '\n'
            'precmd_functions+=(_test_prompt)\n'
            '_test_prompt() { PROMPT="TEST> "; RPROMPT=""; }\n'
        )
        env = dict(HOME=str(home), ZDOTDIR=str(home), XDG_CONFIG_HOME=str(home / "config"),
                   XDG_DATA_HOME=str(home / "data"), XDG_CACHE_HOME=str(home / "cache"),
                   XDG_STATE_HOME=str(home / "state"), TERM="xterm-256color",
                   PATH=str(home / "bin") + ":" + os.environ["PATH"])
        rustup = Path(os.environ.get("RUSTUP_HOME", str(Path.home() / ".rustup")))
        if rustup.is_dir():
            env["RUSTUP_HOME"] = str(rustup)
        launch = "env " + " ".join(shlex.quote(k + "=" + v) for k, v in env.items())
        launch += " " + shlex.quote(shutil.which("zsh")) + " -di"
        try:
            tmux("-f", "/dev/null", "new-session", "-d", "-s", "shell", "-x", "120", "-y", "40", launch)
            wait_for(lambda: "TEST>" in screen(), "shell startup")
            command('(( $+functions[enable-fzf-tab] && $+functions[_zsh_autosuggest_start] && $+functions[_zsh_highlight] )) && touch "$HOME/plugins-ok"; print -r -- ${(k)_comps} > "$HOME/completion-commands"')
            wait_for(lambda: (home / "plugins-ok").exists(), "real plugins active")

            command('echo GHOST_ACCEPTED')
            literal('echo GHOST_ACC')
            wait_for(lambda: screen().split("TEST>")[-1].strip() == "echo GHOST_ACCEPTED", "ghost suggestion rendered")
            key("Right")
            literal(' > "$HOME/ghost-result"')
            key("Enter")
            wait_for(lambda: (home / "ghost-result").exists(), "right-arrow accept")
            assert (home / "ghost-result").read_text().strip() == "GHOST_ACCEPTED"
            print("PASS ghost text and right-arrow acceptance")

            repo = home / "repo"
            repo.mkdir()
            git_env = dict(os.environ, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null")
            subprocess.run(["git", "init", "-q", str(repo)], check=True, env=git_env)
            subprocess.run(["git", "-C", str(repo), "-c", "user.name=Test", "-c", "user.email=test@example.invalid", "commit", "--allow-empty", "-qm", "test"], check=True, env=git_env)
            for branch in ("fish-alpha", "fish-beta"):
                subprocess.run(["git", "-C", str(repo), "branch", branch], check=True, env=git_env)
            command('cd "$HOME/repo"')
            literal("git --")
            key("Tab")
            wait_for(lambda: "--version" in screen(), "Git flag completion menu")
            assert any(word in screen().lower() for word in ("version information", "version number", "print version", "display version")), screen()
            key("C-g")
            time.sleep(0.3)
            key("C-c")
            time.sleep(0.2)
            literal("git switch fish-")
            key("Tab")
            wait_for(lambda: "fish-alpha" in screen() and "fish-beta" in screen(), "Git branch candidates")
            key("C-g")
            time.sleep(0.3)
            key("C-c")
            time.sleep(0.2)
            print("PASS real Tab/fzf Git flag descriptions and branch candidates")

            registered = (home / "completion-commands").read_text().split()
            for tool, flag in (("docker", "--config"), ("kubectl", "--context"),
                               ("cargo", "--version"), ("pnpm", "--filter"),
                               ("npm", "--global"), ("brew", "--prefix"),
                               ("ssh", "-p"), ("systemctl", "--user"), ("dnf", "--refresh")):
                if tool not in registered or not shutil.which(tool):
                    print("SKIP unavailable flag completion: " + tool)
                    continue
                literal(tool + (" -" if tool == "ssh" else " --"))
                key("Tab")
                wait_for(lambda: "╭" in screen().split("TEST>")[-1], tool + " first-Tab completion menu")
                literal(" " + flag)
                wait_for(lambda: any(flag in line and " > " not in line
                         for line in screen().split("TEST>")[-1].splitlines()),
                         tool + " first-Tab flag candidate")
                key("C-g")
                time.sleep(0.3)
                key("C-c")
                time.sleep(0.2)
                print("PASS first-Tab flag completion: " + tool)

            literal("git statu")
            wait_for(lambda: screen().split("TEST>")[-1].strip() == "git status", "completion-based ghost suggestion")
            key("Right")
            literal(' > "$HOME/completion-suggest"')
            key("Enter")
            wait_for(lambda: (home / "completion-suggest").exists(), "accept completion suggestion")
            assert "On branch" in (home / "completion-suggest").read_text()
            print("PASS completion-based inline suggestion")

            filename = "pick file ' $(touch SHOULD_NOT_RUN).txt"
            (repo / filename).write_text("safe preview content")
            literal("printf %s ")
            key("C-t")
            literal("pick file")
            time.sleep(0.4)
            key("Enter")
            time.sleep(0.3)
            literal(' > "$HOME/file-result"')
            key("Enter")
            wait_for(lambda: (home / "file-result").exists(), "Ctrl+T insertion")
            assert (home / "file-result").read_text() == filename
            assert not (repo / "SHOULD_NOT_RUN").exists()
            print("PASS Ctrl+T safe insertion of spaces, quotes, and shell-looking filename")

            (repo / "second-preview.txt").write_text("second file")
            literal("cat ")
            key("Tab")
            literal("pick file")
            if shutil.which("bat"):
                wait_for(lambda: "safe preview content" in screen(), "safe contextual file preview")
            else:
                wait_for(lambda: "pick file" in screen(), "file completion without bat")
            assert not (repo / "SHOULD_NOT_RUN").exists()
            key("C-g")
            time.sleep(0.3)
            key("C-c")
            time.sleep(0.2)
            print("PASS Tab file preview does not execute candidate text")

            nav = repo / "nav target"
            nav.mkdir()
            key("Escape")
            literal("c")
            time.sleep(0.3)
            literal("nav target")
            time.sleep(0.3)
            key("Enter")
            time.sleep(0.3)
            command('pwd > "$HOME/cd-result"')
            wait_for(lambda: (home / "cd-result").exists(), "Alt+C directory navigation")
            assert (home / "cd-result").read_text().strip() == str(nav)
            print("PASS Alt+C directory navigation with spaces")

            command('echo HISTORY_SELECTED > "$HOME/history-result"')
            (home / "history-result").unlink()
            key("C-r")
            literal("HISTORY_SELECTED")
            time.sleep(0.4)
            key("Enter")
            time.sleep(0.2)
            assert not (home / "history-result").exists(), "Ctrl+R must not execute selection"
            key("Enter")
            wait_for(lambda: (home / "history-result").exists(), "Ctrl+R selection executed explicitly")
            print("PASS Ctrl+R selection without automatic execution")

            command('echo SUBSTRING_TARGET > "$HOME/substring-result"')
            (home / "substring-result").unlink()
            literal("SUBSTRING_TARGET")
            key("Up", "Enter")
            wait_for(lambda: (home / "substring-result").exists(), "middle-substring history search")
            print("PASS substring Up-arrow history search")

            literal('printf DOC_BUFFER_OK > "$HOME/doc-result"')
            key("Escape")
            literal("h")
            wait_for(lambda: (home / "man-invocations").exists(), "Alt+H documentation widget")
            assert "MAN_OPENED:printf" in (home / "man-invocations").read_text()
            key("Enter")
            wait_for(lambda: (home / "doc-result").exists(), "documentation preserves editing buffer")
            assert (home / "doc-result").read_text() == "DOC_BUFFER_OK"
            print("PASS documentation shortcut and buffer preservation (controlled man stub)")

            tmux("new-window", "-d", "-t", "shell", "-n", "second", launch)
            wait_for(lambda: "TEST>" in tmux("capture-pane", "-p", "-t", "shell:second").stdout, "second shell startup")
            tmux("send-keys", "-t", "shell:second", "-l", 'echo TWO_SESSION_SHARED > "$HOME/shared-result"')
            tmux("send-keys", "-t", "shell:second", "Enter")
            wait_for(lambda: (home / "shared-result").exists(), "second session history event")
            (home / "shared-result").unlink()
            command("true")  # prompt imports the other session's shared history
            key("C-r")
            literal("TWO_SESSION_SHARED")
            time.sleep(0.4)
            key("Enter")
            time.sleep(0.2)
            assert not (home / "shared-result").exists()
            key("Enter")
            wait_for(lambda: (home / "shared-result").exists(), "first session finds second session history")
            command(" echo PRIVATE_EXCLUDED")
            command("echo DEDUP_SESSION_CHECK")
            command("echo DEDUP_SESSION_CHECK")
            command("true")
            history = (home / "state/dotfiles-zsh/history").read_text()
            assert "PRIVATE_EXCLUDED" not in history
            assert history.count("echo DEDUP_SESSION_CHECK") == 1
            print("PASS two-session shared persistent history, space exclusion, consecutive deduplication")
        finally:
            tmux("kill-server", check=False)


if __name__ == "__main__":
    main()
