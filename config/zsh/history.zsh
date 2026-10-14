zmodload zsh/stat

# Private state only; never trust a symlink, foreign owner, or writable directory.
_dotfiles_zsh_private_dir() {
  emulate -L zsh
  local -A st
  [[ ! -L $1 ]] || return 1
  if [[ ! -d $1 ]]; then
    ( umask 077; command mkdir -p -- "$1" ) || return 1
  fi
  [[ -O $1 ]] && zstat -H st -- "$1" || return 1
  (( (st[mode] & 8#22) == 0 ))
}

HISTSIZE=100000
SAVEHIST=100000
setopt extended_history share_history hist_ignore_dups hist_ignore_space
setopt hist_fcntl_lock hist_save_by_copy
# Keep chronological history: no HIST_IGNORE_ALL_DUPS or expire/dedup rewriting.
unsetopt hist_ignore_all_dups hist_expire_dups_first hist_save_no_dups
unsetopt inc_append_history inc_append_history_time
typeset -g DOTFILES_ZSH_HISTORY_READY=0
if _dotfiles_zsh_private_dir "$DOTFILES_ZSH_STATE"; then
  HISTFILE=$DOTFILES_ZSH_STATE/history
  if [[ ! -e $HISTFILE && ! -L $HISTFILE ]]; then
    ( umask 077; : > "$HISTFILE" )
  fi
  if [[ -f $HISTFILE && -O $HISTFILE && ! -L $HISTFILE ]]; then
    if command chmod 600 "$HISTFILE"; then
      DOTFILES_ZSH_HISTORY_READY=1
    else
      unset HISTFILE
    fi
  else
    unset HISTFILE
  fi
else
  unset HISTFILE
fi

# Only bare, trivial commands are omitted; commands with arguments remain useful.
_dotfiles_zsh_add_history() {
  local line=${1%$'\n'}
  case $line in
    ''|ls|ll|la|pwd|clear|exit) return 1 ;;
  esac
  return 0
}
autoload -Uz add-zsh-hook
add-zsh-hook zshaddhistory _dotfiles_zsh_add_history
