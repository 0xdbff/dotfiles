#!/usr/bin/env python3
"""Real ZLE/fzf keystroke acceptance in an isolated tmux terminal.

Requires tmux, fzf and installed plugins. No plugin downloads or package installs.
DOTFILES_TEST_PLUGIN_DIR can point to a separately downloaded plugin directory.
DOTFILES_TEST_ARTIFACT_DIR optionally saves fixture-only panes on failure.
"""
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import tempfile
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]


def flag_has_description(pane, flag):
    """Require a completion row's metadata, not a prompt/query echo or prose."""
    # fzf-tab separates the native completion value and description with ` -- `.
    # Do not depend on the completion provider's language or exact wording.
    pattern = r"^[^>\n]*?(?<![\w-])" + re.escape(flag) + r"[ \t]+--[ \t]+([^\n│]*)"
    return any(match.group(1).strip() for match in re.finditer(pattern, pane, re.M))


def unprovisioned_pnpm_shim():
    """Corepack's launcher can exist without an installed pnpm package.

    Check only this known lazy launcher case, with downloads explicitly off.
    A functioning pnpm must still have real completion metadata below.
    """
    env = dict(os.environ, COREPACK_ENABLE_NETWORK="0", COREPACK_ENABLE_DOWNLOAD_PROMPT="0")
    try:
        result = subprocess.run(["pnpm", "--version"], env=env, text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=10)
    except subprocess.TimeoutExpired:
        return False
    return result.returncode != 0 and ("corepack" in result.stderr.lower() or
                                      "network access disabled" in result.stderr.lower())


def main():
    for tool in ("tmux", "zsh", "fzf"):
        if not shutil.which(tool):
            raise SystemExit("Missing terminal-test dependency: " + tool)
    # macOS's default TMPDIR can exceed sockaddr_un's 104-byte path limit.
    # Only the private socket directory needs a short path; HOME stays isolated.
    with tempfile.TemporaryDirectory(prefix="zsh-ui-") as temp, \
            tempfile.TemporaryDirectory(prefix="zui-", dir="/tmp") as socket_dir:
        home = Path(temp)
        socket = str(Path(socket_dir) / "socket")

        def tmux(*args, check=True):
            return subprocess.run(["tmux", "-S", socket, *args], check=check,
                                  text=True, stdout=subprocess.PIPE,
                                  stderr=subprocess.PIPE, timeout=10)

        def screen():
            return tmux("capture-pane", "-p", "-J", "-t", "shell:0", "-S", "-100").stdout

        def editing():
            return screen().split("TEST>")[-1]

        def menu_open():
            return "╭" in editing()

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
            previous = prompt_count()
            literal(text)
            key("Enter")
            wait_for(lambda: prompt_count() > previous, "command finished: " + text)

        def prompt_count():
            try:
                return int((home / ".prompt-count").read_text().strip() or "0")
            except FileNotFoundError:
                return 0

        def cancel_menu():
            key("C-g")
            wait_for(lambda: not menu_open(), "completion menu closed")
            previous = prompt_count()
            key("C-c")
            wait_for(lambda: prompt_count() > previous, "editing buffer cancelled")

        def select_menu(label):
            key("Enter")
            wait_for(lambda: not menu_open(), label + " selection returned to ZLE")

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
            '_test_prompt() { PROMPT="TEST> "; RPROMPT=""; '
            '(( ++_test_prompts )); print -r -- $_test_prompts > "$HOME/.prompt-count"; }\n'
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
            wait_for(lambda: flag_has_description(editing(), "--version"),
                     "Git flag candidate has native description metadata")
            cancel_menu()
            literal("git switch fish-")
            key("Tab")
            wait_for(lambda: "fish-alpha" in screen() and "fish-beta" in screen(), "Git branch candidates")
            cancel_menu()
            print("PASS real Tab/fzf Git flag descriptions and branch candidates")

            registered = (home / "completion-commands").read_text().split()
            for tool, flag in (("docker", "--config"), ("kubectl", "--context"),
                               ("cargo", "--version"), ("pnpm", "--filter"),
                               ("npm", "--global"), ("brew", "--prefix"),
                               ("ssh", "-p"), ("systemctl", "--user"), ("dnf", "--refresh")):
                if not shutil.which(tool):
                    print("SKIP unavailable flag completion: " + tool)
                    continue
                if tool == "pnpm" and tool not in registered and unprovisioned_pnpm_shim():
                    print("SKIP pnpm: Corepack launcher has no provisioned manager (network disabled)")
                    continue
                assert tool in registered, "Installed tool lacks completion registration: " + tool
                literal(tool + (" -" if tool == "ssh" else " --"))
                key("Tab")
                wait_for(lambda: "╭" in screen().split("TEST>")[-1], tool + " first-Tab completion menu")
                literal(" " + flag)
                wait_for(lambda: any(flag in line and " > " not in line
                         for line in screen().split("TEST>")[-1].splitlines()),
                         tool + " first-Tab flag candidate")
                cancel_menu()
                print("PASS first-Tab flag completion: " + tool)

            if shutil.which("npm"):
                (repo / "package.json").write_text('{"scripts":{"fixture-one":"echo never run","fixture-two":"echo never run"}}\n')
                literal("npm run fixture-")
                key("Tab")
                wait_for(lambda: "fixture-one" in editing() and "fixture-two" in editing(),
                         "npm native script-argument completion")
                cancel_menu()
                print("PASS npm native command/argument completion preserved")

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
            wait_for(menu_open, "Ctrl+T picker opened")
            literal("pick file")
            wait_for(lambda: filename in editing(), "Ctrl+T filename candidate")
            select_menu("Ctrl+T")
            literal(' > "$HOME/file-result"')
            key("Enter")
            wait_for(lambda: (home / "file-result").exists(), "Ctrl+T insertion")
            assert (home / "file-result").read_text() == filename
            assert not (repo / "SHOULD_NOT_RUN").exists()
            print("PASS Ctrl+T safe insertion of spaces, quotes, and shell-looking filename")

            (repo / "second-preview.txt").write_text("second file")
            literal("cat ")
            key("Tab")
            wait_for(menu_open, "Tab file picker opened")
            literal("pick file")
            if shutil.which("bat"):
                wait_for(lambda: "safe preview content" in screen(), "safe contextual file preview")
            else:
                wait_for(lambda: "pick file" in screen(), "file completion without bat")
            assert not (repo / "SHOULD_NOT_RUN").exists()
            cancel_menu()
            print("PASS Tab file preview does not execute candidate text")

            nav = repo / "nav target"
            nav.mkdir()
            key("Escape")
            literal("c")
            wait_for(menu_open, "Alt+C directory picker opened")
            literal("nav target")
            wait_for(lambda: "nav target" in editing(), "Alt+C directory candidate")
            previous = prompt_count()
            select_menu("Alt+C")
            wait_for(lambda: prompt_count() > previous, "Alt+C directory change completed")
            command('pwd > "$HOME/cd-result"')
            wait_for(lambda: (home / "cd-result").exists(), "Alt+C directory navigation")
            assert (home / "cd-result").read_text().strip() == str(nav)
            print("PASS Alt+C directory navigation with spaces")

            command('echo HISTORY_SELECTED > "$HOME/history-result"')
            (home / "history-result").unlink()
            key("C-r")
            wait_for(menu_open, "Ctrl+R history picker opened")
            literal("HISTORY_SELECTED")
            wait_for(lambda: "echo HISTORY_SELECTED" in editing(), "Ctrl+R history candidate")
            select_menu("Ctrl+R")
            literal(" # HISTORY_BUFFER")
            wait_for(lambda: 'echo HISTORY_SELECTED > "$HOME/history-result" # HISTORY_BUFFER'
                     in editing(), "Ctrl+R restored editable command buffer")
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
            wait_for(menu_open, "shared history picker opened")
            literal("TWO_SESSION_SHARED")
            wait_for(lambda: "echo TWO_SESSION_SHARED" in editing(), "shared history candidate")
            select_menu("shared history")
            literal(" # SHARED_BUFFER")
            wait_for(lambda: 'echo TWO_SESSION_SHARED > "$HOME/shared-result" # SHARED_BUFFER'
                     in editing(), "shared history restored editable command buffer")
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
        except BaseException:
            # Save only this fixture's terminal output, never the inherited env,
            # real HOME, plugin files, or history from the invoking user.
            artifacts = os.environ.get("DOTFILES_TEST_ARTIFACT_DIR")
            if artifacts:
                try:
                    destination = Path(artifacts)
                    destination.mkdir(parents=True, exist_ok=True)
                    (destination / "terminal-failure.txt").write_text(traceback.format_exc())
                    for pane in ("shell:0", "shell:second"):
                        result = tmux("capture-pane", "-p", "-J", "-t", pane, "-S", "-100", check=False)
                        if result.returncode == 0:
                            (destination / (pane.replace(":", "-") + ".txt")).write_text(result.stdout)
                except Exception as error:
                    print("Could not save terminal failure diagnostics: " + str(error))
            raise
        finally:
            tmux("kill-server", check=False)


if __name__ == "__main__":
    main()
