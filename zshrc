#!/usr/bin/env zsh

ZSH_THEME="liner"
CASE_SENSITIVE="false"
HYPHEN_INSENSITIVE="false"

export EDITOR="atom --no-sandbox --wait"
export ZSH="$HOME/.oh-my-zsh"
export NVM_DIR="$HOME/.config/nvm"
export PATH="$HOME/.local/bin:$HOME/.local/bin/scripts:$PATH"

zstyle ':omz:update' mode auto    # update automatically without asking
zstyle ':omz:update' frequency 2  # update every 2 days

plugins=(git)   # load our plugins

source $HOME/.tokens
source $ZSH/oh-my-zsh.sh
[ -s "$NVM_DIR/nvm.sh" ] && source "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && source "$NVM_DIR/bash_completion"

alias atom='atom --no-sandbox'
alias clear='printf "\033c"'

[ -z "$NO_SSH_AGENT" ] && [ -z "$SSH_AGENT_PID" ] \
  && eval $(ssh-agent -s) > /dev/null \
  && ssh-add "$HOME/.ssh/id_ed25519"
