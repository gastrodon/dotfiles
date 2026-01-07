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
        ./gh.nix
        ./ssh.nix
        ./firefox.nix
        ./vscodium
        ./zsh
      ];

      home.stateVersion = "25.11";

      home.packages = with pkgs; [
        bottom
        tldr
        ripgrep
        coreutils
      ];

      programs.home-manager.enable = true;
    };
  };
}
