# vim:ft=zsh ts=2 sts=2

segment_venv_info() {
				if [ $(echo $VIRTUAL_ENV | wc -c) -gt 1 ]; then
								print -n "%{$fg[green]%}$(basename $VIRTUAL_ENV):%{$fg[white]%}"
				fi
}

segment_user_info() {
				print -n "%n@%m "
}

segment_path_info() {
				local where="${PWD##*/}"
				[[ $PWD = / ]] && where="/"
				[[ $PWD = "$HOME" ]] && where="~"
				print -n "$where "
}

segment_git_info() {
				local color repo_name
				if ! git rev-parse --git-dir 2>/dev/null 1>&2; then
					return
				fi

				if [ "$(git status --porcelain 2>/dev/null | wc -l)" -gt "0" ]; then
								color="yellow"
				else
								color="green"
				fi

				local branch_name="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)"
				local remote_name="$(git remote | head -n1 2> /dev/null)"

				if [ "$(git remote -v | wc -l)" -lt "1" ]; then
								print -n "${PWD##*/}%{$fg[$color]%}/$branch_name"
								return
				fi

				local repo_origin="$(git config --get remote.origin.url)"
				if [ ! -z "$repo_origin" ]; then
					repo_name="$(basename -s .git $repo_origin)"
				else
					repo_name="${PWD##*/}"
				fi


				print -n "$repo_name%{$fg[$color]%}/$branch_name"

				local unpushed="$(eval "git log --oneline $remote_name.. 2>/dev/null" | wc -l | tr -d '[:space:]')"
				if [ $unpushed -gt "0" ]; then
								print -n "+$unpushed"
				fi

				print -n "%{$fg[white]%}"
}

segment_aws_info() {
	if [ "$AWS_PROFILE" ]; then
		print -n " [aws:$AWS_PROFILE";
		if [ "$AWS_REGION" ]; then print -n ", %{$fg[green]%}$AWS_REGION%{$fg[white]%}"; fi
		print -n "]"
	fi
}

segment_pre_line() {
				local color=white
				[ $RETVAL -ne 0 ] && color=red
				[ $(jobs -l | wc -l) -gt 0 ] && color=blue

				local prefix="---"
				[ $RETVAL = "127" ] && prefix="???"

				print -n "\n%{$fg[$color]%}$prefix%{$fg[white]%} "
}

prompt_main() {
				RETVAL=$?
				segment_venv_info
				segment_user_info
				segment_path_info
				segment_git_info
				segment_aws_info
				segment_pre_line
}

prompt_liner_precmd() {
				PROMPT='$(prompt_main)'
}

liner_setup() {
				autoload -Uz add-zsh-hook
				prompt_opts=(cr subst percent)
				add-zsh-hook precmd prompt_liner_precmd
}

liner_setup "$@"
