{ config, pkgs, ... }:

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

      home.packages = with pkgs; [
        bottom
        tldr
        ripgrep
      ];

      programs.home-manager.enable = true;
    };
  };
}
