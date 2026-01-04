{
  config,
  pkgs,
  lib,
  ...
}:

let
  cmdPackages = import ../../package/cmd { inherit pkgs lib; };
in
{
  imports = [
    ./git.nix
    ./gh.nix # I'm not 100% I actually use this
    ./ssh.nix
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.${config.identity.username} = {
      imports = [
        ./vscodium
      ];

      home.stateVersion = "25.11";

      home.packages =
        (with pkgs; [
          bottom
          tldr
          ripgrep
          coreutils
        ])
        ++ (builtins.attrValues cmdPackages);

      programs.home-manager.enable = true;

      programs.zsh = {
        enable = true;
        enableCompletion = true;

        initExtra = ''
          setopt rm_star_silent
        '';

        sessionVariables = {
          EDITOR = "vim";
        };
      };
    };
  };
}
