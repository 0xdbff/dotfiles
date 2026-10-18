# Managed entry point: safe to source repeatedly, and inert outside interactive Zsh.
[[ -o interactive ]] || return 0
(( ${+_DOTFILES_ZSH_INITIALIZED} )) && return 0
typeset -g _DOTFILES_ZSH_INITIALIZED=1
typeset -g DOTFILES_ZSH_ROOT=${${(%):-%N}:A:h:h}
typeset -g DOTFILES_ZSH_CACHE=${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-zsh
typeset -g DOTFILES_ZSH_STATE=${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles-zsh
typeset -g DOTFILES_ZSH_PLUGIN_DIR=${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles-zsh/plugins
typeset -g DOTFILES_ZSH_BREW_PREFIX=${HOMEBREW_PREFIX:-}
if [[ -z $DOTFILES_ZSH_BREW_PREFIX && -n ${commands[brew]:-} ]]; then
  DOTFILES_ZSH_BREW_PREFIX=${commands[brew]:h:h}
fi
if [[ -z $DOTFILES_ZSH_BREW_PREFIX && $OSTYPE == darwin* ]]; then
  for _dotfiles_prefix in /opt/homebrew /usr/local; do
    if [[ -x $_dotfiles_prefix/bin/brew ]]; then
      DOTFILES_ZSH_BREW_PREFIX=$_dotfiles_prefix
      break
    fi
  done
  unset _dotfiles_prefix
fi
# Includes the verified Fedora Starship fallback, without touching .zshenv.
typeset -U path
if [[ -n $DOTFILES_ZSH_BREW_PREFIX ]]; then
  path=("$DOTFILES_ZSH_BREW_PREFIX/bin" "$DOTFILES_ZSH_BREW_PREFIX/sbin" $path)
fi
path=("$HOME/.local/bin" $path)

# These files deliberately register all widgets before syntax highlighting.
source "$DOTFILES_ZSH_ROOT/zsh/history.zsh"
source "$DOTFILES_ZSH_ROOT/zsh/completion.zsh"
source "$DOTFILES_ZSH_ROOT/zsh/widgets.zsh"
source "$DOTFILES_ZSH_ROOT/zsh/tools.zsh"
source "$DOTFILES_ZSH_ROOT/zsh/plugins.zsh"
source "$DOTFILES_ZSH_ROOT/zsh/aliases.zsh"
[[ -r ${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles-zsh.local.zsh ]] &&
  source "${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles-zsh.local.zsh"

# MUST remain the final sourced plugin: it observes the complete widget set.
typeset -g DOTFILES_ZSH_HIGHLIGHTING_SOURCE=''
for _dotfiles_file in \
  "$DOTFILES_ZSH_BREW_PREFIX/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" \
  /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh \
  /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh; do
  if [[ -r $_dotfiles_file ]]; then
    DOTFILES_ZSH_HIGHLIGHTING_SOURCE=$_dotfiles_file
    source "$_dotfiles_file"
    break
  fi
done
unset _dotfiles_file
