{ config, pkgs, ... }:

{
  imports = [
    ./git.nix
    ./gh.nix # I'm not 100% I actually use this
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;

    users.eva = {
      home.stateVersion = "25.11";

      # The home.packages option allows you to install Nix packages into your environment
      home.packages = with pkgs; [
        # Add user-level packages here
      ];

      # Let home-manager manage itself
      programs.home-manager.enable = true;
    };
  };
}
