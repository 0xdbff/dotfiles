bindkey -e
KEYTIMEOUT=20
unsetopt correct correctall
zmodload zsh/parameter

# Literal substring history, not history-beginning-search's prefix matching.
typeset -ga _dotfiles_history_events
typeset -g _dotfiles_history_query='' _dotfiles_history_saved=''
typeset -gi _dotfiles_history_index=0 _dotfiles_history_cursor=0
_dotfiles_zsh_history_search() {
  emulate -L zsh
  local direction=$1 event
  if [[ $LASTWIDGET != dotfiles-history-up && $LASTWIDGET != dotfiles-history-down ]]; then
    _dotfiles_history_query=$BUFFER
    _dotfiles_history_saved=$BUFFER
    _dotfiles_history_cursor=$CURSOR
    _dotfiles_history_events=( ${(Onk)history} )
    _dotfiles_history_index=0
  fi
  local -i i=$(( _dotfiles_history_index + direction ))
  while (( i > 0 && i <= ${#_dotfiles_history_events} )); do
    event=$_dotfiles_history_events[i]
    if [[ ${history[$event]} == *"$_dotfiles_history_query"* ]]; then
      _dotfiles_history_index=$i
      BUFFER=${history[$event]}
      CURSOR=${#BUFFER}
      return 0
    fi
    (( i += direction ))
  done
  if (( direction < 0 )); then
    _dotfiles_history_index=0
    BUFFER=$_dotfiles_history_saved
    CURSOR=$_dotfiles_history_cursor
  else
    zle beep
  fi
}
_dotfiles_zsh_history_up() { _dotfiles_zsh_history_search 1 }
_dotfiles_zsh_history_down() { _dotfiles_zsh_history_search -1 }
zle -N dotfiles-history-up _dotfiles_zsh_history_up
zle -N dotfiles-history-down _dotfiles_zsh_history_down
bindkey '^[[A' dotfiles-history-up
bindkey '^[OA' dotfiles-history-up
bindkey '^[[B' dotfiles-history-down
bindkey '^[OB' dotfiles-history-down
bindkey '^[[C' forward-char
bindkey '^[OC' forward-char
bindkey '^[[D' backward-char
bindkey '^[OD' backward-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[Z' reverse-menu-complete

# Parse shell words without evaluating substitutions or executing the buffer.
# Intentionally conservative: ambiguous wrapper options fail closed.
_dotfiles_zsh_help_command() {
  emulate -L zsh
  local -a words
  local word wrapper
  words=( ${(z)1} )
  REPLY=''
  while (( ${#words} )); do
    word=${(Q)words[1]}
    shift words
    [[ $word =~ '^[[:alpha:]_][[:alnum:]_]*=' ]] && continue
    case $word in
      noglob|nocorrect|command|builtin) continue ;;
      sudo|env)
        wrapper=$word
        while (( ${#words} )); do
          word=${(Q)words[1]}
          if [[ $word == -- ]]; then
            shift words
            break
          fi
          [[ $word == -* ]] || break
          shift words
          case $wrapper:$word in
            sudo:-u|sudo:-g|sudo:-h|sudo:-p|sudo:-C|sudo:-T|env:-u|env:--unset)
              (( ${#words} )) || return 1
              shift words ;;
            sudo:-n|sudo:-E|sudo:-H|sudo:-S|sudo:-k|env:-i|env:--ignore-environment) ;;
            *) return 1 ;;
          esac
        done
        continue ;;
    esac
    [[ $word =~ '^[[:alnum:]_][[:alnum:]_.+-]*$' ]] || return 1
    REPLY=$word
    return 0
  done
  return 1
}

_dotfiles_zsh_show_help() {
  emulate -L zsh
  local topic=$1
  [[ $topic =~ '^[[:alnum:]_][[:alnum:]_.+-]*$' ]] || {
    print -u2 'doc: use a simple command or manual-page name'
    return 1
  }
  if (( $+commands[man] )) && command man -w "$topic" >/dev/null 2>&1; then
    command man "$topic"
    return 0
  fi
  (( $+commands[whatis] )) && command whatis -- "$topic" 2>/dev/null
  print -r -- "No manual found for $topic. Try typing '$topic --help' yourself."
  print -r -- 'Help never runs the command in your editing buffer.'
}
doc() {
  if (( $# != 1 )); then
    print -r -- 'Usage: doc COMMAND (manual/whatis); Alt-H or F1 helps the command being edited.'
    print -r -- 'Use apropos WORD (or ap WORD) to search manuals; tldr COMMAND for examples.'
    return 0
  fi
  _dotfiles_zsh_show_help "$1"
}
_dotfiles_zsh_help_widget() {
  local topic
  zle -I
  if _dotfiles_zsh_help_command "$BUFFER"; then
    topic=$REPLY
    _dotfiles_zsh_show_help "$topic"
  else
    print -r -- 'No unambiguous command name. Use doc COMMAND or apropos WORD.'
  fi
  zle reset-prompt
}
zle -N dotfiles-help _dotfiles_zsh_help_widget
bindkey '^[h' dotfiles-help
bindkey '^[OP' dotfiles-help
bindkey '^[[11~' dotfiles-help
