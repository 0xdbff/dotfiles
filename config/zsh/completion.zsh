# Every completion directory must be in fpath BEFORE compinit.
typeset -U fpath
typeset -ga _dotfiles_completion_dirs
_dotfiles_completion_dirs=(
  "$DOTFILES_ZSH_CACHE/completions"
  "$HOME/.docker/completions"
  "$HOME/Applications/Alacritty.app/Contents/Resources/completions"
  "${RUSTUP_HOME:-$HOME/.rustup}/completions"
  "$DOTFILES_ZSH_BREW_PREFIX/share/zsh/site-functions"
  "$DOTFILES_ZSH_BREW_PREFIX/share/zsh-completions"
  /usr/local/share/zsh/site-functions
  /usr/share/zsh/site-functions
  /usr/share/zsh/vendor-completions
  "$DOTFILES_ZSH_PLUGIN_DIR/zsh-completions/src"
)
for _dotfiles_dir in "${_dotfiles_completion_dirs[@]}"; do
  [[ -d $_dotfiles_dir ]] && fpath+=("$_dotfiles_dir")
done
# Prefer explicitly generated tool completions over older system definitions.
[[ -d $DOTFILES_ZSH_CACHE/completions ]] &&
  fpath=("$DOTFILES_ZSH_CACHE/completions" $fpath)
unset _dotfiles_dir _dotfiles_completion_dirs

autoload -Uz compinit compaudit
# compdump uses a temporary file; keep its final permissions private as well.
_dotfiles_zsh_compinit() {
  local saved_umask=$(umask)
  umask 077
  compinit "$@"
  local result=$?
  umask "$saved_umask"
  return $result
}
typeset -g DOTFILES_ZSH_COMPLETION_READY=0
typeset -g DOTFILES_ZSH_COMPDUMP=''
if (( ! ${+_comps} )); then
  if _dotfiles_zsh_private_dir "$DOTFILES_ZSH_CACHE"; then
    DOTFILES_ZSH_COMPDUMP=$DOTFILES_ZSH_CACHE/zcompdump-$ZSH_VERSION
    # A dump is executable shell code. Reject unsafe files before compinit reads it.
    typeset -A _dotfiles_dump_stat
    if [[ -e $DOTFILES_ZSH_COMPDUMP || -L $DOTFILES_ZSH_COMPDUMP ||
          -e $DOTFILES_ZSH_COMPDUMP.zwc || -L $DOTFILES_ZSH_COMPDUMP.zwc ]]; then
      if [[ -f $DOTFILES_ZSH_COMPDUMP && -O $DOTFILES_ZSH_COMPDUMP && ! -L $DOTFILES_ZSH_COMPDUMP &&
            ! -e $DOTFILES_ZSH_COMPDUMP.zwc && ! -L $DOTFILES_ZSH_COMPDUMP.zwc ]] &&
          zstat -H _dotfiles_dump_stat -- "$DOTFILES_ZSH_COMPDUMP" &&
          (( (_dotfiles_dump_stat[mode] & 8#22) == 0 )); then
        _dotfiles_zsh_compinit -i -d "$DOTFILES_ZSH_COMPDUMP"
      else
        DOTFILES_ZSH_COMPDUMP=''
        _dotfiles_zsh_compinit -i -D
      fi
    else
      ( umask 077; : > "$DOTFILES_ZSH_COMPDUMP" )
      _dotfiles_zsh_compinit -i -d "$DOTFILES_ZSH_COMPDUMP"
    fi
    unset _dotfiles_dump_stat
  else
    _dotfiles_zsh_compinit -i -D
  fi
fi
(( ${+_comps} && ${+functions[compdef]} )) && DOTFILES_ZSH_COMPLETION_READY=1

# Existing compsys is allowed. Register newly generated #compdef files even if
# another .zshrc already called compinit, or a dump has the same file count.
if (( DOTFILES_ZSH_COMPLETION_READY )); then
  () {
    emulate -L zsh
    local file header name
    local -a names
    local -A st
    [[ -d $DOTFILES_ZSH_CACHE/completions ]] || return 0
    compaudit "$DOTFILES_ZSH_CACHE/completions" >/dev/null 2>&1 || return 0
    for file in "$DOTFILES_ZSH_CACHE/completions"/_*(N-.); do
      [[ -O $file && ! -L $file ]] || continue
      zstat -H st -- "$file" && (( (st[mode] & 8#22) == 0 )) || continue
      IFS= read -r header < "$file"
      [[ $header == '#compdef '* ]] || continue
      names=( ${(z)${header#\#compdef }} )
      # pnpm's generator emits a sourced adapter, not an autoloading `_pnpm`
      # function (unlike Docker/kubectl). Load it once to register the real
      # _pnpm_completion dispatcher, including pn when the tool provides it.
      if [[ ${file:t} == _pnpm ]]; then
        source "$file"
        continue
      fi
      # Generated definitions only name commands; never interpret code/options.
      unfunction "${file:t}" 2>/dev/null
      autoload -Uz "${file:t}"
      for name in "${names[@]}"; do
        [[ $name =~ '^[[:alnum:]_][[:alnum:]_.+-]*$' ]] || continue
        compdef "${file:t}" "$name"
      done
    done
  }
fi

zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches: %d'
zstyle ':completion:*' verbose yes
zstyle ':completion:*' completer _complete _approximate
# Exact prefixes first. Zsh 5.9 can corrupt Git's unambiguous expansion when
# case folding is enabled on the first pass (e.g. fish- -> fish-B).
# Then case-insensitive, word-boundary and substring fallback matching.
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' \
  'm:{a-zA-Z}={A-Za-z} r:|[._-]=* r:|=*' \
  'm:{a-zA-Z}={A-Za-z} l:|=* r:|=*'
zstyle ':completion:*:approximate:*' max-errors '1 numeric'
zstyle ':completion:*' complete-options true
zstyle ':completion:*' menu select
zstyle ':completion:*:git-checkout:*' sort false
[[ -n ${LS_COLORS:-} ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Previews never execute a candidate. Size-qualified regular files only; no
# devices, FIFOs, symlinks, or unbounded reads. No previews for arbitrary args.
zstyle ':fzf-tab:complete:*' fzf-preview \
  'local -a small; small=( "$realpath"(N-.L-1048577) ); if [[ ! -L $realpath ]] && (( $#small )); then if (( $+commands[bat] )); then bat --color=always --style=numbers --paging=never --line-range=:160 -- "$realpath"; else command ls -ld -- "$realpath"; fi; elif [[ -d $realpath && ! -L $realpath ]]; then command ls -A -- "$realpath" | command head -80; fi'
zstyle ':fzf-tab:complete:cd:*' fzf-preview '[[ -d $realpath ]] && command ls -A -- "$realpath" | command head -80'
zstyle ':fzf-tab:complete:-command-:*' fzf-preview \
  '[[ $word =~ "^[[:alnum:]_][[:alnum:]_.+-]*$" ]] && command whatis -- "$word" 2>/dev/null'
zstyle ':fzf-tab:*' fzf-flags --height=60% --layout=reverse --border=rounded --preview-window=right:50%:wrap
# Keep fzf-tab's documented F1/F2 group navigation.
