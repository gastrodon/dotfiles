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
        ./vscodium
        ./zsh
        ./ghostty.nix
        ./i3.nix
        ./i3blocks.nix
        ./xresources.nix
        ./passage.nix
        ./memory-gardener.nix
        ./trilium.nix
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
        arandr
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
