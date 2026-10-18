"""Parser regressions supplement (not replace) the real tmux keystroke suite."""
import unittest
from unittest.mock import patch
import subprocess

from interactive import flag_has_description, unprovisioned_pnpm_shim


class TerminalMetadata(unittest.TestCase):
    def test_only_unprovisioned_corepack_launcher_is_not_an_installed_manager(self):
        for status, error, expected in (
            (1, "Network access disabled by the environment", True),
            (1, "Cannot find module /cache/corepack/pnpm.cjs", True),
            (0, "", False),
            (1, "A real pnpm command failed for another reason", False),
        ):
            with self.subTest(error=error):
                with patch("interactive.subprocess.run", return_value=subprocess.CompletedProcess([], status, "", error)) as run:
                    self.assertEqual(unprovisioned_pnpm_shim(), expected)
                    self.assertEqual(run.call_args.kwargs["env"]["COREPACK_ENABLE_NETWORK"], "0")

    def test_native_zsh_wording_is_not_an_english_phrase_allowlist(self):
        for description in ("prints the git suite version", "display version information",
                            "zeigt die Git-Version", "版本信息"):
            with self.subTest(description=description):
                self.assertTrue(flag_has_description(
                    "│ ▌ ·--version             -- " + description + " ││ │",
                    "--version"))

    def test_query_command_or_bare_candidate_is_not_metadata(self):
        for pane in ("TEST> git --version -- prints the git suite version",
                     "│ > --version -- prints the git suite version │",
                     "│ ▌ ·--version │", "│ ▌ ·--version --    ││ │",
                     "│ ▌ ·--version-other -- prints version │",
                     "│ --other -- prints version information │"):
            with self.subTest(pane=pane):
                self.assertFalse(flag_has_description(pane, "--version"))

    def test_joined_terminal_wrap_retains_description(self):
        # capture-pane -J joins physical wraps before parsing completion rows.
        self.assertTrue(flag_has_description(
            "│ --version             -- prints the git suite version "
            "and additional provider-specific text │", "--version"))


if __name__ == "__main__":
    unittest.main()
