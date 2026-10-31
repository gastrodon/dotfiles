{
  palette,
  claude-code-nix,
}:
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
    backupFileExtension = "old";

    extraSpecialArgs = {
      identity = config.identity;
      hostname = config.networking.hostName;
      desktop = config.desktop;
      inherit
        palette
        claude-code-nix
        ;
    };

    users.${config.identity.username} = {
      imports = [
        ./git.nix
        ./gh.nix
        ./ssh.nix
        ./firefox.nix
        ./rofi.nix
        ./zed
        ./zsh
        ./ghostty.nix
        ./i3.nix
        ./sway.nix
        ./i3blocks.nix
        ./xresources.nix
        ./passage.nix
        (
          { config, ... }:
          {
            home.file.".claude/CLAUDE.md" = {
              source = config.lib.file.mkOutOfStoreSymlink "/srv/code/lab/docs/claude/global.md";
              force = true;
            };
          }
        )
      ];

      home.stateVersion = "25.11";

      home.packages = with pkgs; [
        bottom
        tldr
        ripgrep
        coreutils
        tmux
      ];

      programs.home-manager.enable = true;
    };
  };
}
