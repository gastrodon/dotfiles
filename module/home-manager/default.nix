{
  palette,
  obsidian-local-rest-api,
  claude-code-nix,
}:
{
  config,
  pkgs,
  lib,
  ...
}:
let
  obsidianMcp = import ./obsidian-mcp.nix;
in

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
        obsidian-local-rest-api
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

      programs.obsidian = {
        enable = true;
        vaults.notes = {
          target = "notes";
          settings = {
            app = {
              promptDelete = false;
              alwaysUpdateLinks = true;
              newFileLocation = "current";
              attachmentFolderPath = "./";
              pdfExportSettings = {
                includeName = false;
                pageSize = "Letter";
                landscape = false;
                margin = "0";
                downscalePercent = 100;
              };
              useMarkdownLinks = true;
              showLineNumber = false;
              openBehavior = "daily";
            };
            appearance = {
              accentColor = "";
              baseFontSize = 16;
              theme = "obsidian";
              monospaceFontFamily = "Fira Code";
              cssTheme = "Solarized";
            };
            themes = [
              {
                enable = true;
                pkg = pkgs.callPackage ../../package/obsidian-theme/solarized { };
              }
            ];
            communityPlugins = [
              {
                enable = true;
                pkg = pkgs.callPackage ../../package/obsidian-plugin/local-rest-api {
                  obsidianLocalRestApi = obsidian-local-rest-api.packages.${pkgs.stdenv.hostPlatform.system}.default;
                };
                settings = {
                  apiKey = obsidianMcp.apiKey;
                  enableInsecureServer = true;
                  insecurePort = obsidianMcp.port;
                  bindingHost = "127.0.0.1";
                };
              }
              {
                enable = true;
                pkg = pkgs.callPackage ../../package/obsidian-plugin/omnisearch { };
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
              "sync"
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
