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

    autosuggestion = {
      enable = true;
    };

    syntaxHighlighting = {
      enable = true;
    };

    historySubstringSearch = {
      enable = true;
    };

    oh-my-zsh = {
      enable = true;
      custom = "$HOME/.config/oh-my-zsh";
      theme = "liner";
    };

    initContent = lib.mkOrder 500 ''
      setopt rm_star_silent
    '';

    sessionVariables = {
      EDITOR = "vim";
    };
  };
}
