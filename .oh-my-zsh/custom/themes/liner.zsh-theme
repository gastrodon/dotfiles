_segment_venv_info() {
				if [ $(echo $VIRTUAL_ENV | wc -c) -gt 1 ]; then
								print -n "%{$fg[green]%}$(basename $VIRTUAL_ENV):%{$fg[white]%}"
				fi
}

okay () {
    print -n "$fg[green]$@$fg[white]"
}

warn () {
    print -n "$fg[yellow]$@$fg[white]"
}

error () {
    print -n "$fg[red]$@$fg[white]"
}

user() {
				print -n "$(whoami)"
}

host() {
				print -n "$(cat /etc/hostname)"
}

in_directory() {
				[ $(pwd) = "/" ] && \
						print -n "/" && return

				[ $(pwd) = "$HOME" ] && \
						print -n "~" && return

				print -n "${$(pwd)##*/}"
}

in_repo_directory() {
	print -n "${$( \
		git rev-parse --git-dir \
		| sed 's/\/\.git//g' \
	)##*/}"
}

in_repo_unpushed() {
	[ -z "$(git rev-parse --git-dir 2>/dev/null)" ] \
		|| [ -z "$(git remote)" ] \
		|| [ -z "$(git branch)" ] \
		&& return

	[ "$NAME_REMOTE" ] \
		&& name_remote="$NAME_REMOTE" \
		|| name_remote="$(git remote)"

	[ "$NAME_BRANCH" ] \
		&& name_branch="$NAME_BRANCH" \
		|| name_branch="$(git rev-parse --abbrev-ref HEAD)"

	[ "$NAME_BRANCH_DEFAULT" ] \
		&& name_branch_default="$NAME_BRANCH_DEFAULT" \
		|| name_branch_default="master"

	# TODO this can fail if we're offline, which happens a lot
	# name_branch_default="$( \
	# 	git remote show "$name_remote" \
	# 	| grep -E 'HEAD branch: .+' \
	# 	| cut -d':' -f2 \
	# 	| tr -d '[:space:]'
	# )"

	[ "$(git branch -r | grep "$name_remote/$name_branch")" ] && has_remote="YES"

	[ "$has_remote" ] \
		&& above_remote="$(git log --oneline "$name_remote/$name_branch".."$name_branch" | wc -l)" \
		|| above_remote="0"

	[ ! "$name_branch" = "$name_branch_default" ] \
		&& above_default="$(git log --oneline "$name_remote/$name_branch_default".."$name_branch" | wc -l)" \
		|| above_default="0"


	delta="$(expr $above_default - $above_remote)"

	[ "$above_remote" -eq "0" ] \
		&& print -n "$(okay " [ +$delta ]")" \
		|| print -n "$(warn " +$above_remote") $(okay "[ +$delta ]")"
}

in_repo() {
	[ -z "$(git rev-parse --git-dir 2>/dev/null)" ] && return

	[ ".git" = "$(in_repo_directory)" ] \
			&& name_remote="$(warn "$(in_directory)")" \
			|| name_remote="$(warn "$(in_repo_directory)")"

	[ "$(git remote)" ] \
	&& name_remote="$(okay "$(basename -s .git `git config --get remote.origin.url`)" )"

	[ -z "$(git branch)" ] \
		&& name_branch="HEAD" \
		|| name_branch="$(git rev-parse --abbrev-ref HEAD)"

	[ "$(git status --porcelain)" ] \
		&& print -n "$name_remote$(warn /$name_branch)$(okay)" \
		|| print -n "$name_remote$(okay /$name_branch)$(okay)" \
}

line_prompt() {
				color=white
				[ "$RETVAL" -ne 0 ] && color=red
				[ $(jobs -l | wc -l) -gt 0 ] && color=blue

				prefix="---"
				[ ! -z "$VIRTUAL_ENV" ] && prefix="~~~"
				[ "$RETVAL" -eq 127 ] && prefix="???"

				print -n "%{$fg[$color]%}$prefix%{$fg[white]%} "
}

prompt_main() {
				RETVAL=$?

				line="$(user)@$(host) $(in_directory) $(in_repo)"
				unpushed="$(in_repo_unpushed)"

				print -n "$line$unpushed\n$(line_prompt)"
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
