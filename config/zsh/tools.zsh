typeset -g DOTFILES_ZSH_FZF_SOURCE=''
if (( $+commands[fzf] )); then
  export FZF_DEFAULT_OPTS=${FZF_DEFAULT_OPTS:-'--height=60% --layout=reverse --border=rounded'}
  if (( $+commands[fd] )); then
    export FZF_DEFAULT_COMMAND=${FZF_DEFAULT_COMMAND:-'fd --type f --hidden --exclude .git'}
    export FZF_CTRL_T_COMMAND=${FZF_CTRL_T_COMMAND-'fd --hidden --exclude .git'}
    export FZF_ALT_C_COMMAND=${FZF_ALT_C_COMMAND-'fd --type d --hidden --exclude .git'}
  fi
  # Only key-bindings: fzf's completion.zsh conflicts with fzf-tab.
  for _dotfiles_file in \
    "$DOTFILES_ZSH_BREW_PREFIX/opt/fzf/shell/key-bindings.zsh" \
    "$DOTFILES_ZSH_BREW_PREFIX/share/fzf/shell/key-bindings.zsh" \
    /usr/share/fzf/shell/key-bindings.zsh \
    /usr/share/fzf/key-bindings.zsh \
    /usr/share/doc/fzf/examples/key-bindings.zsh; do
    if [[ -r $_dotfiles_file ]]; then
      source "$_dotfiles_file"
      DOTFILES_ZSH_FZF_SOURCE=$_dotfiles_file
      break
    fi
  done
  # Deliberately no --zsh fallback: without fzf-tab it would steal native Tab.
fi
unset _dotfiles_file

if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh --cmd z)"
fi
if (( $+commands[starship] )); then
  export STARSHIP_CONFIG=${STARSHIP_CONFIG:-$DOTFILES_ZSH_ROOT/starship.toml}
  eval "$(starship init zsh)"
else
  # Usable ASCII fallback on hosts where an optional tool is missing.
  PROMPT=$'%F{cyan}%~%f\n%F{green}>%f '
fi
