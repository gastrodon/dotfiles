{
  pkgs,
  lib,
  ...
}:

{
  imports = [ ./prompt.nix ];

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      zed = "zeditor";
    };

    autosuggestion = {
      enable = true;
    };

    syntaxHighlighting = {
      enable = true;
    };

    history = {
      size = 100000;
      save = 100000;
      extended = true;
      ignoreAllDups = true;
      ignoreSpace = true;
    };

    autocd = true;
    defaultKeymap = "emacs";
    setOptions = [
      "RM_STAR_SILENT"
      "AUTO_PUSHD"
      "PUSHD_IGNORE_DUPS"
      "PUSHD_MINUS"
      "INTERACTIVE_COMMENTS"
      "LONG_LIST_JOBS"
      "COMPLETE_IN_WORD"
      "ALWAYS_TO_END"
      "NO_FLOW_CONTROL"
    ];

    initContent = lib.mkOrder 600 ''
      zmodload -i zsh/complist
      WORDCHARS=
      zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
      zstyle ':completion:*' menu select
      zstyle ':completion:*' special-dirs true
      zstyle ':completion:*' list-colors ''${(s.:.)LS_COLORS}
      zstyle ':completion:*' use-cache yes
      zstyle ':completion:*' cache-path "''${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
      bindkey '^[[Z' reverse-menu-complete
      bindkey '^[[H' beginning-of-line
      bindkey '^[OH' beginning-of-line
      bindkey '^[[F' end-of-line
      bindkey '^[OF' end-of-line
      bindkey '^[[3~' delete-char
      bindkey '^[[1;5C' forward-word
      bindkey '^[[1;5D' backward-word
      autoload -Uz edit-command-line
      zle -N edit-command-line
      bindkey '^X^E' edit-command-line
      alias -- -='cd -'
    '';

    sessionVariables = {
      EDITOR = "vim";
    };
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  programs.nix-index-database.comma.enable = true;
}
