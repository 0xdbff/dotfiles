# Add conveniences, never silently replace standard commands such as ls or cd.
if (( $+commands[eza] || $+commands[exa] )); then
  # eza is the maintained exa successor; both accept these options.
  if (( $+commands[eza] )); then
    _dotfiles_listing=eza
  else
    _dotfiles_listing=exa
  fi
  # Keep -F separate: recent eza treats trailing grouped flags as its value.
  alias Ltg="$_dotfiles_listing -laTS -F --no-permissions --octal-permissions --group-directories-first --time-style iso"
  alias Lt="$_dotfiles_listing -laTS -F -I .git --no-permissions --octal-permissions --group-directories-first --time-style iso"
  alias L="$_dotfiles_listing -laS -F --no-permissions --octal-permissions --group-directories-first --time-style iso"
  alias llt="$_dotfiles_listing -1aT -F --group-directories-first"
  alias ll="$_dotfiles_listing -1aF --group-directories-first"
  alias lt="$_dotfiles_listing -1T -F --group-directories-first"
  alias l="$_dotfiles_listing -1F --group-directories-first"
  alias la="$_dotfiles_listing --long --all --group-directories-first"
  unset _dotfiles_listing
else
  alias l='ls'
  alias ll='ls -l'
  alias L='ls -la'
  alias lt='ls -R'
  alias llt='ls -aR'
  alias Lt='ls -laR'
  alias Ltg='ls -laR'
  alias la='ls -lah'
fi
(( $+commands[bat] )) && alias bcat='bat --paging=never'
alias ..='cd ..'
alias ...='cd ../..'
alias ap='apropos'
