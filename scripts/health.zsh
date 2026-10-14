# Invoked in an isolated interactive Zsh by check.sh; never source personal .zshrc.
typeset -gi health_failures=0
_health() {
  if eval "$2"; then
    print -r -- "OK   $1"
  else
    print -r -- "FAIL $1"
    (( health_failures++ ))
  fi
}
_health 'completion system' '(( $+functions[compdef] && $+_comps[git] && $+_comps[ssh] ))'
_health 'autosuggestions' '(( $+functions[_zsh_autosuggest_start] ))'
_health 'syntax highlighting' '(( $+functions[_zsh_highlight] ))'
_health 'fzf-tab' '(( $+functions[enable-fzf-tab] ))'
_health 'fuzzy history widget' '(( $+widgets[fzf-history-widget] ))'
_health 'Ctrl+R binding' '[[ $(bindkey "^R") == *fzf-history-widget* ]]'
_health 'Ctrl+T binding' '[[ $(bindkey "^T") == *fzf-file-widget* ]]'
_health 'Alt+C binding' '[[ $(bindkey "^[c") == *fzf-cd-widget* ]]'
_health 'shared, private-space history' '[[ -o sharehistory && -o histignorespace && -o histignoredups ]]'
_health 'private persistent history file' '(( DOTFILES_ZSH_HISTORY_READY ))'
_health 'documentation shortcut' '[[ $(bindkey "^[h") == *dotfiles-help* ]]'
for source_name in DOTFILES_ZSH_FZF_SOURCE DOTFILES_ZSH_FZF_TAB_SOURCE DOTFILES_ZSH_AUTOSUGGEST_SOURCE DOTFILES_ZSH_HIGHLIGHTING_SOURCE; do
  print -r -- "INFO $source_name: ${(P)source_name:-not loaded}"
done
for tool in git docker kubectl cargo npm pnpm ssh systemctl brew dnf; do
  if (( $+commands[$tool] )); then
    if [[ -n ${_comps[$tool]} ]]; then
      print -r -- "OK   completion metadata: $tool -> ${_comps[$tool]}"
    else
      print -r -- "WARN no completion definition registered for installed tool: $tool"
    fi
  fi
done
unfunction _health
exit $(( health_failures != 0 ))
