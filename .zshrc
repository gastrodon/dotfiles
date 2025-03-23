export ZSH='/usr/share/oh-my-zsh'
export DEVKITPRO='/opt/devkitpro'
export DEVKITARM='/opt/devkitpro/devkitARM'
export DEVKITPPC='/opt/devkitpro/devkitPPC'

ZSH_THEME="liner"
ZSH_CUSTOM="$HOME/.config/oh-my-zsh"

export EDITOR='vim'

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

function code-remote() {
	r="$1"
	shift
	code --folder-uri vscode-remote://ssh-remote+$r$@
}

export RM_STAR_SILENT=1 # disables "are you sure you want to remove ..." zsh warning
export DOTNET_CLI_TELEMETRY_OPTOUT=1

# set up node versoin manager
export NVM_DIR="$HOME/.config/nvm" # this is different on mac
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$HOME/go/bin:/opt/android-sdk/platform-tools:$PATH"

source "$ZSH/oh-my-zsh.sh"

# colors
function black() { echo -e "\e[30m$@\e[0m"; }
function black-bg() { echo -e "\e[40m$@\e[0m"; }
function red() { echo -e "\e[31m$@\e[0m"; }
function red-bg() { echo -e "\e[41m$@\e[0m"; }
function green() { echo -e "\e[32m$@\e[0m"; }
function green-bg() { echo -e "\e[42m$@\e[0m"; }
function yellow() { echo -e "\e[33m$@\e[0m"; }
function yellow-bg() { echo -e "\e[43m$@\e[0m"; }
function blue() { echo -e "\e[34m$@\e[0m"; }
function blue-bg() { echo -e "\e[44m$@\e[0m"; }
function magenta() { echo -e "\e[35m$@\e[0m"; }
function magenta-bg() { echo -e "\e[45m$@\e[0m"; }
function cyan() { echo -e "\e[36m$@\e[0m"; }
function cyan-bg() { echo -e "\e[46m$@\e[0m"; }
function white() { echo -e "\e[37m$@\e[0m"; }
function white-bg() { echo -e "\e[47m$@\e[0m"; }
function bright-black() { echo -e "\e[90m$@\e[0m"; }
function bright-black-bg() { echo -e "\e[100m$@\e[0m"; }
function bright-red() { echo -e "\e[91m$@\e[0m"; }
function bright-red-bg() { echo -e "\e[101m$@\e[0m"; }
function bright-green() { echo -e "\e[92m$@\e[0m"; }
function bright-green-bg() { echo -e "\e[102m$@\e[0m"; }
function bright-yellow() { echo -e "\e[93m$@\e[0m"; }
function bright-yellow-bg() { echo -e "\e[103m$@\e[0m"; }
function bright-blue() { echo -e "\e[94m$@\e[0m"; }
function bright-blue-bg() { echo -e "\e[104m$@\e[0m"; }
function bright-magenta() { echo -e "\e[95m$@\e[0m"; }
function bright-magenta-bg() { echo -e "\e[105m$@\e[0m"; }
function bright-cyan() { echo -e "\e[96m$@\e[0m"; }
function bright-cyan-bg() { echo -e "\e[106m$@\e[0m"; }
function bright-white() { echo -e "\e[97m$@\e[0m"; }
function bright-white-bg() { echo -e "\e[107m$@\e[0m"; }

