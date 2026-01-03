export ZSH='/usr/share/oh-my-zsh'

ZSH_THEME="liner"
ZSH_CUSTOM="$HOME/.config/oh-my-zsh"

export EDITOR='vim'
alias code="codium"

function scrt () {
	disc="$1";
	if [[ "$disc" == "@obsidian" ]]; then
		shift;
		f="$(date +'%d-%m-%Y-%_H-%M-%S').png";

		scrot --select --ignorekeyboard "$HOME/Documents/obsidian-vault/root/scrt/$f";
		xdg-open "obsidian://open?vault=root&file=scrt/$f";
	else
		shift;
		f="$HOME/Pictures/scrot/$disc-$(date +'%d-%m-%Y-%_H-%M-%S').png";
		scrot --select --ignorekeyboard "$f"
		echo "$f";
	fi

}

FE_SH_SESSION="$(mktemp -d)/fe.sh"
touch "$FE_SH_SESSION"
function fe() {
	$=EDITOR $FE_SH_SESSION && eval "$(cat $FE_SH_SESSION)"
}


# one of these disables "are you sure you want to remove ..." zsh warning
setopt rm_star_silent
export RM_STAR_SILENT=1

source "$ZSH/oh-my-zsh.sh"

# colors - move this to a separate nix pkg
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

