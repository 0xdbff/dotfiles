#!/bin/bash
install_platform() {
    if [ "$DRY_RUN" = 1 ]; then
        plan require-homebrew
        plan brew install zsh fzf zoxide bat eza fd ripgrep starship git tealdeer zsh-completions zsh-autosuggestions zsh-syntax-highlighting fzf-tab
        return
    fi
    enable_homebrew
    # No sudo for Homebrew, including on Apple Silicon.
    install_missing_brew_formulas zsh fzf zoxide bat eza fd ripgrep starship git tealdeer zsh-completions zsh-autosuggestions zsh-syntax-highlighting fzf-tab
}
