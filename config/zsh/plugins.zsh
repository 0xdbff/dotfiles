typeset -g DOTFILES_ZSH_FZF_TAB_SOURCE='' DOTFILES_ZSH_AUTOSUGGEST_SOURCE=''
if (( DOTFILES_ZSH_COMPLETION_READY && $+commands[fzf] )); then
  for _dotfiles_file in \
    "$DOTFILES_ZSH_BREW_PREFIX/share/fzf-tab/fzf-tab.zsh" \
    /usr/share/fzf-tab/fzf-tab.plugin.zsh \
    /usr/share/fzf-tab/fzf-tab.zsh \
    /usr/share/zsh/plugins/fzf-tab/fzf-tab.plugin.zsh \
    "$DOTFILES_ZSH_PLUGIN_DIR/fzf-tab/fzf-tab.plugin.zsh"; do
    if [[ -r $_dotfiles_file ]]; then
      zstyle ':completion:*' menu no
      source "$_dotfiles_file"
      DOTFILES_ZSH_FZF_TAB_SOURCE=$_dotfiles_file
      break
    fi
  done
fi

typeset -ga ZSH_AUTOSUGGEST_STRATEGY=(history completion)
typeset -g ZSH_AUTOSUGGEST_USE_ASYNC=1
typeset -g ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=80
typeset -g ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=8'
for _dotfiles_file in \
  "$DOTFILES_ZSH_BREW_PREFIX/share/zsh-autosuggestions/zsh-autosuggestions.zsh" \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh; do
  if [[ -r $_dotfiles_file ]]; then
    source "$_dotfiles_file"
    DOTFILES_ZSH_AUTOSUGGEST_SOURCE=$_dotfiles_file
    break
  fi
done
unset _dotfiles_file
