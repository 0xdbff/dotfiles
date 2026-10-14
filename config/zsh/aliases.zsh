# Add conveniences, never silently replace standard commands such as ls or cd.
if (( $+commands[eza] )); then
  alias ll='eza --long --group-directories-first'
  alias la='eza --long --all --group-directories-first'
else
  alias ll='ls -lh'
  alias la='ls -lah'
fi
(( $+commands[bat] )) && alias bcat='bat --paging=never'
alias ..='cd ..'
alias ...='cd ../..'
alias ap='apropos'
