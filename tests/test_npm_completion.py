"""The npm adapter uses installed definitions and preserves the native protocol."""
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


@unittest.skipUnless(shutil.which("node"), "requires Node for npm metadata generation")
class NpmMetadata(unittest.TestCase):
    def test_real_definition_shapes_and_description_quoting(self):
        with tempfile.TemporaryDirectory(prefix="npm-definitions-") as temp:
            root = Path(temp) / "npm"
            (root / "bin").mkdir(parents=True)
            entry = root / "bin/npm-cli.js"
            entry.write_text("// fixture launcher\n")
            definitions = root / "node_modules/@npmcli/config/lib/definitions"
            definitions.mkdir(parents=True)
            definitions.joinpath("index.js").write_text('''module.exports = {definitions: {
              global: {type: Boolean, short: 'g', description: "Operate in global mode [safe]: don't execute $(touch BAD)"},
              workspace: {type: [String, Array], short: 'w', description: 'Choose workspace'},
              color: {type: [Boolean, 'always'], description: 'Color output'},
              'loglevel': {type: ['silent', 'info'], description: 'Logging level'}
            }};''')
            result = subprocess.run(["node", str(ROOT / "scripts/npm-completion.js"), str(entry)],
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, timeout=20)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(result.stdout.startswith("#compdef npm\n"))
            self.assertIn("--global[Operate in global mode", result.stdout)
            self.assertIn("-g[", result.stdout)
            self.assertIn("*--workspace=", result.stdout)
            self.assertIn("--color=-[Color output]::value:(always)", result.stdout)
            self.assertIn("(silent info)", result.stdout)
            self.assertIn("command npm completion", result.stdout)
            script = Path(temp) / "_npm"
            script.write_text(result.stdout)
            if shutil.which("zsh"):
                syntax = subprocess.run(["zsh", "-fn", str(script)], capture_output=True, text=True, timeout=10)
                self.assertEqual(syntax.returncode, 0, syntax.stderr)
            self.assertFalse(Path(temp, "BAD").exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
