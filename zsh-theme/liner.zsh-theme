# vim:ft=zsh ts=2 sts=2

segment_venv_info() {
				if [ $(echo $VIRTUAL_ENV | wc -c) -gt 1 ]; then
								print -n "%{$fg[green]%}$(basename $VIRTUAL_ENV):%{$fg[white]%}"
				fi
}

segment_user_info() {
				print -n "$(whoami)@$(hostname) "
}

segment_path_info() {
				where="${$(pwd)##*/}"
				[ $(pwd) = "/" ] && where="/"
				[ $(pwd) = "$HOME" ] && where="~"
				print -n "$where "
}

segment_git_info() {
				in_git="0"

				[ -d .git ] || git rev-parse --git-dir > /dev/null 2>&1 && in_git="1"

				if [ $in_git -eq "0" ]; then
								return
				fi

				if [ $(git status --porcelain | wc -l) -gt "0" ]; then
								color="yellow"
				else
								color="green"
				fi

				branch_name=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

				if [ $(git remote -v | wc -l) -lt "1" ]; then
								print -n "${$(pwd)##*/}%{$fg[$color]%}/$branch_name"
								return
				fi

				repo_name=$(basename -s .git `git config --get remote.origin.url`)
				branch_name=$(git rev-parse --abbrev-ref HEAD)
				print -n "$repo_name%{$fg[$color]%}/$branch_name"

				unpushed=$(git cherry 2>/dev/null | wc -l)
				 
				if [ $unpushed -gt "0" ]; then
								print -n "+$unpushed"
				fi

				print -n "%{$fg[white]%}"
}

segment_pre_line() {
				color=white
				[ $RETVAL -ne 0 ] && color=red
				[ $(jobs -l | wc -l) -gt 0 ] && color=blue

				prefix="---"
				[ $RETVAL = "127" ] && prefix="???"

				print -n "\n%{$fg[$color]%}$prefix%{$fg[white]%} "
}

prompt_main() {
				RETVAL=$?
				segment_venv_info
				segment_user_info
				segment_path_info
				segment_git_info
				segment_pre_line
}

prompt_liner_precmd() {
				vcs_info
				PROMPT='$(prompt_main)'
}

liner_setup() {
				autoload -Uz add-zsh-hook
				autoload -Uz vcs_info
				prompt_opts=(cr subst percent)
				add-zsh-hook precmd prompt_liner_precmd
}

liner_setup "$@"
