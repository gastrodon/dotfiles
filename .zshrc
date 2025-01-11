export ZSH='/usr/share/oh-my-zsh'
export DEVKITPRO='/opt/devkitpro'
export DEVKITARM='/opt/devkitpro/devkitARM'
export DEVKITPPC='/opt/devkitpro/devkitPPC'

ZSH_THEME="liner"
ZSH_CUSTOM="$HOME/.config/oh-my-zsh"

if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='codium --wait'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
alias code="codium"
alias aws="python -m awscli"
function mkcd () {
	mkdir "$@" && cd "$1"
}

function mkvenv () {
	mkdir -pv "$1"; python -m virtualenv "$1"; source "$1/bin/activate"
}

FE_SH_SESSION="$(mktemp -d)/fe.sh"
touch "$FE_SH_SESSION"
function fe() {
	$=EDITOR $FE_SH_SESSION && eval "$(cat $FE_SH_SESSION)"
}


export RM_STAR_SILENT=1 # disables "are you sure you want to remove ..." zsh warning
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# set up node versoin manager
export NVM_DIR="$HOME/.config/nvm" # this is different on mac
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:/opt/android-sdk/platform-tools:$PATH"

source "$ZSH/oh-my-zsh.sh"
