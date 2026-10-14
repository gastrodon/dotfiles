{
  config,
  pkgs,
  lib,
  ...
}:

{
  home.file.".config/oh-my-zsh/themes/liner.zsh-theme".source = ./liner.zsh-theme;

  programs.zsh = {
    enable = true;
    enableCompletion = true;

    shellAliases = {
      code = "codium";
    };

    autosuggestion = {
      enable = true;
    };

    syntaxHighlighting = {
      enable = true;
    };

    historySubstringSearch = {
      enable = true;
      # omz enables keypad mode (smkx), so arrows also arrive as SS3
      searchUpKey = [
        "^[[A"
        "^[OA"
      ];
      searchDownKey = [
        "^[[B"
        "^[OB"
      ];
    };

    history = {
      size = 100000;
      save = 100000;
      extended = true;
      ignoreAllDups = true;
      ignorePatterns = [
        "bao login*"
        "bao kv put*"
        "bao write*"
        "*TOKEN=*"
        "*_KEY=*"
        "*SECRET*=*"
        "*PASSWORD=*"
      ];
    };

    oh-my-zsh = {
      enable = true;
      custom = "${config.home.homeDirectory}/.config/oh-my-zsh";
      theme = "liner";
    };

    initContent = lib.mkOrder 500 ''
      setopt rm_star_silent
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
