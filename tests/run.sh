#!/bin/bash
set -eu
root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
cd "$root"
python3 -m unittest discover -s tests -p 'test_*.py' -v
if command -v shellcheck >/dev/null 2>&1; then
    shellcheck -x setup.sh install.sh scripts/*.sh tests/*.sh
else
    echo 'SKIP ShellCheck (install shellcheck to run static lint).'
fi
