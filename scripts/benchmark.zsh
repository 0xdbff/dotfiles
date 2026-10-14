#!/bin/zsh -f
# Uses the real interactive initialization, but no personal rc files.
emulate -L zsh
zmodload zsh/datetime
local_init=${1:-${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles-zsh/zsh/init.zsh}
[[ -r $local_init ]] || { print -u2 'Install the configuration first (or pass init.zsh).'; exit 1; }
typeset -a samples
typeset -F start elapsed
# The first run warms the compinit dump. Report it separately.
for n in {0..7}; do
  start=$EPOCHREALTIME
  zsh -dfi -o no_zle -c 'source "$1"' -- "$local_init" >/dev/null || exit 1
  elapsed=$(( (EPOCHREALTIME - start) * 1000 ))
  if (( n == 0 )); then
    printf 'First startup: %.1f ms\n' $elapsed
  else
    samples+=($elapsed)
  fi
done
samples=(${(on)samples})
printf 'Warm startup: median %.1f ms; range %.1f–%.1f ms (7 runs)\n' $samples[4] $samples[1] $samples[-1]
print 'Measures interactive initialization, not terminal launch or first prompt rendering.'
(( samples[4] <= 200 )) || print 'NOTE: above the ~200 ms target; profile local customizations and installed tools.'
exit 0
