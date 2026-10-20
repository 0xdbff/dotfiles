# Local system information only: no public-IP lookup or other network requests.
_dotfiles_greeting_addresses() {
  emulate -L zsh
  if (( $+commands[ip] )); then
    command ip -o addr show up scope global 2>/dev/null | awk '
      $3 == "inet" || $3 == "inet6" {
        sub(/@.*/, "", $2); sub(/\/.*/, "", $4); print $2, $4
      }'
  elif (( $+commands[ifconfig] )); then
    command ifconfig -a 2>/dev/null | awk '
      /^[^ \t]/ { interface=$1; sub(/:$/, "", interface); up=($0 ~ /[<,]UP[,>]/) }
      up && ($1 == "inet" || $1 == "inet6") {
        address=$2; sub(/%.*/, "", address)
        if (address !~ /^(127\.|169\.254\.|fe80:)/ && address != "::1")
          print interface, address
      }'
  fi
}

dotfiles_greeting() {
  emulate -L zsh
  local color=0 bold='' green='' reset=''
  if [[ -t 1 && ${TERM:-dumb} != dumb && ! -v NO_COLOR ]]; then
    color=1
    bold=$'\e[1m' green=$'\e[0;32m' reset=$'\e[0m'
  fi
  printf '\n %sOS: %s%s%s\n' "$bold" "$green" "$(command uname -rs)" "$reset"
  printf ' %sUptime: %s%s%s\n' "$bold" "$green" "$(command uptime | sed 's/^[[:space:]]*//')" "$reset"
  printf ' %sHostname: %s%s%s\n\n' "$bold" "$green" "$(command uname -n)" "$reset"

  # -P keeps one filesystem per row on both BSD/macOS and GNU/Linux.
  command df -l -P -h 2>/dev/null | awk -v color="$color" '
    BEGIN { esc=sprintf("%c", 27) }
    $1 ~ /^\/dev\// {
      used=$5+0; tint=""; reset=""
      if (color) {
        if (used >= 85) tint=esc "[0;31m"
        else if (used >= 75) tint=esc "[0;33m"
        reset=esc "[0m"
      }
      mount=$6; for (i=7; i<=NF; i++) mount=mount " " $i
      printf "\t%s%s\t%4s / %4s  %s%s\n", tint, mount, $3, $2, $5, reset
    }'

  printf '\n %sNetwork:%s\n\n' "$bold" "$reset"
  _dotfiles_greeting_addresses | LC_ALL=C sort -u | awk -v color="$color" '
    BEGIN { esc=sprintf("%c", 27) }
    {
      tint=""; underline=""; reset=""
      if (color) {
        tint=esc "[36m"
        if ($1 ~ /^(en|em|eth)/) tint=esc "[39m"
        else if ($1 ~ /^wl/) tint=esc "[35m"
        else if ($1 ~ /^ww/) tint=esc "[33m"
        private=($2 ~ /^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.|[fF][cCdD])/)
        if (!private) underline=esc "[4m"
        reset=esc "[0m"
      }
      printf "\t%s%-12s %s%s%s\n", tint, $1, underline, $2, reset
      found=1
    }
    END { if (!found) print "\tNo active global addresses." }'
  printf '\n'
}

# Quiet in scripts, redirected shells, and tests; show once in a real terminal.
# Set DOTFILES_ZSH_GREETING=0 before sourcing to opt out.
if [[ -o interactive && -t 1 && ${DOTFILES_ZSH_GREETING:-1} != 0 ]] &&
    (( ! ${+_DOTFILES_ZSH_GREETING_SHOWN} )); then
  typeset -g _DOTFILES_ZSH_GREETING_SHOWN=1
  dotfiles_greeting
fi
