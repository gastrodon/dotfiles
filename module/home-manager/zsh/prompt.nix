{ lib, ... }:

let
  # Rendered in order; each body appends prompt text to $p.
  segments = [
    {
      name = "venv";
      body = ''
        [[ -n $VIRTUAL_ENV ]] && p+="%F{green}''${VIRTUAL_ENV:t}:%F{white}"
      '';
    }
    {
      name = "user";
      body = ''
        p+="%n@%m "
      '';
    }
    {
      name = "path";
      body = ''
        local where=''${PWD:t}
        [[ $PWD == / ]] && where=/
        [[ $PWD == $HOME ]] && where='~'
        p+="''${where//\%/%%} "
      '';
    }
    {
      name = "git";
      body = ''
        local -a st cfg
        st=("''${(@f)$(git status --porcelain=v2 --branch 2>/dev/null)}") || return 0
        local line head= dirty= base ahead=
        for line in $st; do
          case $line in
            ('# branch.head '*) head=''${line#\# branch.head } ;;
            ('#'*) ;;
            (*) dirty=1 ;;
          esac
        done
        [[ $head == '(detached)' ]] && head=HEAD

        local name=''${PWD:t}
        cfg=(''${(f)"$(git config --get-regexp '^(remote\.origin\.url|init\.defaultbranch)$' 2>/dev/null)"})
        line=''${(M)cfg:#remote.origin.url *}
        [[ -n $line ]] && name=''${''${''${line##* }:t}%.git}

        # commits since branching off the default branch
        line=''${(M)cfg:#init.defaultbranch *}
        for base in refs/remotes/origin/HEAD refs/heads/main refs/heads/master ''${line:+refs/heads/''${line##* }}; do
          ahead=$(git rev-list --count "$base..HEAD" 2>/dev/null) && break
          ahead=
        done

        p+="''${name//\%/%%}%F{''${dirty:+yellow}''${dirty:-green}}/''${head//\%/%%}"
        (( ahead > 0 )) && p+="+$ahead"
        p+="%F{white}"
      '';
    }
    {
      name = "aws";
      body = ''
        [[ -n $AWS_PROFILE ]] || return 0
        p+=" [aws:$AWS_PROFILE"
        [[ -n $AWS_REGION ]] && p+=", %F{green}$AWS_REGION%F{white}"
        p+="]"
      '';
    }
    {
      name = "status";
      body = ''
        local color=white prefix=---
        (( rc )) && color=red
        (( $#jobstates )) && color=blue
        (( rc == 127 )) && prefix='???'
        p+=$'\n'"%F{$color}$prefix%F{white} "
      '';
    }
  ];

  fn = s: ''
    _liner_${s.name}() {
    ${s.body}}
  '';
in
{
  programs.zsh.initContent = lib.mkOrder 1200 ''
    ${lib.concatMapStrings fn segments}
    _liner_precmd() {
      local -i rc=$?
      local p=
      ${lib.concatMapStringsSep "\n  " (s: "_liner_${s.name}") segments}
      _liner_ps=$p
    }
    setopt prompt_subst
    PROMPT="\''${_liner_ps}"
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _liner_precmd
  '';
}
