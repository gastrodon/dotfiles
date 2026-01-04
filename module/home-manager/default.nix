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

      home.sessionVariables = {
        SSH_AUTH_SOCK = "$(gpgconf --list-dirs agent-ssh-socket)";
        GPG_TTY = "$(tty)";
      };

      programs.home-manager.enable = true;
    };
  };
}
