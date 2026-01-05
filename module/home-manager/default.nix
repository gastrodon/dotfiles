{
  config,
  pkgs,
  lib,
  ...
}:

{
  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    extraSpecialArgs = {
      identity = config.identity;
    };

    users.${config.identity.username} = {
      imports = [
        ./git.nix
        ./gh.nix # I'm not 100% I actually use this
        ./ssh.nix
        ./vscodium
      ];

      home.stateVersion = "25.11";

      home.packages = with pkgs; [
        bottom
        tldr
        ripgrep
        coreutils
      ];

      programs.home-manager.enable = true;

      programs.zsh = {
        enable = true;
        enableCompletion = true;

        initContent = ''
          setopt rm_star_silent
        '';

        sessionVariables = {
          EDITOR = "vim";
        };
      };
    };
  };
}
