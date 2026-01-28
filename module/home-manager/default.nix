{ palette }:
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
      inherit palette;
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
      ];

      programs.obsidian = {
        enable = true;
        vaults.notes = {
          target = "notes";
          settings = {
            app = {
              promptDelete = false;
              attachmentFolderPath = "./attachments";
              useMarkdownLinks = true;
            };
            appearance = {
              baseFontSize = 16;
              theme = "obsidian";
              cssTheme = "Solarized";
            };
            themes = [
              {
                enable = true;
                pkg = pkgs.callPackage ../../package/obsidian-theme/solarized { };
              }
            ];
            corePlugins = [
              "backlink"
              "bookmarks"
              "canvas"
              "command-palette"
              "editor-status"
              "file-explorer"
              "file-recovery"
              "global-search"
              "graph"
              "note-composer"
              "outgoing-link"
              "outline"
              "page-preview"
              "switcher"
              "tag-pane"
              "templates"
              "word-count"
              {
                name = "daily-notes";
                settings = {
                  format = "YYYY-MM-DD";
                  folder = "daily";
                  autorun = true;
                };
              }
            ];
          };
        };
      };

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
